from fastapi import APIRouter, Depends, HTTPException
from typing import List, Optional, Dict, Any
from app.models.trip import TripDB, TripCreate, Location, Expense
from app.models.user import UserDB
from app.api.auth import get_current_user
from app.core.database import db
from app.services.trip_planner import TripPlannerService
import uuid
from datetime import datetime
from pydantic import BaseModel

router = APIRouter()

# ─── SPECIFIC / LITERAL ROUTES (must come before wildcard /{trip_id}) ───────

@router.post("/", response_model=TripDB)
async def create_trip(trip: TripCreate, current_user: UserDB = Depends(get_current_user)):
    trip_db = TripDB(
        **trip.dict(),
        id=str(uuid.uuid4()),
        organizer_id=current_user.id,
        status="planned"
    )
    await db.db["trips"].insert_one(trip_db.dict())
    return trip_db

@router.get("/user/categories")
async def get_user_trips(current_user: UserDB = Depends(get_current_user)):
    """
    Returns trips in categories:
    - planned_by_me
    - completed_by_me
    - participant_active
    - participant_completed
    """
    all_trips_cursor = db.db["trips"].find({
        "$or": [
            {"organizer_id": current_user.id},
            {"participants.user_id": current_user.id}
        ]
    }).sort("created_at", -1)
    
    trips = await all_trips_cursor.to_list(length=100)
    
    categorized = {
        "planned_by_me": [],
        "completed_by_me": [],
        "participant_active": [],
        "participant_completed": []
    }
    
    for t in trips:
        trip = TripDB(**t)
        if trip.organizer_id == current_user.id:
            if trip.status == "completed":
                categorized["completed_by_me"].append(trip)
            else:
                categorized["planned_by_me"].append(trip)
        else:
            if trip.status == "completed":
                categorized["participant_completed"].append(trip)
            else:
                categorized["participant_active"].append(trip)
                
    return categorized

@router.get("/feed/completed", response_model=List[TripDB])
async def get_completed_trips_feed(search: Optional[str] = None, current_user: UserDB = Depends(get_current_user)):
    """Home feed showing completed trips of others"""
    query: Dict[str, Any] = {"status": "completed"}
    
    if search:
        search_regex = {"$regex": search, "$options": "i"}
        query["$or"] = [
            {"title": search_regex},
            {"destination.name": search_regex}
        ]
        
    cursor = db.db["trips"].find(query).sort("updated_at", -1).limit(50)
    
    trips = await cursor.to_list(length=50)
    return [TripDB(**t) for t in trips]

@router.get("/autocomplete")
async def autocomplete_location(query: str, current_user: UserDB = Depends(get_current_user)):
    return TripPlannerService.get_autocomplete(query)

class VehicleForPlan(BaseModel):
    id: str
    name: Optional[str] = None
    seats: int = 4
    mileage_per_liter: float = 15.0
    avg_distance_per_day: float = 500.0

class PlanRequest(BaseModel):
    source: Location
    destination: Location
    stops: List[Location] = []
    selected_vehicles: List[VehicleForPlan] = []  # vehicles chosen by user in UI
    fuel_price_per_liter: float = 100.0  # editable in UI

@router.post("/intelligence/plan")
async def generate_trip_plan(req: PlanRequest, current_user: UserDB = Depends(get_current_user)):
    # Use the best (max) avg_distance_per_day from chosen vehicles, then user vehicles, then fallback
    candidate_days_dists: list[float] = [v.avg_distance_per_day for v in req.selected_vehicles if v.avg_distance_per_day > 0]
    if not candidate_days_dists and current_user.profile_settings.vehicles:
        candidate_days_dists = [v.avg_distance_per_day for v in current_user.profile_settings.vehicles]
    avg_daily = max(candidate_days_dists) if candidate_days_dists else 500.0

    plan = TripPlannerService.calculate_trip_itinerary(
        source=req.source,
        destination=req.destination,
        stops=req.stops,
        avg_daily_dist=avg_daily,
    )

    total_dist = plan["total_distance_km"]
    days = plan["estimated_days"]

    # Per-vehicle fuel cost
    vehicle_fuel_costs = []
    total_fuel_cost = 0.0
    for v in req.selected_vehicles:
        liters = total_dist / v.mileage_per_liter if v.mileage_per_liter > 0 else 0
        cost = round(liters * req.fuel_price_per_liter, 2)
        total_fuel_cost += cost
        vehicle_fuel_costs.append({
            "vehicle_id": v.id,
            "vehicle_name": v.name or "Vehicle",
            "fuel_cost": cost,
            "liters_needed": round(liters, 2),
        })

    # Stay & food cost from user profile
    stay_cost = round(current_user.profile_settings.avg_nightly_stay_expense * (days - 1), 2)
    food_cost = round(current_user.profile_settings.avg_daily_food_expense * days, 2)
    total_cost = round(total_fuel_cost + stay_cost + food_cost, 2)

    plan["vehicle_fuel_costs"] = vehicle_fuel_costs
    plan["estimated_fuel_cost"] = round(total_fuel_cost, 2)
    plan["estimated_stay_cost"] = stay_cost
    plan["estimated_food_cost"] = food_cost
    plan["total_estimated_cost"] = total_cost
    plan["fuel_price_per_liter"] = req.fuel_price_per_liter

    return plan

# ─── WILDCARD ROUTES (must come AFTER all literal routes) ────────────────────

@router.get("/{trip_id}", response_model=TripDB)
async def get_trip(trip_id: str, current_user: UserDB = Depends(get_current_user)):
    trip_data = await db.db["trips"].find_one({"id": trip_id})
    if not trip_data:
        raise HTTPException(status_code=404, detail="Trip not found")
        
    # Anyone can view completed trips, otherwise only participants
    if trip_data["status"] != "completed":
        participant_ids = [p["user_id"] for p in trip_data.get("participants", [])]
        if current_user.id != trip_data["organizer_id"] and current_user.id not in participant_ids:
            raise HTTPException(status_code=403, detail="Not authorized to view this active trip")
            
    return TripDB(**trip_data)

@router.put("/{trip_id}/status")
async def update_trip_status(trip_id: str, status: str, current_user: UserDB = Depends(get_current_user)):
    if status not in ["planned", "in_progress", "completed"]:
        raise HTTPException(status_code=400, detail="Invalid status")
        
    trip_data = await db.db["trips"].find_one({"id": trip_id})
    if not trip_data:
        raise HTTPException(status_code=404, detail="Trip not found")
        
    if trip_data["organizer_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Only organizer can change status")
        
    await db.db["trips"].update_one(
        {"id": trip_id},
        {"$set": {"status": status, "updated_at": datetime.utcnow()}}
    )
    
    updated_trip = await db.db["trips"].find_one({"id": trip_id})
    return TripDB(**updated_trip)

@router.post("/{trip_id}/expenses", response_model=Expense)
async def add_expense(trip_id: str, expense: Expense, current_user: UserDB = Depends(get_current_user)):
    trip_data = await db.db["trips"].find_one({"id": trip_id})
    if not trip_data:
        raise HTTPException(status_code=404, detail="Trip not found")
        
    participant_ids = [p["user_id"] for p in trip_data.get("participants", [])]
    if current_user.id != trip_data["organizer_id"] and current_user.id not in participant_ids:
        raise HTTPException(status_code=403, detail="Not authorized to add expenses")
        
    expense.id = str(uuid.uuid4())
    if not expense.paid_by:
        expense.paid_by = current_user.id
        
    await db.db["trips"].update_one(
        {"id": trip_id},
        {"$push": {"expenses": expense.dict()}}
    )
    return expense

class CommentCreate(BaseModel):
    text: str

@router.post("/{trip_id}/comments")
async def add_comment(trip_id: str, comment: CommentCreate, current_user: UserDB = Depends(get_current_user)):
    trip_data = await db.db["trips"].find_one({"id": trip_id})
    if not trip_data:
        raise HTTPException(status_code=404, detail="Trip not found")
        
    # Anyone can comment on completed public trips, else only participants
    if trip_data["status"] != "completed":
        participant_ids = [p["user_id"] for p in trip_data.get("participants", [])]
        if current_user.id != trip_data["organizer_id"] and current_user.id not in participant_ids:
            raise HTTPException(status_code=403, detail="Not authorized to comment")
            
    comment_data = {
        "id": str(uuid.uuid4()),
        "user_id": current_user.id,
        "username": current_user.username,
        "text": comment.text,
        "timestamp": datetime.utcnow()
    }
    
    await db.db["trips"].update_one(
        {"id": trip_id},
        {"$push": {"comments": comment_data}}
    )
    return comment_data

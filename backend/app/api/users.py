from fastapi import APIRouter, Depends, HTTPException
from app.models.user import UserDB, UserProfileSettings, Vehicle, UserProfileUpdate
from app.api.auth import get_current_user
from app.core.database import db

router = APIRouter()

@router.get("/me", response_model=UserDB)
async def get_my_profile(current_user: UserDB = Depends(get_current_user)):
    return current_user

@router.put("/me/profile", response_model=UserDB)
async def update_my_profile(profile_update: UserProfileUpdate, current_user: UserDB = Depends(get_current_user)):
    update_data = {k: v for k, v in profile_update.dict().items() if v is not None}
    if not update_data:
        return current_user
        
    await db.db["users"].update_one(
        {"id": current_user.id},
        {"$set": update_data}
    )
    updated_user = await db.db["users"].find_one({"id": current_user.id})
    return UserDB(**updated_user)

@router.put("/me/settings", response_model=UserDB)
async def update_my_settings(settings: UserProfileSettings, current_user: UserDB = Depends(get_current_user)):
    await db.db["users"].update_one(
        {"id": current_user.id},
        {"$set": {"profile_settings": settings.dict()}}
    )
    updated_user = await db.db["users"].find_one({"id": current_user.id})
    return UserDB(**updated_user)

@router.post("/me/vehicles", response_model=UserDB)
async def add_vehicle(vehicle: Vehicle, current_user: UserDB = Depends(get_current_user)):
    # Motorcycles must have exactly 2 seats
    if vehicle.type.lower() == "motorcycle":
        vehicle.seats = 2
        
    await db.db["users"].update_one(
        {"id": current_user.id},
        {"$push": {"profile_settings.vehicles": vehicle.dict()}}
    )
    updated_user = await db.db["users"].find_one({"id": current_user.id})
    return UserDB(**updated_user)

@router.delete("/me/vehicles/{vehicle_id}", response_model=UserDB)
async def remove_vehicle(vehicle_id: str, current_user: UserDB = Depends(get_current_user)):
    await db.db["users"].update_one(
        {"id": current_user.id},
        {"$pull": {"profile_settings.vehicles": {"id": vehicle_id}}}
    )
    updated_user = await db.db["users"].find_one({"id": current_user.id})
    return UserDB(**updated_user)

from fastapi import APIRouter, Depends, HTTPException
from typing import List
from app.models.user import UserDB
from app.api.auth import get_current_user
from app.core.database import db
from pydantic import BaseModel
from datetime import datetime
import uuid

router = APIRouter()

class CrewRequest(BaseModel):
    id: str
    sender_id: str
    receiver_id: str
    status: str = "pending" # pending, accepted, rejected
    created_at: datetime = datetime.utcnow()

class SearchResult(BaseModel):
    id: str
    username: str
    email: str

@router.get("/search", response_model=List[SearchResult])
async def search_users(query: str, current_user: UserDB = Depends(get_current_user)):
    # Search by email or username, exclude self
    cursor = db.db["users"].find({
        "$and": [
            {"id": {"$ne": current_user.id}},
            {"$or": [
                {"email": {"$regex": query, "$options": "i"}},
                {"username": {"$regex": query, "$options": "i"}}
            ]}
        ]
    }).limit(20)
    
    users = await cursor.to_list(length=20)
    return [SearchResult(**u) for u in users]

@router.post("/requests/{user_id}")
async def send_crew_request(user_id: str, current_user: UserDB = Depends(get_current_user)):
    receiver = await db.db["users"].find_one({"id": user_id})
    if not receiver:
        raise HTTPException(status_code=404, detail="User not found")
        
    if user_id in current_user.crew_ids:
        raise HTTPException(status_code=400, detail="Already in crew")
        
    existing_req = await db.db["crew_requests"].find_one({
        "sender_id": current_user.id,
        "receiver_id": user_id,
        "status": "pending"
    })
    if existing_req:
        raise HTTPException(status_code=400, detail="Request already sent")
        
    req = CrewRequest(
        id=str(uuid.uuid4()),
        sender_id=current_user.id,
        receiver_id=user_id
    )
    await db.db["crew_requests"].insert_one(req.dict())
    return {"message": "Request sent"}

@router.get("/requests/pending")
async def get_pending_requests(current_user: UserDB = Depends(get_current_user)):
    cursor = db.db["crew_requests"].find({
        "receiver_id": current_user.id,
        "status": "pending"
    })
    requests = await cursor.to_list(length=100)

    # Enrich each request with sender's display info
    enriched = []
    for req in requests:
        sender = await db.db["users"].find_one({"id": req["sender_id"]})
        req["sender_email"] = sender["email"] if sender else req["sender_id"]
        req["sender_full_name"] = sender.get("full_name") if sender else None
        enriched.append(req)
    return enriched

@router.post("/requests/{request_id}/accept")
async def accept_request(request_id: str, current_user: UserDB = Depends(get_current_user)):
    req = await db.db["crew_requests"].find_one({"id": request_id, "receiver_id": current_user.id, "status": "pending"})
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
        
    # Update request status
    await db.db["crew_requests"].update_one(
        {"id": request_id},
        {"$set": {"status": "accepted"}}
    )
    
    # Add to each other's crew
    await db.db["users"].update_one(
        {"id": current_user.id},
        {"$addToSet": {"crew_ids": req["sender_id"]}}
    )
    await db.db["users"].update_one(
        {"id": req["sender_id"]},
        {"$addToSet": {"crew_ids": current_user.id}}
    )
    
    return {"message": "Request accepted"}

@router.get("/")
async def get_my_crew(current_user: UserDB = Depends(get_current_user)):
    cursor = db.db["users"].find({"id": {"$in": current_user.crew_ids}})
    crew = await cursor.to_list(length=100)
    # Return limited info for crew (no hashed passwords etc.)
    return [UserDB(**member).dict(exclude={"hashed_password"}) for member in crew]

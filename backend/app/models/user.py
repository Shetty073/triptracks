from pydantic import BaseModel, EmailStr, Field
from typing import List
from datetime import datetime
import uuid

class Vehicle(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    type: str # car, motorcycle
    seats: int
    mileage_per_liter: float
    avg_distance_per_day: float

class UserProfileSettings(BaseModel):
    distance_unit: str = "km" # km or miles
    currency: str = "USD"
    vehicles: List[Vehicle] = []
    avg_daily_food_expense: float = 0.0
    avg_nightly_stay_expense: float = 0.0

class UserBase(BaseModel):
    email: EmailStr
    username: str

class UserCreate(UserBase):
    password: str

class UserDB(UserBase):
    id: str
    hashed_password: str
    profile_settings: UserProfileSettings = UserProfileSettings()
    crew_ids: List[str] = [] # List of connected friend IDs
    created_at: datetime = Field(default_factory=datetime.utcnow)

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

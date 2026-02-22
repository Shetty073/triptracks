from pydantic import BaseModel, Field
from typing import Optional, List, Dict
from datetime import datetime
import uuid

class Location(BaseModel):
    name: str # The autocomplete name
    lat: float
    lng: float

class Leg(BaseModel):
    distance_km: float
    estimated_time_mins: int

class TripParticipant(BaseModel):
    user_id: str
    is_driver: bool = False
    vehicle_id: Optional[str] = None # Which vehicle they are in
    role: str = "passenger" # e.g. "driver", "passenger", "organizer"

class Expense(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    description: str
    amount: float
    paid_by: str # user_id
    split_ratio: Dict[str, float] = {} # user_id -> ratio or fixed amount
    date: datetime = Field(default_factory=datetime.utcnow)

class TripBase(BaseModel):
    title: str
    source: Location
    destination: Location
    stops: List[Location] = []
    participants: List[TripParticipant] = []
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    fuel_cost_per_unit: float = 0.0

class TripCreate(TripBase):
    pass

class TripDB(TripBase):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    organizer_id: str
    status: str = "planned" # planned, in_progress, completed
    legs: List[Leg] = []
    total_distance_km: float = 0.0
    total_estimated_time_mins: int = 0
    expenses: List[Expense] = []
    comments: List[dict] = [] # Keeping it simple for now -> [{user_id, text, timestamp}]
    photos: List[str] = [] # URLs to photos
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

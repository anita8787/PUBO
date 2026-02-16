from pydantic import BaseModel, HttpUrl, Field
from typing import List, Optional, Any, Dict
from datetime import datetime
from enum import Enum

class TaskStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"

# --- Place Schemas ---
class PlaceBase(BaseModel):
    place_id: str
    google_place_id: Optional[str] = None
    name: str
    address: Optional[str] = None
    latitude: float
    longitude: float
    category: Optional[str] = None
    rating: Optional[float] = None
    user_ratings_total: Optional[int] = None
    opening_hours: Optional[Dict[str, Any]] = None
    open_now: Optional[bool] = None

class PlaceCreate(PlaceBase):
    pass

class Place(BaseModel):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True

# --- Content Schemas ---
class ContentBase(BaseModel):
    source_type: str # instagram / threads / youtube
    source_url: str
    title: Optional[str] = None
    text: Optional[str] = None
    author_name: Optional[str] = None
    author_avatar_url: Optional[str] = None
    preview_thumbnail_url: Optional[str] = None
    published_at: Optional[datetime] = None
    user_tags: List[str] = []

class ContentCreate(ContentBase):
    pass

class ContentPlaceInfo(BaseModel):
    place: PlaceBase
    evidence_text: Optional[str] = None
    confidence_score: float = 0.0

class ContentResponse(ContentBase):
    id: int
    created_at: datetime
    places: List[ContentPlaceInfo] = []

    class Config:
        from_attributes = True

# --- API Interaction Schemas ---
class ShareRequest(BaseModel):
    url: str

class ExtractionResponse(BaseModel):
    content: ContentBase
    suggested_places: List[ContentPlaceInfo]

class TaskResponse(BaseModel):
    task_id: str
    status: TaskStatus
    result: Optional[ExtractionResponse] = None
    error: Optional[str] = None

# --- AI Analysis Schemas ---
class AnalyzeRequest(BaseModel):
    name: str
    address: Optional[str] = None
    category: Optional[str] = None

class AnalyzeResponse(BaseModel):
    description: str

# --- Trip Planning Schemas ---

# 1. Spot Schemas
class SpotBase(BaseModel):
    name: str
    category: Optional[str] = "spot"
    start_time: Optional[str] = None
    stay_duration: Optional[str] = "60分鐘"
    notes: List[str] = []
    image_url: Optional[str] = None
    place_id: Optional[int] = None # Link to existing Place DB ID
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    travel_time: Optional[str] = None
    travel_distance: Optional[str] = None
    travel_mode: Optional[str] = "train"

class SpotCreate(SpotBase):
    day_id: int
    google_place_id: Optional[str] = None
    place: Optional[PlaceBase] = None # Nested Place info for creation

class SpotUpdate(BaseModel):
    name: Optional[str] = None
    start_time: Optional[str] = None
    stay_duration: Optional[str] = None
    notes: Optional[List[str]] = None
    sort_order: Optional[int] = None
    travel_mode: Optional[str] = None
    travel_time: Optional[str] = None
    travel_distance: Optional[str] = None

class SpotResponse(SpotBase):
    id: str
    day_id: int
    sort_order: int
    place: Optional[PlaceBase] = None # Nested Place info

    class Config:
        from_attributes = True

# 2. Day Schemas
class DayBase(BaseModel):
    day_order: int
    date: Optional[datetime] = None
    weekday: Optional[str] = None
    title: Optional[str] = None

class DayCreate(DayBase):
    trip_id: str

class DayResponse(DayBase):
    id: int
    trip_id: str
    spots: List[SpotResponse] = []

    class Config:
        from_attributes = True

# 3. Trip Schemas
class TripBase(BaseModel):
    title: str
    destination: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    cover_image_url: Optional[str] = None
    transport_mode: Optional[str] = "大眾運輸"

class TripCreate(TripBase):
    pass

class TripUpdate(BaseModel):
    title: Optional[str] = None
    destination: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    transport_mode: Optional[str] = None

class TripResponse(TripBase):
    id: str
    created_at: datetime
    updated_at: datetime
    days: List[DayResponse] = []

    class Config:
        from_attributes = True

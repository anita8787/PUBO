from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Table, Text, JSON
from sqlalchemy.orm import relationship, declarative_base
from datetime import datetime

Base = declarative_base()

# Association Table for Content and Place (Many-to-Many)
class ContentPlaceAssociation(Base):
    __tablename__ = "content_place_association"
    
    id = Column(Integer, primary_key=True, index=True)
    content_id = Column(Integer, ForeignKey("contents.id"), nullable=False)
    place_id = Column(Integer, ForeignKey("places.id"), nullable=False)
    
    # Relationship evidence fields (from PRD)
    evidence_text = Column(Text, nullable=True)  # 原文證據
    confidence_score = Column(Float, default=0.0) # 抽取信心值
    is_manual_override = Column(Integer, default=0) # 使用者是否手動覆寫 (0 or 1)
    
    content = relationship("Content", back_populates="place_associations")
    place = relationship("Place", back_populates="content_associations")

class Content(Base):
    __tablename__ = "contents"
    
    id = Column(Integer, primary_key=True, index=True)
    source_type = Column(String, nullable=False) # instagram / threads / youtube
    source_url = Column(String, unique=True, nullable=False, index=True)
    title = Column(String, nullable=True)
    text = Column(Text, nullable=True) # caption or transcript
    author_name = Column(String, nullable=True)
    author_avatar_url = Column(String, nullable=True)
    preview_thumbnail_url = Column(String, nullable=True)
    published_at = Column(DateTime, nullable=True)
    user_tags = Column(JSON, default=[]) # 存儲標籤清單
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationship
    place_associations = relationship("ContentPlaceAssociation", back_populates="content", cascade="all, delete-orphan")

class Place(Base):
    __tablename__ = "places"
    
    id = Column(Integer, primary_key=True, index=True)
    place_id = Column(String, unique=True, index=True)  # Apple Maps POI ID
    name = Column(String, nullable=False, index=True)
    address = Column(String, nullable=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    category = Column(String, nullable=True) # 餐廳、咖啡、景點、商店等
    
    # Smart Itinerary Fields
    rating = Column(Float, nullable=True)
    user_ratings_total = Column(Integer, nullable=True)
    opening_hours = Column(JSON, nullable=True) # Store complete Google Places opening_hours dictionary
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationship
    content_associations = relationship("ContentPlaceAssociation", back_populates="place")

class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(String, unique=True, index=True, nullable=False)
    status = Column(String, default="pending")
    target_url = Column(String, nullable=False)
    result = Column(JSON, nullable=True)
    error = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# --- Trip Planning Models ---

class Trip(Base):
    __tablename__ = "trips"
    
    id = Column(String, primary_key=True, index=True) # UUID
    title = Column(String, nullable=False)
    destination = Column(String, nullable=True)
    start_date = Column(DateTime, nullable=True)
    end_date = Column(DateTime, nullable=True)
    cover_image_url = Column(String, nullable=True)
    transport_mode = Column(String, nullable=True) # e.g. "大眾運輸", "開車"
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    days = relationship("ItineraryDay", back_populates="trip", cascade="all, delete-orphan", order_by="ItineraryDay.day_order")

class ItineraryDay(Base):
    __tablename__ = "itinerary_days"
    
    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(String, ForeignKey("trips.id"), nullable=False)
    day_order = Column(Integer, nullable=False) # 1, 2, 3...
    date = Column(DateTime, nullable=True)
    weekday = Column(String, nullable=True) # "Mon", "週一"
    title = Column(String, nullable=True) # e.g. "抵達東京"
    
    # Relationships
    trip = relationship("Trip", back_populates="days")
    spots = relationship("ItinerarySpot", back_populates="day", cascade="all, delete-orphan", order_by="ItinerarySpot.sort_order")

class ItinerarySpot(Base):
    __tablename__ = "itinerary_spots"
    
    id = Column(String, primary_key=True, index=True) # UUID
    day_id = Column(Integer, ForeignKey("itinerary_days.id"), nullable=False)
    place_id = Column(Integer, ForeignKey("places.id"), nullable=True) # Optional link to Place
    
    name = Column(String, nullable=False)
    category = Column(String, nullable=True) # "food", "spot", etc.
    start_time = Column(String, nullable=True) # "10:00"
    stay_duration = Column(String, nullable=True) # "60分鐘"
    notes = Column(JSON, default=[]) # List of strings
    image_url = Column(String, nullable=True)
    
    # Cache location for quick access (or if manual spot without Place)
    latitude = Column(Float, nullable=True) 
    longitude = Column(Float, nullable=True)
    
    sort_order = Column(Integer, default=0)
    
    # New fields for travel info
    travel_time = Column(String, nullable=True) # Time to next spot
    travel_distance = Column(String, nullable=True) # Distance to next spot
    travel_mode = Column(String, nullable=True) # "walk", "train", "car"
    
    # Relationships
    day = relationship("ItineraryDay", back_populates="spots")
    place = relationship("Place")

# Database Setup
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./pubo.db")
# SQLite 特定設定 (check_same_thread)
connect_args = {"check_same_thread": False} if "sqlite" in DATABASE_URL else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def init_db():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import uuid
from datetime import timedelta

from ..models.database import get_db, init_db, Task, SessionLocal, Trip, ItineraryDay, ItinerarySpot, Place
from ..models import schemas

router = APIRouter()

# --- Trip Endpoints ---

from sqlalchemy.orm import joinedload

@router.get("/trips", response_model=List[schemas.TripResponse])
def get_trips(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    trips = db.query(Trip).order_by(Trip.start_date.desc()).offset(skip).limit(limit).all()
    return trips

@router.post("/trips", response_model=schemas.TripResponse)
def create_trip(trip: schemas.TripCreate, db: Session = Depends(get_db)):
    # 1. Create Trip
    new_trip = Trip(
        id=str(uuid.uuid4()),
        title=trip.title,
        destination=trip.destination,
        start_date=trip.start_date,
        end_date=trip.end_date,
        cover_image_url=trip.cover_image_url,
        transport_mode=trip.transport_mode
    )
    db.add(new_trip)
    db.commit()
    db.refresh(new_trip)
    
    # 2. Auto-generate Days if dates are provided
    if trip.start_date and trip.end_date:
        delta = trip.end_date - trip.start_date
        days_count = delta.days + 1
        
        for i in range(days_count):
            current_date = trip.start_date + timedelta(days=i)
            # Simple weekday formatting (0=Mon, 6=Sun)
            weekday_map = ["週一", "週二", "週三", "週四", "週五", "週六", "週日"]
            weekday_str = weekday_map[current_date.weekday()]
            
            new_day = ItineraryDay(
                trip_id=new_trip.id,
                day_order=i + 1,
                date=current_date,
                weekday=weekday_str,
                title=f"Day {i + 1}"
            )
            db.add(new_day)
        
        db.commit()
        db.refresh(new_trip)
    
    return new_trip

@router.get("/trips/{trip_id}", response_model=schemas.TripResponse)
def get_trip(trip_id: str, db: Session = Depends(get_db)):
    trip = db.query(Trip).options(
        joinedload(Trip.days).joinedload(ItineraryDay.spots).joinedload(ItinerarySpot.place)
    ).filter(Trip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip

@router.put("/trips/{trip_id}", response_model=schemas.TripResponse)
def update_trip(trip_id: str, trip_update: schemas.TripUpdate, db: Session = Depends(get_db)):
    db_trip = db.query(Trip).filter(Trip.id == trip_id).first()
    if not db_trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    
    update_data = trip_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_trip, key, value)
    
    db.add(db_trip)
    db.commit()
    db.refresh(db_trip)
    return db_trip

@router.delete("/trips/{trip_id}")
def delete_trip(trip_id: str, db: Session = Depends(get_db)):
    trip = db.query(Trip).filter(Trip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    db.delete(trip)
    db.commit()
    return {"message": "Trip deleted successfully"}

# --- Spot Endpoints ---

@router.post("/days/{day_id}/spots", response_model=schemas.SpotResponse)
def add_spot(day_id: int, spot: schemas.SpotCreate, db: Session = Depends(get_db)):
    day = db.query(ItineraryDay).filter(ItineraryDay.id == day_id).first()
    if not day:
        raise HTTPException(status_code=404, detail="Day not found")
        
    # Calculate sort order (append to end)
    count = db.query(ItinerarySpot).filter(ItinerarySpot.day_id == day_id).count()
    
    # Resolve Place ID (Link to places table)
    final_place_id = spot.place_id
    
    if not final_place_id and spot.google_place_id:
        # Try to find existing place by External ID (stored in place_id column)
        existing_place = db.query(Place).filter(Place.place_id == spot.google_place_id).first()
        if existing_place:
            final_place_id = existing_place.id
        elif spot.place:
            # Create new Place from Pydantic model
            p_data = spot.place
            
            # opening_hours is already a dict in PlaceBase schema
            oh_data = p_data.opening_hours if p_data.opening_hours else None
            
            new_place = Place(
                place_id=spot.google_place_id,
                name=p_data.name or spot.name,
                address=p_data.address,
                latitude=p_data.latitude or spot.latitude,
                longitude=p_data.longitude or spot.longitude,
                category=p_data.category or spot.category,
                rating=p_data.rating,
                user_ratings_total=p_data.user_ratings_total,
                opening_hours=oh_data
            )
            db.add(new_place)
            db.commit()
            db.refresh(new_place)
            final_place_id = new_place.id
            
    new_spot = ItinerarySpot(
        id=str(uuid.uuid4()),
        day_id=day_id,
        place_id=final_place_id,
        name=spot.name,
        category=spot.category,
        start_time=spot.start_time,
        stay_duration=spot.stay_duration,
        notes=spot.notes,
        image_url=spot.image_url,
        latitude=spot.latitude,
        longitude=spot.longitude,
        sort_order=count,
        travel_mode=spot.travel_mode,
        travel_time=spot.travel_time,
        travel_distance=spot.travel_distance
    )
    
    db.add(new_spot)
    db.commit()
    
    # Eager load the place relationship to return full data (including opening_hours)
    # db.refresh(new_spot) might not load relationships
    from sqlalchemy.orm import joinedload
    full_spot = db.query(ItinerarySpot).options(joinedload(ItinerarySpot.place)).filter(ItinerarySpot.id == new_spot.id).first()
    
    return full_spot

@router.put("/spots/{spot_id}", response_model=schemas.SpotResponse)
def update_spot(spot_id: str, spot_update: schemas.SpotUpdate, db: Session = Depends(get_db)):
    spot = db.query(ItinerarySpot).filter(ItinerarySpot.id == spot_id).first()
    if not spot:
        raise HTTPException(status_code=404, detail="Spot not found")
    
    update_data = spot_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(spot, key, value)
    
    db.add(spot)
    db.commit()
    db.refresh(spot)
    return spot

@router.delete("/spots/{spot_id}")
def delete_spot(spot_id: str, db: Session = Depends(get_db)):
    spot = db.query(ItinerarySpot).filter(ItinerarySpot.id == spot_id).first()
    if not spot:
        raise HTTPException(status_code=404, detail="Spot not found")
    
    db.delete(spot)
    db.commit()
    return {"message": "Spot deleted"}

@router.post("/spots/reorder")
def reorder_spots(day_id: int, spot_ids: List[str], db: Session = Depends(get_db)):
    """
    Update sort_order for a list of spot IDs within a day
    """
    for index, spot_id in enumerate(spot_ids):
        spot = db.query(ItinerarySpot).filter(ItinerarySpot.id == spot_id, ItinerarySpot.day_id == day_id).first()
        if spot:
            spot.sort_order = index
            db.add(spot)
    
    db.commit()
    return {"message": "Spots reordered successfully"}

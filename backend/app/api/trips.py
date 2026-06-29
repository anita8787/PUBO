import uuid
import math
import json
from datetime import datetime
from typing import List
from fastapi import APIRouter, HTTPException, Depends
from firebase_admin import firestore
from ..models import schemas
from ..models.database import get_db

router = APIRouter()

def get_trips_ref(db):
    return db.collection("users").document("default_user").collection("trips")

def parse_datetime(val):
    if hasattr(val, "to_dict"):
        return val.astimezone().replace(tzinfo=None)
    if isinstance(val, str):
        try:
            return datetime.fromisoformat(val.replace('Z', '+00:00'))
        except ValueError:
            return None
    return val

def clean_float(val):
    if isinstance(val, float) and math.isnan(val):
        return None
    return val

def parse_list(val):
    if isinstance(val, str):
        try:
            parsed = json.loads(val)
            if isinstance(parsed, list):
                return parsed
        except Exception:
            pass
    if isinstance(val, list):
        return val
    return []

@router.get("/trips", response_model=List[schemas.TripResponse])
def get_trips(db_session=Depends(get_db)):
    db = db_session.db_client
    trips_ref = get_trips_ref(db)
    docs = trips_ref.get()
    
    results = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        data["created_at"] = parse_datetime(data.get("created_at")) or datetime.utcnow()
        data["updated_at"] = parse_datetime(data.get("updated_at")) or datetime.utcnow()
        data["start_date"] = parse_datetime(data.get("start_date"))
        data["end_date"] = parse_datetime(data.get("end_date"))
        data["cover_image_url"] = clean_float(data.get("cover_image_url"))
        
        # Load days and spots
        days_ref = doc.reference.collection("days").order_by("day_order").get()
        days_list = []
        for d_doc in days_ref:
            d_data = d_doc.to_dict()
            d_data["id"] = d_data.get("id") or int(d_doc.id) if d_doc.id.isdigit() else 0
            d_data["date"] = parse_datetime(d_data.get("date"))
            
            spots_ref = d_doc.reference.collection("spots").order_by("sort_order").get()
            spots_list = []
            for s_doc in spots_ref:
                s_data = s_doc.to_dict()
                s_data["id"] = str(s_data.get("id") or s_doc.id)
                s_data["day_id"] = d_data["id"]
                s_data["sort_order"] = s_data.get("sort_order", 0)
                s_data["latitude"] = clean_float(s_data.get("latitude"))
                s_data["longitude"] = clean_float(s_data.get("longitude"))
                s_data["place_id"] = clean_float(s_data.get("place_id"))
                s_data["notes"] = parse_list(s_data.get("notes"))
                spots_list.append(s_data)
                
            d_data["spots"] = spots_list
            days_list.append(d_data)
            
        data["days"] = days_list
        results.append(data)
        
    return results

@router.post("/trips", response_model=schemas.TripResponse)
def create_trip(trip: schemas.TripCreate, db_session=Depends(get_db)):
    db = db_session.db_client
    trips_ref = get_trips_ref(db)
    
    new_id = str(uuid.uuid4())
    now = datetime.utcnow()
    
    data = trip.dict()
    data["id"] = new_id
    data["created_at"] = now
    data["updated_at"] = now
    
    trips_ref.document(new_id).set(data)
    data["days"] = []
    return data

@router.get("/trips/{trip_id}", response_model=schemas.TripResponse)
def get_trip(trip_id: str, db_session=Depends(get_db)):
    db = db_session.db_client
    trip_ref = get_trips_ref(db).document(trip_id)
    doc = trip_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Trip not found")
        
    data = doc.to_dict()
    data["id"] = doc.id
    data["created_at"] = parse_datetime(data.get("created_at")) or datetime.utcnow()
    data["updated_at"] = parse_datetime(data.get("updated_at")) or datetime.utcnow()
    data["start_date"] = parse_datetime(data.get("start_date"))
    data["end_date"] = parse_datetime(data.get("end_date"))
    data["cover_image_url"] = clean_float(data.get("cover_image_url"))
    
    days_ref = trip_ref.collection("days").order_by("day_order").get()
    days_list = []
    for d_doc in days_ref:
        d_data = d_doc.to_dict()
        d_data["id"] = d_data.get("id") or int(d_doc.id) if d_doc.id.isdigit() else 0
        d_data["date"] = parse_datetime(d_data.get("date"))
        
        spots_ref = d_doc.reference.collection("spots").order_by("sort_order").get()
        spots_list = []
        for s_doc in spots_ref:
            s_data = s_doc.to_dict()
            s_data["id"] = str(s_data.get("id") or s_doc.id)
            s_data["day_id"] = d_data["id"]
            s_data["sort_order"] = s_data.get("sort_order", 0)
            s_data["latitude"] = clean_float(s_data.get("latitude"))
            s_data["longitude"] = clean_float(s_data.get("longitude"))
            s_data["place_id"] = clean_float(s_data.get("place_id"))
            s_data["notes"] = parse_list(s_data.get("notes"))
            spots_list.append(s_data)
            
        d_data["spots"] = spots_list
        days_list.append(d_data)
        
    data["days"] = days_list
    return data

@router.put("/trips/{trip_id}", response_model=schemas.TripResponse)
def update_trip(trip_id: str, trip_update: schemas.TripUpdate, db_session=Depends(get_db)):
    db = db_session.db_client
    trip_ref = get_trips_ref(db).document(trip_id)
    
    doc = trip_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Trip not found")
        
    update_data = {k: v for k, v in trip_update.dict().items() if v is not None}
    update_data["updated_at"] = datetime.utcnow()
    trip_ref.update(update_data)
    
    return get_trip(trip_id, db_session)

@router.delete("/trips/{trip_id}")
def delete_trip(trip_id: str, db_session=Depends(get_db)):
    db = db_session.db_client
    trip_ref = get_trips_ref(db).document(trip_id)
    trip_ref.delete()
    return {"message": "deleted"}

@router.post("/days/{day_id}/spots", response_model=schemas.SpotResponse)
def add_spot(day_id: int, spot: schemas.SpotCreate, db_session=Depends(get_db)):
    db = db_session.db_client
    
    days = db.collection_group("days").where("id", "==", day_id).limit(1).get()
    if not days:
        raise HTTPException(status_code=404, detail="Day not found")
        
    day_ref = days[0].reference
    new_spot_id = str(uuid.uuid4())
    
    data = spot.dict()
    data["id"] = new_spot_id
    data["sort_order"] = data.get("sort_order", 0)
    
    day_ref.collection("spots").document(new_spot_id).set(data)
    
    data["latitude"] = clean_float(data.get("latitude"))
    data["longitude"] = clean_float(data.get("longitude"))
    return data

@router.put("/spots/{spot_id}", response_model=schemas.SpotResponse)
def update_spot(spot_id: str, spot_update: schemas.SpotUpdate, db_session=Depends(get_db)):
    db = db_session.db_client
    spots = db.collection_group("spots").where("id", "==", spot_id).limit(1).get()
    if not spots:
        raise HTTPException(status_code=404, detail="Spot not found")
        
    spot_ref = spots[0].reference
    update_data = {k: v for k, v in spot_update.dict().items() if v is not None}
    spot_ref.update(update_data)
    
    updated_doc = spot_ref.get()
    data = updated_doc.to_dict()
    data["id"] = spot_id
    data["latitude"] = clean_float(data.get("latitude"))
    data["longitude"] = clean_float(data.get("longitude"))
    data["day_id"] = updated_doc.reference.parent.parent.id # or from data
    if "day_id" not in data:
        data["day_id"] = 0
    data["sort_order"] = data.get("sort_order", 0)
    return data

@router.delete("/spots/{spot_id}")
def delete_spot(spot_id: str, db_session=Depends(get_db)):
    db = db_session.db_client
    spots = db.collection_group("spots").where("id", "==", spot_id).limit(1).get()
    if not spots:
        raise HTTPException(status_code=404, detail="Spot not found")
        
    spots[0].reference.delete()
    return {"message": "deleted"}

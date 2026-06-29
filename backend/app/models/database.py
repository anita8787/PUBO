import os
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import json
import math
from dotenv import load_dotenv

load_dotenv()

# Helper to map string ID to unique int for Place.id and Content.id
import hashlib

def get_int_id(string_id: str) -> int:
    if not string_id:
        return 0
    # Use MD5 to get a deterministic hash across Python restarts
    return int(hashlib.md5(string_id.encode('utf-8')).hexdigest()[:8], 16) % (10**9)

class FieldAttribute:
    def __init__(self, name):
        self.name = name
    def __eq__(self, other):
        return ("==", self.name, other)
    def __ne__(self, other):
        return ("!=", self.name, other)
    def desc(self):
        return ("desc", self.name)

class FirestoreModelMeta(type):
    def __new__(cls, name, bases, attrs):
        # Automatically set FieldAttributes for properties to support filter expression comparison
        for key, val in list(attrs.items()):
            if not key.startswith("_") and key not in ["collection", "id_field"] and not callable(val) and not isinstance(val, property) and not isinstance(val, classmethod) and not isinstance(val, staticmethod):
                attrs[key] = FieldAttribute(key)
        return super().__new__(cls, name, bases, attrs)

class FirestoreModel(metaclass=FirestoreModelMeta):
    collection = ""
    id_field = "id"

    def __init__(self, _doc_id=None, **kwargs):
        self._doc_id = _doc_id
        
        # Initialize field attributes to None on the instance so they don't fallback to Class-level FieldAttributes
        for cls in self.__class__.__mro__:
            for key, val in cls.__dict__.items():
                if isinstance(val, FieldAttribute):
                    setattr(self, key, None)
        
        # Populate attributes
        for key, val in kwargs.items():
            if not key.startswith("_"):
                # Skip read-only property fields (like id or places)
                prop = getattr(self.__class__, key, None)
                if isinstance(prop, property):
                    continue
                
                # Clean NaN float values to None
                if isinstance(val, float) and math.isnan(val):
                    val = None
                    
                # Clean user_tags JSON string to list
                if key == "user_tags" and isinstance(val, str):
                    try:
                        val = json.loads(val)
                    except Exception:
                        val = []
                        
                setattr(self, key, val)
                
    def to_dict(self):
        d = {}
        for key, val in self.__dict__.items():
            if not key.startswith("_"):
                if isinstance(val, datetime):
                    d[key] = val
                else:
                    d[key] = val
        return d

# --- Define Firestore Models ---

class Content(FirestoreModel):
    collection = "contents"
    id_field = "id"

    # Define fields so Python type checkers are happy
    source_type = None
    source_url = None
    title = None
    text = None
    author_name = None
    author_avatar_url = None
    preview_thumbnail_url = None
    published_at = None
    user_tags = None
    is_collected = None
    created_at = None

    @property
    def id(self) -> int:
        return get_int_id(self.source_url)
        
    @property
    def places(self):
        return getattr(self, "_places", [])

class Place(FirestoreModel):
    collection = "places"
    id_field = "id"

    place_id = None
    name = None
    address = None
    latitude = None
    longitude = None
    category = None
    image_url = None
    rating = None
    user_ratings_total = None
    opening_hours = None
    created_at = None

    @property
    def id(self) -> int:
        # Pydantic expects id to be int
        return get_int_id(self.place_id or self.name)

class ContentPlaceAssociation(FirestoreModel):
    collection = "content_place_association"
    id_field = "id"

    content_id = None
    place_id = None
    evidence_text = None
    confidence_score = None
    is_manual_override = None

    @property
    def id(self) -> int:
        return get_int_id(f"{self.content_id}_{self.place_id}")

class Task(FirestoreModel):
    collection = "tasks"
    id_field = "task_id"

    task_id = None
    status = None
    progress = None
    target_url = None
    result = None
    error = None
    created_at = None
    updated_at = None

class CuratedPost(FirestoreModel):
    collection = "curated_posts"
    id_field = "id"

    title = None
    cover_image = None
    author = None
    source_url = None
    spots = None
    spot_count = None
    country = None
    trip_category = None
    uploader_id = None
    created_at = None

    def __init__(self, _doc_id=None, **kwargs):
        super().__init__(_doc_id=_doc_id, **kwargs)
        if isinstance(self.spots, str):
            try:
                self.spots = json.loads(self.spots)
            except Exception:
                pass

class PlaceCache(FirestoreModel):
    collection = "place_cache"
    id_field = "search_key"

    search_key = None
    place_id = None
    google_place_id = None
    status = None
    created_at = None
    updated_at = None

class AIAnalysisCache(FirestoreModel):
    collection = "ai_analysis_cache"
    id_field = "id"

    place_name = None
    address = None
    result = None
    created_at = None
    updated_at = None

class FirestoreQuery:
    def __init__(self, model_class, session):
        self.model_class = model_class
        self.session = session
        self.filters = []
        self.order_by_field = None
        self.order_by_desc = False
        self.offset_val = None
        self.limit_val = None

    def filter(self, *expressions):
        for expr in expressions:
            if isinstance(expr, tuple) and len(expr) == 3:
                self.filters.append(expr)
        return self

    def order_by(self, expression):
        if isinstance(expression, tuple) and len(expression) == 2 and expression[0] == "desc":
            self.order_by_field = expression[1]
            self.order_by_desc = True
        elif isinstance(expression, FieldAttribute):
            self.order_by_field = expression.name
            self.order_by_desc = False
        return self

    def offset(self, val):
        self.offset_val = val
        return self

    def limit(self, val):
        self.limit_val = val
        return self

    def options(self, *args):
        # Ignore SQLAlchemy options like joinedload
        return self

    def _execute(self):
        coll_ref = self.session.db_client.collection(self.model_class.collection)
        query = coll_ref
        
        # Apply filters
        for op, field, val in self.filters:
            query = query.where(field, op, val)
            
        # Apply ordering
        if self.order_by_field:
            direction = firestore.Query.DESCENDING if self.order_by_desc else firestore.Query.ASCENDING
            query = query.order_by(self.order_by_field, direction=direction)
            
        # Apply offset and limit
        if self.offset_val is not None:
            query = query.offset(self.offset_val)
        if self.limit_val is not None:
            query = query.limit(self.limit_val)
            
        docs = query.get()
        results = []
        for d in docs:
            doc_data = d.to_dict()
            # Map created_at/updated_at timestamps to datetime
            for k, v in list(doc_data.items()):
                if isinstance(v, datetime):
                    doc_data[k] = v.astimezone().replace(tzinfo=None) if v.tzinfo else v
                elif hasattr(v, "to_dict"): # Firestore timestamp object
                    doc_data[k] = v.astimezone().replace(tzinfo=None)
                elif k in ["created_at", "updated_at"] and isinstance(v, str):
                    try:
                        v_clean = v.replace("Z", "+00:00")
                        doc_data[k] = datetime.fromisoformat(v_clean).replace(tzinfo=None)
                    except Exception:
                        pass
            inst = self.model_class(_doc_id=d.id, **doc_data)
            results.append(inst)
            self.session.tracked_objects.append(inst)
            
        # Eager load relations for Content
        if self.model_class == Content:
            for content in results:
                content_id = content.id
                assoc_query = self.session.db_client.collection("content_place_association").where("content_id", "==", content_id)
                assoc_docs = assoc_query.get()
                
                places_info = []
                place_associations = []
                for assoc_doc in assoc_docs:
                    assoc_data = assoc_doc.to_dict()
                    assoc_inst = ContentPlaceAssociation(_doc_id=assoc_doc.id, **assoc_data)
                    place_associations.append(assoc_inst)
                    self.session.tracked_objects.append(assoc_inst)
                    
                    p_id = assoc_data.get("place_id")
                    place_query = self.session.db_client.collection("places").where("id", "==", p_id)
                    place_docs = place_query.limit(1).get()
                    if place_docs:
                        p_doc = place_docs[0]
                        place_inst = Place(_doc_id=p_doc.id, **p_doc.to_dict())
                        self.session.tracked_objects.append(place_inst)
                        assoc_inst.place = place_inst
                        
                        places_info.append({
                            "place": place_inst,
                            "evidence_text": assoc_data.get("evidence_text"),
                            "confidence_score": assoc_data.get("confidence_score", 0.0)
                        })
                content._place_associations = place_associations
                content._places = places_info
                
        return results

    def all(self):
        return self._execute()

    def first(self):
        self.limit(1)
        res = self._execute()
        return res[0] if res else None

    def count(self):
        return len(self._execute())

class FirestoreSession:
    def __init__(self, db_client):
        self.db_client = db_client
        self.pending_adds = []
        self.pending_deletes = []
        self.tracked_objects = []

    def query(self, model_class):
        return FirestoreQuery(model_class, self)

    def add(self, obj):
        self.pending_adds.append(obj)

    def delete(self, obj):
        self.pending_deletes.append(obj)

    def commit(self):
        all_objects = list(self.pending_adds)
        existing_ids = {id(o) for o in all_objects}
        for obj in self.tracked_objects:
            if id(obj) not in existing_ids:
                all_objects.append(obj)
                existing_ids.add(id(obj))
                
        for obj in all_objects:
            coll_ref = self.db_client.collection(obj.collection)
            data = obj.to_dict()
            
            # Auto populate created_at/updated_at if missing
            now = datetime.utcnow()
            if hasattr(obj, "created_at") and getattr(obj, "created_at", None) is None:
                data["created_at"] = now
                obj.created_at = now
            if hasattr(obj, "updated_at") and getattr(obj, "updated_at", None) is None:
                data["updated_at"] = now
                obj.updated_at = now

            # Decide document ID
            doc_id = getattr(obj, "_doc_id", None)
            if not doc_id:
                id_val = getattr(obj, obj.id_field, None)
                if id_val is not None:
                    doc_id = str(id_val)
                    
            if doc_id:
                coll_ref.document(doc_id).set(data)
                obj._doc_id = doc_id
            else:
                ref = coll_ref.document()
                ref.set(data)
                obj._doc_id = ref.id
                
        for obj in self.pending_deletes:
            doc_id = getattr(obj, "_doc_id", None)
            if not doc_id:
                id_val = getattr(obj, obj.id_field, None)
                if id_val is not None:
                    doc_id = str(id_val)
            if doc_id:
                self.db_client.collection(obj.collection).document(doc_id).delete()
                
        self.pending_adds.clear()
        self.pending_deletes.clear()

    def refresh(self, obj):
        pass

    def rollback(self):
        self.pending_adds.clear()
        self.pending_deletes.clear()

    def close(self):
        pass

class FirestoreSessionLocal:
    def __call__(self):
        if not firebase_admin._apps:
            firebase_admin.initialize_app()
        db_client = firestore.client()
        return FirestoreSession(db_client)

SessionLocal = FirestoreSessionLocal()

def init_db():
    # Firestore schema does not need initialization
    pass

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

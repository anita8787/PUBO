from app.models.database import Content, ContentPlaceAssociation
from app.main import get_db

db = next(get_db())
c = db.query(Content).first()
if c is None:
    print("No content found")
else:
    print(f"Content ID: {c.id} (type: {type(c.id)})")
    
    any_assoc = db.query(ContentPlaceAssociation).limit(1).first()
    if any_assoc:
        print(f"Sample Assoc content_id: {any_assoc.content_id} (type: {type(any_assoc.content_id)})")
    else:
        print("No associations found")

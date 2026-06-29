from app.models.database import Content, ContentPlaceAssociation
from app.api.dependencies import get_db

db = next(get_db())

url = "https://www.instagram.com/p/C69n1q4P3z_/" # A random IG URL, maybe we can just query the first content
c = db.query(Content).first()
if c:
    print(f"Content ID: {c.id} (type: {type(c.id)})")
    assoc = db.query(ContentPlaceAssociation).filter(ContentPlaceAssociation.content_id == c.id).all()
    print(f"Assocs: {len(assoc)}")
    if len(assoc) == 0:
        # Check if content_id is string
        assoc_str = db.query(ContentPlaceAssociation).filter(ContentPlaceAssociation.content_id == str(c.id)).all()
        print(f"Assocs (str): {len(assoc_str)}")
        
        # Or let's just query any assoc
        any_assoc = db.query(ContentPlaceAssociation).limit(1).first()
        if any_assoc:
            print(f"Sample Assoc content_id: {any_assoc.content_id} (type: {type(any_assoc.content_id)})")

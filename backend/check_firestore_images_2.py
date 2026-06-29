import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    cred = credentials.Certificate('firebase-key.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()
docs = db.collection('curated_posts').get()
for d in docs:
    data = d.to_dict()
    print(f"{data.get('title')}: {data.get('cover_image')}")

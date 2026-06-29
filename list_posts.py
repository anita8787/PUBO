import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

posts = db.collection("curated_posts").get()
for p in posts:
    data = p.to_dict()
    print(f"ID: {p.id}, Title: {data.get('title')}, Image: {data.get('image_url')}")

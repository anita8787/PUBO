import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    cred = credentials.Certificate('firebase-key.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()
docs = db.collection('curated_posts').limit(1).get()
if docs:
    print(docs[0].to_dict())

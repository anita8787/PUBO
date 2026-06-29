import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    cred = credentials.Certificate('firebase-key.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()
for d in db.collection('curated_posts').get():
    print(d.to_dict().get('title'))

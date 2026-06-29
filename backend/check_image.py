import firebase_admin
from firebase_admin import credentials, storage

if not firebase_admin._apps:
    cred = credentials.Certificate('firebase-key.json')
    firebase_admin.initialize_app(cred, {'storageBucket': 'pubo-production.firebasestorage.app'})

bucket = storage.bucket()
blob = bucket.blob("pubo-images/af01bf22d9134a3382236d133c545c58.jpg")
print(f"Exists: {blob.exists()}")

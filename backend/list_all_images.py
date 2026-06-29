import firebase_admin
from firebase_admin import credentials, storage

if not firebase_admin._apps:
    cred = credentials.Certificate('firebase-key.json')
    firebase_admin.initialize_app(cred, {'storageBucket': 'pubo-production.firebasestorage.app'})

bucket = storage.bucket()
blobs = list(bucket.list_blobs(max_results=50))
print(f"Total blobs found: {len(blobs)}")
for b in blobs:
    print(b.name)

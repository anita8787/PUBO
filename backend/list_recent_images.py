import firebase_admin
from firebase_admin import credentials, storage
from datetime import datetime, timezone, timedelta

if not firebase_admin._apps:
    cred = credentials.Certificate('firebase-key.json')
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'pubo-production.firebasestorage.app'
    })

bucket = storage.bucket()
blobs = bucket.list_blobs(prefix="pubo-images/")
recent_blobs = []
now = datetime.now(timezone.utc)
# Look for images uploaded in the last 2 days
for blob in blobs:
    if blob.time_created > now - timedelta(days=2):
        recent_blobs.append(blob)

recent_blobs.sort(key=lambda x: x.time_created, reverse=True)
print(f"Found {len(recent_blobs)} recent images:")
for b in recent_blobs:
    print(f"{b.name} - {b.time_created} - {b.public_url}")

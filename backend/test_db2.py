import os
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "firebase-key.json"
from google.cloud import firestore
db = firestore.Client(project="pubo-production")
docs = db.collection("curated_posts").stream()
for doc in docs:
    data = doc.to_dict()
    print(f"- {data.get('title')}: {data.get('cover_image')}")

import os
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "firebase-key.json"
from google.cloud import firestore
db = firestore.Client(project="pubo-production")
docs = db.collection("contents").stream()
count = 0
for doc in docs:
    data = doc.to_dict()
    url = data.get("preview_thumbnail_url", "")
    if url and "pubo-images/" in url:
        new_url = url.replace("pubo-images/", "pubo_image/")
        doc.reference.update({"preview_thumbnail_url": new_url})
        count += 1
print(f"Fixed {count} contents.")

import os
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "firebase-key.json"
from google.cloud import firestore
db = firestore.Client(project="pubo-production")
docs = db.collection("curated_posts").where("title", "==", "東京｜高円寺6間逛街小店(下）").stream()

for doc in docs:
    print(f"Deleting: {doc.to_dict().get('title')}")
    db.collection("curated_posts").document(doc.id).delete()

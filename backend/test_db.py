import os
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "firebase-key.json"
from google.cloud import firestore
db = firestore.Client(project="pubo-production")
docs = db.collection("curated_posts").stream()
posts = list(docs)
print("Total CuratedPosts:", len(posts))
for p in posts:
    data = p.to_dict()
    print(f"- {data.get('title')} (URL: {data.get('source_url')})")

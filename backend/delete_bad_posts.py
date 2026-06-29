import os
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "firebase-key.json"
from google.cloud import firestore
db = firestore.Client(project="pubo-production")
docs = db.collection("curated_posts").stream()

for doc in docs:
    data = doc.to_dict()
    title = data.get("title", "")
    image = data.get("cover_image", "")
    # The new ones have 'pubo_image' or 'pubo-images' in the url. 
    # Or valid images. 
    # Let's keep the ones uploaded today, or specifically the 3 recent ones from the user.
    if title not in ["東京｜高円寺6間逛街小店(下）", "日本東京｜高円寺7間逛街小店(上）", "日本東京｜吉祥寺5間必逛的店"]:
        print(f"Deleting old post: {title}")
        db.collection("curated_posts").document(doc.id).delete()
    else:
        print(f"Keeping valid post: {title}")

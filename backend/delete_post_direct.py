from firebase_admin import credentials, firestore, initialize_app
import os

initialize_app()
db = firestore.client()

posts = db.collection("curated_posts").get()
for post in posts:
    data = post.to_dict()
    if data and "吉祥寺" in data.get("title", ""):
        db.collection("curated_posts").document(post.id).delete()
        print(f"Deleted post: {data.get('title')}")

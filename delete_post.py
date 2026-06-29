from firebase_admin import credentials, firestore, initialize_app
import os

cred = credentials.Certificate("backend/serviceAccountKey.json")
initialize_app(cred)
db = firestore.client()

posts = db.collection("curated_posts").where("title", "==", "吉祥寺五間必逛的店").get()
for post in posts:
    db.collection("curated_posts").document(post.id).delete()
    print(f"Deleted post: {post.id}")

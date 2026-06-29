import os
import sys

# 確保可以 import app
sys.path.append("/Users/anita/Cursor/PUBO/backend")

from app.models.database import get_db, Task, Content, ContentPlaceAssociation
import firebase_admin

db = next(get_db())

print("Cleaning up broken tasks...")
tasks = db.db_client.collection("tasks").get()
for t in tasks:
    data = t.to_dict()
    res = data.get("result", {})
    if res and isinstance(res, dict):
        places = res.get("suggested_places", [])
        if any("ma to ga" in p.get("place", {}).get("name", "") for p in places):
            if len(places) > 1: # "ma to ga" 5 times
                print(f"Deleting broken task: {t.id}")
                db.db_client.collection("tasks").document(t.id).delete()

print("Cleaning up broken contents...")
contents = db.db_client.collection("contents").get()
for c in contents:
    data = c.to_dict()
    title = data.get("title", "")
    if "吉祥寺5間必逛的店" in title:
        print(f"Deleting broken content: {c.id}")
        db.db_client.collection("contents").document(c.id).delete()
        # Delete associations
        assocs = db.db_client.collection("content_place_association").where("content_id", "==", c.id).get()
        for a in assocs:
            db.db_client.collection("content_place_association").document(a.id).delete()

print("Done.")

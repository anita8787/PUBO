from app.models.database import SessionLocal, CuratedPost
db = SessionLocal()
posts = db.query(CuratedPost).all()
for p in posts:
    if "吉祥寺" in p.title:
        db.delete(p)
        print("Deleted: " + str(p.title))
db.commit()
db.close()

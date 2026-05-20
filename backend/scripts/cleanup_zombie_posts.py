import os
import sys
from sqlalchemy.orm import Session
from dotenv import load_dotenv

# Add parent directory to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.models.database import SessionLocal, CuratedPost

def cleanup_db():
    print("🧹 Starting Database Cleanup (Zombie & Duplicate Posts)...")
    db = SessionLocal()
    
    # 1. 刪除景點數為 0 的貼文
    zombies = db.query(CuratedPost).filter(CuratedPost.spot_count == 0).all()
    zombie_count = len(zombies)
    for z in zombies:
        print(f"   🗑️ Deleting zombie (0 spots): {z.title}")
        db.delete(z)
        
    # 2. 刪除重複的網址 (保留最新的一筆)
    all_posts = db.query(CuratedPost).order_by(CuratedPost.created_at.desc()).all()
    seen_urls = set()
    duplicate_count = 0
    
    for p in all_posts:
        if p.source_url in seen_urls:
            print(f"   🗑️ Deleting duplicate URL: {p.title} ({p.source_url})")
            db.delete(p)
            duplicate_count += 1
        else:
            seen_urls.add(p.source_url)
            
    if zombie_count > 0 or duplicate_count > 0:
        db.commit()
        print(f"🎉 Cleanup Finished!")
        print(f"   - Removed {zombie_count} zombie posts.")
        print(f"   - Removed {duplicate_count} duplicate posts.")
    else:
        print("🙌 Database is already clean. No action needed.")
    
    db.close()

if __name__ == "__main__":
    load_dotenv()
    cleanup_db()

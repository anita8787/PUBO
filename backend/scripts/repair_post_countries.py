import os
import sys
import asyncio
from sqlalchemy.orm import Session
from dotenv import load_dotenv

# Add parent directory to sys.path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.models.database import SessionLocal, CuratedPost
from app.services.nlp_service import NLPService

async def repair_countries():
    print("🚀 Starting Country Repair for Curated Posts...")
    db = SessionLocal()
    nlp = NLPService()
    
    posts = db.query(CuratedPost).all()
    updated_count = 0
    
    for post in posts:
        # We re-evaluate all posts, but especially those marked as '韓國'
        old_country = post.country
        title = post.title
        # Attempt to get text from some cached source if available, 
        # but for repair, title and spots are often enough.
        spots = post.spots if isinstance(post.spots, list) else []
        
        print(f"🔍 Analyzing: {title} (Current: {old_country})")
        
        # Simple heuristic or AI call
        new_country = nlp.detect_country(title, "", spots)
        
        if new_country != old_country:
            print(f"✅ Found Mismatch! Updating '{old_country}' -> '{new_country}'")
            post.country = new_country
            updated_count += 1
        else:
            print(f"➖ Country remains '{old_country}'")

    if updated_count > 0:
        db.commit()
        print(f"🎉 Successfully updated {updated_count} posts!")
    else:
        print("🙌 No mismatches found. Database is already accurate.")
    
    db.close()

if __name__ == "__main__":
    load_dotenv()
    asyncio.run(repair_countries())

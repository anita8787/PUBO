import os
import sys
from dotenv import load_dotenv

# Add the current directory to sys.path to import app
sys.path.append(os.getcwd())

from app.models.database import init_db, SessionLocal, Content, Place

def test_connection():
    load_dotenv()
    db_url = os.getenv("SUPABASE_DB_URL")
    print(f"🚀 Initializing Cloud Database: {db_url[:20]}...")
    
    try:
        # 1. Create tables
        init_db()
        print("✅ Tables created or already exist.")
        
        # 2. Test session
        db = SessionLocal()
        content_count = db.query(Content).count()
        place_count = db.query(Place).count()
        print(f"✅ Connection successful!")
        print(f"📊 Current Cloud Stats: {content_count} contents, {place_count} places.")
        db.close()
        return True
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False

if __name__ == "__main__":
    test_connection()

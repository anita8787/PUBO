import os
import sys
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Add current directory to sys.path
sys.path.append(os.getcwd())
from app.models.database import CuratedPost, Place

def repair_curated_spots():
    load_dotenv()
    db_url = os.getenv("SUPABASE_DB_URL")
    if not db_url:
        print("❌ Error: SUPABASE_DB_URL not found.")
        return

    print("🔧 Repairing CuratedPost spots with missing place_ids...")
    engine = create_engine(db_url)
    Session = sessionmaker(bind=engine)
    db = Session()

    try:
        posts = db.query(CuratedPost).all()
        for post in posts:
            if not post.spots:
                continue
            
            modified = False
            new_spots = []
            for spot in post.spots:
                # 如果缺少 place_id，嘗試去 places 表找
                if "place_id" not in spot or not spot["place_id"]:
                    name = spot.get("name")
                    print(f"  🔍 Finding ID for: {name}")
                    
                    # 模糊匹配名稱或精確匹配座標 (如果有的話)
                    place = db.query(Place).filter(Place.name == name).first()
                    if place:
                        spot["place_id"] = place.place_id
                        modified = True
                        print(f"  ✅ Found ID: {place.place_id}")
                    else:
                        # 如果找不到，產出一個基於名稱的 ID 至少防止 UI 崩潰
                        spot["place_id"] = f"ref_{name.replace(' ', '_')}"
                        modified = True
                        print(f"  ⚠️ Could not find exact match, using ref ID.")
                
                new_spots.append(spot)
            
            if modified:
                post.spots = new_spots
                # SQLAlchemy JSON 變更可能需要 flag_modified
                from sqlalchemy.orm.attributes import flag_modified
                flag_modified(post, "spots")
                print(f"💾 Updated Post: {post.title}")
        
        db.commit()
        print("\n🎉 Repair complete!")

    except Exception as e:
        print(f"❌ Repair failed: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    repair_curated_spots()

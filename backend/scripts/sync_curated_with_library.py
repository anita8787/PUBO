import os
import sys
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Add current directory to sys.path
sys.path.append(os.getcwd())
try:
    from app.models.database import CuratedPost, Content
    from app.services.image_service import ImageService
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)

def sync_curated_with_library():
    load_dotenv()
    db_url = os.getenv("SUPABASE_DB_URL")
    if not db_url:
        print("❌ Error: SUPABASE_DB_URL not found.")
        return

    print("🔄 [Sync] Syncing CuratedPosts with Library Collection (Data Restoration)...")
    
    # Init DB
    engine = create_engine(db_url)
    Session = sessionmaker(bind=engine)
    db = Session()
    
    image_service = ImageService()

    try:
        curated_posts = db.query(CuratedPost).all()
        sync_count = 0
        
        for post in curated_posts:
            print(f"\n🔍 Checking Recommendation: {post.title}")
            
            # Find matching content in the library (which the user says looks correct)
            content = db.query(Content).filter(Content.source_url == post.source_url).first()
            
            if content:
                print(f"  ✅ FOUND library match for URL: {post.source_url}")
                
                # 1. Restore Spots from Library
                spots_data = []
                for ass in content.place_associations:
                    place = ass.place
                    if place:
                        spots_data.append({
                            "name": place.name,
                            "place_id": place.place_id,
                            "category": place.category,
                            "latitude": place.latitude,
                            "longitude": place.longitude,
                            "address": place.address
                        })
                
                if spots_data:
                    post.spots = spots_data
                    post.spot_count = len(spots_data)
                    print(f"  📍 Restored {len(spots_data)} spots from collection.")
                else:
                    print(f"  ⚠️ Warning: Library content has 0 spots associated.")
                
                # 2. Restore Image (Force persistent link)
                if content.preview_thumbnail_url:
                    print(f"  ☁️ Migrating library image to Supabase...")
                    permanent_url = image_service.upload_to_supabase(content.preview_thumbnail_url)
                    if "supabase.co" in permanent_url:
                        post.cover_image = permanent_url
                        print(f"  🖼 Image Restored: {permanent_url[:60]}...")
                    else:
                        print(f"  ❌ Failed to upload image.")
                
                # 3. Sync Author
                if content.author_name:
                    post.author = content.author_name

                sync_count += 1
            else:
                print(f"  ⏩ No library match found. Skipping sync for this post.")

        db.commit()
        print(f"\n🎉 Sync & Restoration complete!")
        print(f"✅ Updated Curated Posts: {sync_count}")

    except Exception as e:
        print(f"❌ Sync failed: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    sync_curated_with_library()

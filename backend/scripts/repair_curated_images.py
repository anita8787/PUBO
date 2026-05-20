import os
import sys
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Add current directory to sys.path
sys.path.append(os.getcwd())
try:
    from app.models.database import CuratedPost
    from app.services.image_service import ImageService
    from app.services.apify_service import ApifyService
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)

def repair_curated_images():
    load_dotenv()
    db_url = os.getenv("SUPABASE_DB_URL")
    if not db_url:
        print("❌ Error: SUPABASE_DB_URL not found.")
        return

    print("🔧 [Script] Repairing CuratedPost cover images (Migrating to Supabase Storage)...")
    
    # Init DB
    engine = create_engine(db_url)
    Session = sessionmaker(bind=engine)
    db = Session()
    
    # Init Services
    image_service = ImageService()
    apify_service = ApifyService()

    try:
        posts = db.query(CuratedPost).all()
        repair_count = 0
        failure_count = 0
        
        for post in posts:
            img_url = post.cover_image or ""
            already_in_supabase = "supabase.co" in img_url
            
            if already_in_supabase:
                print(f"⏩ Skipping (Already persistent): {post.title}")
                continue

            print(f"\n🔄 Processing: {post.title}")
            print(f"  👉 Current URL is external/ephemeral.")
            
            new_thumb_to_upload = None
            
            # Step 1: Try to re-fetch fresh URL if it's Instagram
            if post.source_url and "instagram.com" in post.source_url:
                print(f"  📸 Re-scraping Instagram source: {post.source_url}")
                try:
                    insta_info = apify_service.extract_instagram_post(post.source_url)
                    if insta_info and insta_info.get("preview_thumbnail_url"):
                        new_thumb_to_upload = insta_info["preview_thumbnail_url"]
                        print(f"  ✅ Got fresh thumbnail from Apify.")
                    else:
                        print(f"  ⚠️ Could not find thumbnail in scraped data.")
                except Exception as e:
                    print(f"  ⚠️ Scraping failed: {e}")
            
            # Step 2: Fallback - use the current link if re-scraping failed
            # If the current link hasn't expired yet, we can still save it.
            target_url = new_thumb_to_upload or img_url
            
            if target_url:
                print(f"  ☁️ Uploading to Supabase...")
                permanent_url = image_service.upload_to_supabase(target_url)
                
                if "supabase.co" in permanent_url:
                    post.cover_image = permanent_url
                    repair_count += 1
                    print(f"  🚀 SUCCESS! Permanent URL: {permanent_url[:60]}...")
                else:
                    failure_count += 1
                    print(f"  ❌ Failed to upload to Supabase.")
            else:
                print(f"  ⚠️ No image source found for this post.")

        db.commit()
        print(f"\n🎉 Repair process complete!")
        print(f"✅ Repaired: {repair_count}")
        print(f"❌ Failed: {failure_count}")

    except Exception as e:
        print(f"❌ Process error: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    repair_curated_images()

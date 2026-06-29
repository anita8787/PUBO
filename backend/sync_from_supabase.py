import os
import sys
import json
import sqlalchemy
from sqlalchemy import create_engine, text

# Add current directory to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app.models.database import CuratedPost, Place, SessionLocal
from app.services.image_service import ImageService

def main():
    print("🚀 Connecting to Supabase Cloud Database...")
    supabase_url = 'postgresql://postgres.tixmkecbyeeehajlxpbo:fucbu9-xiwnus-giKmem@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres'
    supabase_engine = create_engine(supabase_url)
    
    local_db = SessionLocal()
    image_service = ImageService()
    
    try:
        # 1. 為了確保資料整潔與修復空白貼文，清空本地 SQLite 的 curated_posts 和 places 表
        print("🧹 Cleaning up local curated_posts and places tables...")
        local_db.execute(text("DELETE FROM curated_posts"))
        local_db.execute(text("DELETE FROM places"))
        local_db.commit()
        local_db.expunge_all()
        
        # 2. 從 Supabase 讀取所有景點資料
        print("📥 Fetching places from Supabase...")
        with supabase_engine.connect() as conn:
            places_res = conn.execute(text("SELECT id, place_id, name, address, latitude, longitude, category, image_url, rating, user_ratings_total, opening_hours, created_at FROM places"))
            places_rows = places_res.fetchall()
            
            print(f"💾 Syncing {len(places_rows)} places to local SQLite...")
            for row in places_rows:
                # 處理營業時間 JSON
                oh_data = row[10]
                if isinstance(oh_data, str):
                    try:
                        oh_data = json.loads(oh_data)
                    except:
                        pass
                
                # 景點封面圖轉存至 Firebase Storage (若原網址為 Supabase 或過期 Instagram CDN)
                image_url = row[7]
                if image_url and ("supabase.co" in image_url or "cdninstagram.com" in image_url or "fbcdn.net" in image_url):
                    print(f"  ☁️ Migrating place image to Firebase: {row[2]}...")
                    image_url = image_service.upload_to_firebase(image_url)
                
                new_place = Place(
                    id=row[0],
                    place_id=row[1],
                    name=row[2],
                    address=row[3],
                    latitude=row[4],
                    longitude=row[5],
                    category=row[6],
                    image_url=image_url,
                    rating=row[8],
                    user_ratings_total=row[9],
                    opening_hours=oh_data,
                    created_at=row[11]
                )
                local_db.add(new_place)
            local_db.commit()
            
            # 3. 從 Supabase 讀取所有高畫質推薦貼文資料
            print("📥 Fetching curated posts from Supabase...")
            posts_res = conn.execute(text("SELECT id, title, cover_image, author, source_url, spots, spot_count, country, created_at FROM curated_posts"))
            posts_rows = posts_res.fetchall()
            
            print(f"💾 Syncing {len(posts_rows)} curated posts to local SQLite...")
            for row in posts_rows:
                # 處理景點清單 JSON
                spots_data = row[5]
                if isinstance(spots_data, str):
                    try:
                        spots_data = json.loads(spots_data)
                    except:
                        pass
                
                # 貼文封面圖轉存至 Firebase Storage (若原網址為 Supabase 或過期 Instagram CDN)
                cover_image = row[2]
                if cover_image and ("supabase.co" in cover_image or "cdninstagram.com" in cover_image or "fbcdn.net" in cover_image):
                    print(f"  ☁️ Migrating curated post cover image to Firebase: {row[1]}...")
                    # 利用 Apify 重新抓取未過期的貼文原圖以進行高畫質 Firebase 轉存 (如果可以直接下載原圖則用 ImageService)
                    cover_image = image_service.upload_to_firebase(cover_image)
                
                new_post = CuratedPost(
                    id=row[0],
                    title=row[1],
                    cover_image=cover_image,
                    author=row[3],
                    source_url=row[4],
                    spots=spots_data,
                    spot_count=row[6],
                    country=row[7],
                    created_at=row[8]
                )
                local_db.add(new_post)
            local_db.commit()
            
        print("\n🎉 Supabase data sync & Firebase Storage image migration complete!")
        
        # Verify counts in local SQLite
        places_count = local_db.query(Place).count()
        posts_count = local_db.query(CuratedPost).count()
        print(f"📊 Verified SQLite count - Places: {places_count}, CuratedPosts: {posts_count}")
        
    except Exception as e:
        print(f"❌ Error during sync: {e}")
        local_db.rollback()
    finally:
        local_db.close()

if __name__ == "__main__":
    main()

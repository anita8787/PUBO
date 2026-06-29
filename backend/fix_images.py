import sys
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models.database import CuratedPost

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
from app.services.image_service import ImageService
from app.services.apify_service import ApifyService

DATABASE_URL = "sqlite:///./pubo.db"
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)
session = Session()

image_service = ImageService()
apify_service = ApifyService()

posts = session.query(CuratedPost).all()
for post in posts:
    if post.cover_image and ("cdninstagram.com" in post.cover_image or "fbcdn.net" in post.cover_image):
        print(f"\n🔄 Processing post: '{post.title}'")
        print(f"  🔗 Source URL: {post.source_url}")
        
        # 透過 Apify 重新爬取該 Instagram 貼文，獲取未過期的最新圖片網址
        new_thumb_url = None
        if post.source_url and "instagram.com" in post.source_url:
            print("  📸 Re-scraping Instagram post via Apify...")
            try:
                insta_info = apify_service.extract_instagram_post(post.source_url)
                if insta_info and insta_info.get("preview_thumbnail_url"):
                    new_thumb_url = insta_info["preview_thumbnail_url"]
                    print(f"  ✅ Scraped fresh thumbnail URL: {new_thumb_url[:60]}...")
                else:
                    print("  ⚠️ Could not find thumbnail in scraped data.")
            except Exception as e:
                print(f"  ❌ Scraping error: {e}")
        
        # 如果成功抓到最新的未過期圖片，則將其上傳到 Firebase Storage，以產生永久不失效的連結
        if new_thumb_url:
            print("  ☁️ Uploading fresh image to Firebase Storage...")
            new_url = image_service.upload_to_firebase(new_thumb_url)
            
            if new_url and "firebasestorage" in new_url:
                post.cover_image = new_url
                session.commit()
                print(f"  🚀 SUCCESS! Updated to Firebase permanent URL: {new_url[:90]}...")
            else:
                print("  ❌ Failed to upload the fresh image to Firebase.")
        else:
            print(f"  ❌ Skipped '{post.title}' because no fresh thumbnail could be scraped from Instagram.")

session.close()
print("\n🎉 Instagram 圖片重新爬取與 Firebase 永久儲存遷移完成！")


import os
import sys
import sqlite3
import json
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Add current directory to sys.path
sys.path.append(os.getcwd())
from app.models.database import Base, CuratedPost, AIAnalysisCache, Place

def migrate_data():
    load_dotenv()
    cloud_url = os.getenv("SUPABASE_DB_URL")
    local_db_path = "pubo.db"
    
    if not cloud_url:
        print("❌ Error: SUPABASE_DB_URL not found.")
        return
    if not os.path.exists(local_db_path):
        print(f"❌ Error: Local DB {local_db_path} not found.")
        return

    print(f"🚀 Migrating data from {local_db_path} to Supabase...")
    
    # 1. Setup Connections
    local_conn = sqlite3.connect(local_db_path)
    local_conn.row_factory = sqlite3.Row
    
    cloud_engine = create_engine(cloud_url)
    CloudSession = sessionmaker(bind=cloud_engine)
    cloud_db = CloudSession()

    try:
        # --- A. Migrate CuratedPost (Homepage) ---
        print("\n🏠 Migrating CuratedPosts...")
        local_curated = local_conn.execute("SELECT * FROM curated_posts").fetchall()
        for row in local_curated:
            # Check if exists
            exists = cloud_db.query(CuratedPost).filter(CuratedPost.source_url == row['source_url']).first()
            if not exists:
                new_post = CuratedPost(
                    id=row['id'],
                    title=row['title'],
                    cover_image=row['cover_image'],
                    author=row['author'],
                    source_url=row['source_url'],
                    spots=json.loads(row['spots']) if isinstance(row['spots'], str) else row['spots'],
                    spot_count=row['spot_count'],
                    country=row['country']
                )
                cloud_db.add(new_post)
                print(f"✅ Migrated CuratedPost: {row['title']}")
        
        # --- B. Migrate AIAnalysisCache (Descriptions) ---
        print("\n🧠 Migrating AIAnalysisCache...")
        local_cache = local_conn.execute("SELECT * FROM ai_analysis_cache").fetchall()
        for row in local_cache:
            exists = cloud_db.query(AIAnalysisCache).filter(
                AIAnalysisCache.place_name == row['place_name'],
                AIAnalysisCache.address == row['address']
            ).first()
            if not exists:
                new_cache = AIAnalysisCache(
                    place_name=row['place_name'],
                    address=row['address'],
                    result=json.loads(row['result']) if isinstance(row['result'], str) else row['result']
                )
                cloud_db.add(new_cache)
        print(f"✅ Migrated {len(local_cache)} AI analysis results.")

        # --- C. Migrate Places (to support existing posts) ---
        print("\n📍 Migrating key Places...")
        local_places = local_conn.execute("SELECT * FROM places").fetchall()
        for row in local_places:
            exists = cloud_db.query(Place).filter(Place.place_id == row['place_id']).first()
            if not exists:
                new_place = Place(
                    place_id=row['place_id'],
                    name=row['name'],
                    address=row['address'],
                    latitude=row['latitude'],
                    longitude=row['longitude'],
                    category=row['category'],
                    image_url=row['image_url'],
                    rating=row['rating'],
                    user_ratings_total=row['user_ratings_total'],
                    opening_hours=json.loads(row['opening_hours']) if row['opening_hours'] and isinstance(row['opening_hours'], str) else row['opening_hours']
                )
                cloud_db.add(new_place)
        print(f"✅ Migrated {len(local_places)} Places.")

        cloud_db.commit()
        print("\n🎉 Migration Successfully Finished!")

    except Exception as e:
        print(f"❌ Migration failed: {e}")
        cloud_db.rollback()
    finally:
        local_conn.close()
        cloud_db.close()

if __name__ == "__main__":
    migrate_data()

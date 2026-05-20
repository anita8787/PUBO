import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Import all SQLAlchemy models
from backend.app.models.database import Base, Content, Place, ContentPlaceAssociation, Task, Trip, ItineraryDay, ItinerarySpot, AIAnalysisCache, CuratedPost

def migrate_sqlite_to_supabase(sqlite_path: str, supabase_url: str):
    print("🚀 準備開始從 SQLite 遷移到 Supabase...")
    
    # 1. 建立連線
    sqlite_engine = create_engine(f"sqlite:///{sqlite_path}")
    SqliteSession = sessionmaker(bind=sqlite_engine)
    sqlite_session = SqliteSession()

    supabase_engine = create_engine(supabase_url)
    SupabaseSession = sessionmaker(bind=supabase_engine)
    supabase_session = SupabaseSession()

    # 2. 在 Supabase 中建立所有資料表
    print("🛠️ 正在 Supabase 建立資料表結構...")
    Base.metadata.create_all(bind=supabase_engine)

    # 定義遷移順序（考慮外鍵依賴關係）
    # 必須先遷移沒有外鍵依賴的表，再遷移有外鍵依賴的表
    tables_to_migrate = [
        (Place, "Places"),
        (Content, "Contents"),
        (ContentPlaceAssociation, "ContentPlaceAssociation"),
        (Task, "Tasks"),
        (Trip, "Trips"),
        (ItineraryDay, "ItineraryDays"),
        (ItinerarySpot, "ItinerarySpots"),
        (AIAnalysisCache, "AIAnalysisCache"),
        (CuratedPost, "CuratedPosts")
    ]

    # 3. 開始搬運資料
    try:
        for model_class, table_name in tables_to_migrate:
            print(f"\n📦 正在讀取 SQLite 的 {table_name}...")
            records = sqlite_session.query(model_class).all()
            print(f"   -> 找到 {len(records)} 筆記錄。正在寫入 Supabase...")
            
            # 使用 expunge_all 讓物件脫離舊的 session
            sqlite_session.expunge_all()
            
            # 清除原有的 ID 以避免 PostgreSQL 衝突 (可選，但為了安全先試著直接寫入)
            for record in records:
                supabase_session.merge(record)  # 使用 merge 可以處理插入或更新
            
            supabase_session.commit()
            print(f"✅ {table_name} 搬運完成！")

        print("\n🎉 所有資料已成功搬遷至 Supabase！")
    
    except Exception as e:
        print(f"\n❌ 搬遷過程中發生錯誤: {e}")
        supabase_session.rollback()
    finally:
        sqlite_session.close()
        supabase_session.close()

if __name__ == "__main__":
    load_dotenv()
    
    # SQLite 資料庫路徑
    SQLITE_PATH = os.path.abspath("backend/pubo.db")
    if not os.path.exists(SQLITE_PATH):
        SQLITE_PATH = os.path.abspath("pubo.db")
        
    print(f"🔍 使用的 SQLite 來源: {SQLITE_PATH}")
    
    # 從環境變數獲取 Supabase URL
    SUPABASE_URL = os.getenv("SUPABASE_DB_URL")
    
    if not SUPABASE_URL:
        print("❌ 錯誤：請在 .env 檔案中設定 SUPABASE_DB_URL (PostgreSQL connection string)")
    elif not os.path.exists(SQLITE_PATH):
        print("❌ 錯誤：找不到 pubo.db 檔案")
    else:
        migrate_sqlite_to_supabase(SQLITE_PATH, SUPABASE_URL)

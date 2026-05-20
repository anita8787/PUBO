import os
import sys
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

def repair_cloud_db():
    load_dotenv()
    db_url = os.getenv("SUPABASE_DB_URL")
    if not db_url or "postgresql" not in db_url:
        print("❌ Error: SUPABASE_DB_URL is not set or not a PostgreSQL URL.")
        return

    print(f"🔧 Repairing Cloud Database Schema: {db_url[:20]}...")
    engine = create_engine(db_url)
    
    # 1. 修復 contents 表
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE contents ADD COLUMN IF NOT EXISTS is_collected INTEGER DEFAULT 0;"))
            conn.commit()
            print("✅ Verified is_collected in contents.")
        except Exception as e:
            print(f"⚠️ contents table update skipped or failed: {e}")

    # 2. 獨立修復 places 表的每個欄位 (避免單一失敗導致整筆交易中斷)
    places_columns = [
        ("image_url", "TEXT"),
        ("rating", "FLOAT"),
        ("user_ratings_total", "INTEGER"),
        ("opening_hours", "JSONB")
    ]
    
    for col_name, col_type in places_columns:
        with engine.connect() as conn:
            try:
                # 注意：PostgreSQL 針對 ADD COLUMN 不支援 IF NOT EXISTS 的語法（在某些版本中），
                # 所以我們用 try-except 包裹每一行並獨立 commit
                conn.execute(text(f"ALTER TABLE places ADD COLUMN {col_name} {col_type};"))
                conn.commit()
                print(f"✅ Added {col_name} to places table.")
            except Exception as e:
                if "already exists" in str(e).lower():
                    print(f"ℹ️ {col_name} already exists in places.")
                else:
                    print(f"⚠️ Error adding {col_name}: {e}")
    
    # 3. 再次執行標準 init_db 以確保其他表也存在
    sys.path.append(os.getcwd())
    from app.models.database import init_db
    init_db()
    print("✅ Schema sync complete.")

if __name__ == "__main__":
    repair_cloud_db()

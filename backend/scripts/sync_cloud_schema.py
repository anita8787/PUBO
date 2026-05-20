import os
import sys
from sqlalchemy import create_engine, text, inspect
from dotenv import load_dotenv

# Add current directory to sys.path
sys.path.append(os.getcwd())
from app.models.database import Base

def sync_cloud_schema():
    load_dotenv()
    db_url = os.getenv("SUPABASE_DB_URL")
    if not db_url or "postgresql" not in db_url:
        print("❌ Error: SUPABASE_DB_URL not found or invalid.")
        return

    print(f"📡 Syncing Cloud Schema: {db_url[:20]}...")
    engine = create_engine(db_url)
    inspector = inspect(engine)
    
    # 遍歷所有 SQLAlchemy 模型中定義的資料表
    for table_name, table_obj in Base.metadata.tables.items():
        print(f"\n🔍 Checking table: {table_name}")
        
        # 1. 檢查資料表是否存在
        if not inspector.has_table(table_name):
            print(f"✨ Table {table_name} missing. Creating...")
            table_obj.create(engine)
            continue
            
        # 2. 檢查欄位是否存在，不存在則補強
        existing_columns = [col['name'] for col in inspector.get_columns(table_name)]
        
        for column in table_obj.columns:
            if column.name not in existing_columns:
                print(f"🔧 Adding missing column: {table_name}.{column.name}")
                
                # 取得資料型別
                col_type = str(column.type).replace("VARCHAR", "TEXT").replace("BOOLEAN", "INTEGER")
                if "JSON" in col_type: col_type = "JSONB"
                
                alter_query = f'ALTER TABLE "{table_name}" ADD COLUMN "{column.name}" {col_type}'
                if not column.nullable:
                    # 如果原定不為空，在補強時通常需允許為空或給定預設值
                    alter_query += "" 
                
                try:
                    with engine.connect() as conn:
                        conn.execute(text(alter_query))
                        conn.commit()
                        print(f"✅ Successfully added {column.name}")
                except Exception as e:
                    print(f"❌ Failed to add {column.name}: {e}")
            else:
                pass # Already exists

    print("\n✅ Cloud Schema Synchronization Finished.")

if __name__ == "__main__":
    sync_cloud_schema()

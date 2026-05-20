import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
import os

# --- 1. 初始化 Firebase ---
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# --- 2. 修正路徑：確保與你的資料夾名稱完全一致 ---
CSV_FOLDER = "九個項目的CSV" 

def load_csv(file_name):
    # 組合路徑，例如：九個項目的CSV/places_rows.csv
    file_path = os.path.join(CSV_FOLDER, f"{file_name}.csv")
    
    if os.path.exists(file_path):
        print(f"📖 正在讀取: {file_path}")
        df = pd.read_csv(file_path)
        # 將 NaN 轉為 None (Firebase 不收 NaN)
        return df.where(pd.notnull(df), None).to_dict(orient='records')
    else:
        print(f"❌ 找不到檔案: {file_path}，請檢查檔名是否為 {file_name}.csv")
        return []

def migrate_all():
    print("🚀 開始 PUBO 資料搬遷任務...")

    # A. 景點資料
    places = load_csv("places_rows")
    for p in places:
        doc_id = str(p.get('place_id') or p['id'])
        db.collection("places").document(doc_id).set(p)
    print(f"✅ Places 搬遷完成")

    # B. 行程層級結構 (符合 PUBO PRD 的嵌套設計)
    trips = load_csv("trips_rows")
    days = load_csv("itinerary_days_rows")
    spots = load_csv("itinerary_spots_rows")

    for t in trips:
        uid = str(t.get('user_id', 'default_user'))
        tid = str(t['id'])
        trip_ref = db.collection("users").document(uid).collection("trips").document(tid)
        trip_ref.set(t)

        for d in [d for d in days if str(d['trip_id']) == tid]:
            did = str(d['id'])
            day_ref = trip_ref.collection("days").document(did)
            day_ref.set(d)

            for s in [s for s in spots if str(s['day_id']) == did]:
                sid = str(s['id'])
                day_ref.collection("spots").document(sid).set(s)
    print(f"✅ 行程與景點結構搬遷完成")

    # C. 其他剩餘項目
    others = ["ai_analysis_cache_rows", "contents_rows", "curated_posts_rows", "tasks_rows"]
    for item in others:
        data = load_csv(item)
        collection_name = item.replace("_rows", "")
        for d in data:
            db.collection(collection_name).add(d)
    
    print("\n🎉 所有資料已成功搬遷至 Firebase！")

if __name__ == "__main__":
    migrate_all()
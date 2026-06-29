import firebase_admin
from firebase_admin import credentials, firestore

def fix_url(url):
    if not isinstance(url, str):
        return url
    if "tixmkecbyeeehajlxpbo.supabase.co" in url:
        # 從舊網址擷取檔名，例如 xxx.jpg 或 xxx.png
        filename = url.split('/')[-1]
        # 轉換成 Firebase Storage 的網址格式
        return f"https://firebasestorage.googleapis.com/v0/b/pubo-production.firebasestorage.app/o/pubo-images%2F{filename}?alt=media"
    return url

def main():
    if not firebase_admin._apps:
        cred = credentials.Certificate('firebase-key.json')
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    print("🚀 開始掃描與清洗 Firestore 圖片網址...")
    collections = ['contents', 'places', 'curated_posts']
    updated_count = 0
    
    for coll_name in collections:
        print(f"📂 正在檢查 {coll_name}...")
        docs = db.collection(coll_name).stream()
        for doc in docs:
            data = doc.to_dict()
            needs_update = False
            
            if coll_name == 'contents':
                if 'preview_thumbnail_url' in data and data['preview_thumbnail_url']:
                    new_url = fix_url(data['preview_thumbnail_url'])
                    if new_url != data['preview_thumbnail_url']:
                        data['preview_thumbnail_url'] = new_url
                        needs_update = True
                        
            elif coll_name == 'places':
                if 'image_url' in data and data['image_url']:
                    new_url = fix_url(data['image_url'])
                    if new_url != data['image_url']:
                        data['image_url'] = new_url
                        needs_update = True
                        
            elif coll_name == 'curated_posts':
                if 'cover_image' in data and data['cover_image']:
                    new_url = fix_url(data['cover_image'])
                    if new_url != data['cover_image']:
                        data['cover_image'] = new_url
                        needs_update = True
                        
            if needs_update:
                doc.reference.update(data)
                updated_count += 1
                
    # 檢查使用者的 trips
    print("📂 正在檢查 users/default_user/trips...")
    trips_query = db.collection('users').document('default_user').collection('trips').stream()
    for doc in trips_query:
        data = doc.to_dict()
        if 'cover_image_url' in data and isinstance(data['cover_image_url'], str):
            new_url = fix_url(data['cover_image_url'])
            if new_url != data['cover_image_url']:
                data['cover_image_url'] = new_url
                doc.reference.update(data)
                updated_count += 1
                
    print(f"✅ 完成！共成功替換了 {updated_count} 筆資料的圖片網址。")

if __name__ == '__main__':
    main()

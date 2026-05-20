#!/usr/bin/env python3
"""
migrate_images_to_firebase.py
把所有儲存在 Supabase Storage 的圖片遷移到 Firebase Storage，
並更新 PostgreSQL / SQLite 資料庫中所有對應的 URL。
"""

import os
import sys
import hashlib
import requests
import time
from pathlib import Path
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

# ── 設定 ──────────────────────────────────────────────────────────────────────
BASE_DIR      = Path(__file__).parent
FIREBASE_KEY  = BASE_DIR / "firebase-key.json"
FB_BUCKET     = "pubo-production.firebasestorage.app"

load_dotenv()
DB_URL        = os.getenv("SUPABASE_DB_URL") or os.getenv("DATABASE_URL")
if not DB_URL:
    DB_URL = "sqlite:///./pubo.db"

SUPABASE_URL  = os.getenv("SUPABASE_URL") or "https://tixmkecbyeeehajlxpbo.supabase.co"
SUPABASE_KEY  = os.getenv("SUPABASE_KEY") or "your_supabase_key_here"

IMAGE_COLUMNS = [
    ("contents",         "id",  "preview_thumbnail_url"),
    ("places",           "id",  "image_url"),
    ("trips",            "id",  "cover_image_url"),
    ("itinerary_spots",  "id",  "image_url"),
    ("curated_posts",    "id",  "cover_image"),
]

# ── 初始化 Firebase Admin ──────────────────────────────────────────────────────
import firebase_admin
from firebase_admin import credentials, storage as fb_storage
from typing import Optional

cred = credentials.Certificate(str(FIREBASE_KEY))
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred, {"storageBucket": FB_BUCKET})
bucket = fb_storage.bucket()

print(f"✅ Firebase Storage 初始化完成：{FB_BUCKET}")

# ── 初始化 Supabase ────────────────────────────────────────────────────────────
from supabase import create_client
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
print(f"✅ Supabase 客戶端初始化完成")

migrated_cache: dict[str, str] = {}

def download_image(url: str) -> Optional[bytes]:
    try:
        resp = requests.get(url, timeout=20)
        if resp.status_code == 200:
            return resp.content
        print(f"   ⚠️  下載失敗 HTTP {resp.status_code}: {url}")
        return None
    except Exception as e:
        print(f"   ⚠️  下載例外：{e}")
        return None

def upload_to_firebase(image_bytes: bytes, original_url: str) -> Optional[str]:
    filename_hash = hashlib.md5(original_url.encode()).hexdigest()
    ext = ".jpg"
    if ".png" in original_url.lower(): ext = ".png"
    elif ".webp" in original_url.lower(): ext = ".webp"
    elif ".gif" in original_url.lower(): ext = ".gif"
    firebase_path = f"pubo-images/{filename_hash}{ext}"

    try:
        blob = bucket.blob(firebase_path)
        if blob.exists():
            blob.make_public()
            return blob.public_url

        blob.upload_from_string(image_bytes, content_type=f"image/{ext.lstrip('.')}")
        blob.make_public()
        return blob.public_url
    except Exception as e:
        print(f"   ❌ Firebase 上傳失敗：{e}")
        return None

def migrate_url(old_url: str) -> Optional[str]:
    if not old_url or "supabase.co" not in old_url:
        return old_url

    if old_url in migrated_cache:
        return migrated_cache[old_url]

    print(f"  ⬇️  下載: {old_url[-60:]}")
    image_bytes = download_image(old_url)
    if not image_bytes:
        return None

    print(f"  ⬆️  上傳到 Firebase...")
    new_url = upload_to_firebase(image_bytes, old_url)
    if new_url:
        migrated_cache[old_url] = new_url
        print(f"  ✅ 遷移成功: {new_url[-60:]}")
    return new_url

def main():
    print(f"🔌 連接資料庫：{DB_URL.split('@')[-1] if '@' in DB_URL else DB_URL}")
    engine = create_engine(DB_URL)
    
    total_migrated = 0
    total_skipped  = 0
    total_failed   = 0

    with engine.connect() as conn:
        for table, pk_col, img_col in IMAGE_COLUMNS:
            try:
                result = conn.execute(text(f"SELECT {pk_col}, {img_col} FROM {table} WHERE {img_col} LIKE '%supabase.co%'"))
                rows = result.fetchall()
            except Exception as e:
                print(f"⚠️  資料表 {table} 查詢失敗（可能不存在）：{e}")
                continue

            if not rows:
                print(f"  [{table}.{img_col}] — 沒有 Supabase URL，跳過")
                continue

            print(f"\n📋 [{table}.{img_col}] — 找到 {len(rows)} 筆需遷移")

            for row in rows:
                pk_val = row[0]
                old_url = row[1]
                print(f"\n 🔄 {table} id={pk_val}")
                
                new_url = migrate_url(old_url)
                if new_url and new_url != old_url:
                    conn.execute(
                        text(f"UPDATE {table} SET {img_col}=:new_url WHERE {pk_col}=:pk_val"),
                        {"new_url": new_url, "pk_val": pk_val}
                    )
                    conn.commit()
                    total_migrated += 1
                elif new_url == old_url:
                    total_skipped += 1
                else:
                    print(f"  ❌ 遷移失敗，保留原始 URL")
                    total_failed += 1

                time.sleep(0.3)

    print("\n" + "━" * 50)
    print(f"🎉 遷移完成！")
    print(f"   ✅ 成功更新：{total_migrated} 筆")
    print(f"   ⏭  跳過：{total_skipped} 筆")
    print(f"   ❌ 失敗：{total_failed} 筆")
    print("━" * 50)

if __name__ == "__main__":
    main()

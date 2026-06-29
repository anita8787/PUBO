import requests
import re
import os
import uuid
import mimetypes
from typing import Optional

# Firebase Storage bucket name - will be set once Firebase Storage is enabled
FIREBASE_STORAGE_BUCKET = os.environ.get("FIREBASE_STORAGE_BUCKET", "pubo-production.firebasestorage.app")


class ImageService:
    """
    提供景點圖片的「自動補水」功能與「圖片永久儲存」功能。
    使用 Firebase Storage 儲存圖片，並透過 Firebase 下載 Token 產生永久不過期的公開連結。
    """

    def __init__(self):
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }

    def _get_firebase_bucket(self):
        """取得 Firebase Storage bucket，並確保 SDK 已初始化。"""
        import firebase_admin
        from firebase_admin import credentials, storage as fb_storage

        if not firebase_admin._apps:
            # 找 firebase-key.json
            current_dir = os.path.dirname(os.path.abspath(__file__))
            key_path = None
            for _ in range(5):
                temp_path = os.path.join(current_dir, "firebase-key.json")
                if os.path.exists(temp_path):
                    key_path = temp_path
                    break
                current_dir = os.path.dirname(current_dir)

            if key_path:
                cred = credentials.Certificate(key_path)
                firebase_admin.initialize_app(cred, {"storageBucket": FIREBASE_STORAGE_BUCKET})
                print(f"✅ [ImageService] Firebase Admin SDK 啟動，bucket: {FIREBASE_STORAGE_BUCKET}")
            else:
                firebase_admin.initialize_app()
                print("✅ [ImageService] Firebase Admin SDK 啟動（環境變數模式）")

        return fb_storage.bucket(FIREBASE_STORAGE_BUCKET)

    def _upload_and_get_permanent_url(self, data: bytes, filename: str, content_type: str) -> Optional[str]:
        """
        上傳資料到 Firebase Storage，並回傳永久公開的下載 URL。
        使用 Firebase Storage 的 Download Token 機制，產生不會過期的連結。
        """
        try:
            from firebase_admin import storage as fb_storage
            from google.oauth2 import service_account
            from google.auth.transport.requests import Request as GoogleRequest

            bucket = self._get_firebase_bucket()
            blob = bucket.blob(filename)
            blob.upload_from_string(data, content_type=content_type)

            # 透過 Firebase Storage REST API 取得含 download token 的永久 URL
            # 這個 token 是 Firebase 專有機制，不受 uniform bucket-level access 影響，也不會過期
            key_path = self._find_firebase_key()
            if key_path:
                sa_cred = service_account.Credentials.from_service_account_file(
                    key_path,
                    scopes=["https://www.googleapis.com/auth/cloud-platform"]
                )
                sa_cred.refresh(GoogleRequest())
                access_token = sa_cred.token

                encoded_path = filename.replace("/", "%2F")
                metadata_url = f"https://firebasestorage.googleapis.com/v0/b/{FIREBASE_STORAGE_BUCKET}/o/{encoded_path}"
                r = requests.get(metadata_url, headers={"Authorization": f"Bearer {access_token}"})

                if r.status_code == 200:
                    meta = r.json()
                    if "downloadTokens" in meta:
                        dl_token = meta["downloadTokens"].split(",")[0]
                        permanent_url = f"https://firebasestorage.googleapis.com/v0/b/{FIREBASE_STORAGE_BUCKET}/o/{encoded_path}?alt=media&token={dl_token}"
                        print(f"✅ [ImageService] 永久 URL: {permanent_url[:80]}...")
                        return permanent_url

            # 備用：回傳 public URL（若 bucket 已設置 allUsers objectViewer）
            blob.make_public()
            return blob.public_url

        except Exception as e:
            print(f"❌ [ImageService] Upload error: {e}")
            return None

    def _find_firebase_key(self) -> Optional[str]:
        """尋找 firebase-key.json 的路徑。"""
        current_dir = os.path.dirname(os.path.abspath(__file__))
        for _ in range(5):
            path = os.path.join(current_dir, "firebase-key.json")
            if os.path.exists(path):
                return path
            current_dir = os.path.dirname(current_dir)
        return None



    def upload_to_firebase(self, image_url: str) -> str:
        """
        下載外部圖片（如 Instagram CDN），上傳到 Firebase Storage，
        並回傳永久不過期的下載 URL。
        【去重機制】：使用圖片內容 MD5 Hash 作為檔名，確保同一張社群封面圖只儲存一次。
        """
        import hashlib
        
        if not image_url:
            return image_url

        # 已在 Firebase Storage 就跳過（直接回傳永久連結）
        if "firebasestorage.googleapis.com" in image_url:
            print(f"⏩ [ImageService] 已在 Firebase，跳過: {image_url[:60]}")
            return image_url

        print(f"☁️ [ImageService] 下載並上傳到 Firebase: {image_url[:60]}")
        try:
            res = requests.get(image_url, headers=self.headers, timeout=15)
            if res.status_code != 200:
                print(f"❌ [ImageService] 下載失敗 HTTP {res.status_code}")
                return image_url

            content_type = res.headers.get("content-type", "")
            if not content_type.startswith("image/"):
                content_type = "image/jpeg"

            ext = mimetypes.guess_extension(content_type) or ".jpg"
            if ext == ".jpe":
                ext = ".jpg"

            # 【去重】用圖片內容 MD5 Hash 做檔案名稱，相同圖片只存一次
            img_hash = hashlib.md5(res.content).hexdigest()
            filename = f"pubo_image/{img_hash}{ext}"

            # 先檢查 Firebase Storage 是否已存在相同 hash 的圖片
            try:
                bucket = self._get_firebase_bucket()
                existing_blob = bucket.blob(filename)
                if existing_blob.exists():
                    print(f"⏩ [ImageService] 社群封面圖已存在（Hash 相同），跳過重複上傳: {filename}")
                    key_path = self._find_firebase_key()
                    if key_path:
                        from google.oauth2 import service_account
                        from google.auth.transport.requests import Request as GoogleRequest
                        sa_cred = service_account.Credentials.from_service_account_file(
                            key_path, scopes=["https://www.googleapis.com/auth/cloud-platform"]
                        )
                        sa_cred.refresh(GoogleRequest())
                        access_token = sa_cred.token
                        encoded_path = filename.replace("/", "%2F")
                        metadata_url = f"https://firebasestorage.googleapis.com/v0/b/{FIREBASE_STORAGE_BUCKET}/o/{encoded_path}"
                        r = requests.get(metadata_url, headers={"Authorization": f"Bearer {access_token}"})
                        if r.status_code == 200:
                            meta = r.json()
                            if "downloadTokens" in meta:
                                dl_token = meta["downloadTokens"].split(",")[0]
                                existing_url = f"https://firebasestorage.googleapis.com/v0/b/{FIREBASE_STORAGE_BUCKET}/o/{encoded_path}?alt=media&token={dl_token}"
                                print(f"✅ [ImageService] 回傳已存在社群圖的永久 URL: {existing_url[:80]}...")
                                return existing_url
            except Exception as check_err:
                print(f"⚠️ [ImageService] 無法確認既有檔案，改為全新上傳: {check_err}")

            result_url = self._upload_and_get_permanent_url(res.content, filename, content_type)
            return result_url if result_url else image_url

        except Exception as e:
            print(f"❌ [ImageService] Upload Error: {e}")
            return image_url

    def upload_bytes_to_firebase(self, image_bytes: bytes, content_type: str) -> Optional[str]:
        """
        上傳原始二進位資料到 Firebase Storage（主要用於用戶自訂圖片上傳），
        並回傳永久不過期的下載 URL。
        【去重機制】：使用圖片內容的 MD5 Hash 作為檔案名稱，確保同一張圖片只儲存一次。
        """
        import hashlib
        
        print(f"☁️ [ImageService] 上傳 bytes 到 Firebase Storage. Content-Type: {content_type}")
        try:
            ext = mimetypes.guess_extension(content_type) or ".jpg"
            if ext == ".jpe":
                ext = ".jpg"

            # 【去重】用圖片內容 MD5 Hash 做檔案名稱，相同圖片只存一次
            img_hash = hashlib.md5(image_bytes).hexdigest()
            filename = f"user_image/{img_hash}{ext}"
            
            # 先檢查 Firebase Storage 是否已存在相同 hash 的圖片
            try:
                bucket = self._get_firebase_bucket()
                existing_blob = bucket.blob(filename)
                if existing_blob.exists():
                    # 已存在，直接取得並回傳現有的永久 URL
                    print(f"⏩ [ImageService] 圖片已存在（Hash 相同），跳過重複上傳: {filename}")
                    key_path = self._find_firebase_key()
                    if key_path:
                        from google.oauth2 import service_account
                        from google.auth.transport.requests import Request as GoogleRequest
                        sa_cred = service_account.Credentials.from_service_account_file(
                            key_path,
                            scopes=["https://www.googleapis.com/auth/cloud-platform"]
                        )
                        sa_cred.refresh(GoogleRequest())
                        access_token = sa_cred.token
                        encoded_path = filename.replace("/", "%2F")
                        metadata_url = f"https://firebasestorage.googleapis.com/v0/b/{FIREBASE_STORAGE_BUCKET}/o/{encoded_path}"
                        r = requests.get(metadata_url, headers={"Authorization": f"Bearer {access_token}"})
                        if r.status_code == 200:
                            meta = r.json()
                            if "downloadTokens" in meta:
                                dl_token = meta["downloadTokens"].split(",")[0]
                                existing_url = f"https://firebasestorage.googleapis.com/v0/b/{FIREBASE_STORAGE_BUCKET}/o/{encoded_path}?alt=media&token={dl_token}"
                                print(f"✅ [ImageService] 回傳已存在的永久 URL: {existing_url[:80]}...")
                                return existing_url
            except Exception as check_err:
                print(f"⚠️ [ImageService] 無法確認既有檔案，改為全新上傳: {check_err}")
            
            result_url = self._upload_and_get_permanent_url(image_bytes, filename, content_type)

            if result_url:
                print(f"✅ [ImageService] 上傳成功！永久 URL: {result_url[:80]}")
                return result_url
            return None

        except Exception as e:
            print(f"❌ [ImageService] Bytes Upload Error: {e}")
            return None

    # 向下相容的別名
    upload_to_supabase = upload_to_firebase
    upload_bytes_to_supabase = upload_bytes_to_firebase

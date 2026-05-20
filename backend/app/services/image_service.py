import requests
import re
import os
import uuid
import mimetypes
from typing import Optional
from supabase import create_client, Client

class ImageService:
    """
    提供景點圖片的「自動補水」功能與「圖片永久儲存」功能。
    當 Google Places 或原始社群貼文都沒有圖片時，透過搜尋引擎尋找相關圖片，並儲存至 Supabase。
    """
    
    def __init__(self):
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }
        
        # 初始化 Supabase
        supabase_url = os.environ.get("SUPABASE_URL")
        supabase_key = os.environ.get("SUPABASE_KEY")
        if supabase_url and supabase_key:
            self.supabase: Client = create_client(supabase_url, supabase_key)
        else:
            self.supabase = None
            print("⚠️ [ImageService] Supabase credentials missing. Cloud upload disabled.")

    def fetch_fallback_image(self, query: str) -> Optional[str]:
        """
        透過 DuckDuckGo Image Search 抓取第一張相關圖片。
        這是一個「免費且無須 API Key」的解決方案。
        """
        if not query or len(query) < 2:
            return None
            
        print(f"🖼️ [ImageService] Searching fallback for: {query}")
        
        try:
            # 1. 取得搜尋頁面的 Token (vqd)
            search_url = "https://duckduckgo.com/"
            res = requests.post(search_url, data={"q": query}, headers=self.headers, timeout=5)
            vqd_match = re.search(r'vqd=([\d-]+)&', res.text)
            
            if not vqd_match:
                # Try simple GET if POST failed
                res = requests.get(search_url, params={"q": query}, headers=self.headers, timeout=5)
                vqd_match = re.search(r'vqd=([\d-]+)&', res.text)
            
            if not vqd_match:
                print("⚠️ [ImageService] Could not find vqd token")
                return None
            
            vqd = vqd_match.group(1)
            
            # 2. 呼叫 DuckDuckGo Image API
            # mode=wt-wt is no-proxy, i=all is all regions
            image_api_url = "https://duckduckgo.com/i.js"
            params = {
                "l": "wt-wt",
                "o": "json",
                "q": query,
                "vqd": vqd,
                "f": ",,,",
                "p": "1"
            }
            
            img_res = requests.get(image_api_url, params=params, headers=self.headers, timeout=5)
            data = img_res.json()
            
            if "results" in data and len(data["results"]) > 0:
                # 抓取第一張圖片的 URL
                img_url = data["results"][0].get("image")
                print(f"✅ [ImageService] Found image: {img_url}")
                return img_url
                
            return None
            
        except Exception as e:
            print(f"❌ [ImageService] Search failed for '{query}': {e}")
            return None

    def upload_to_supabase(self, image_url: str) -> str:
        """
        下載外部的過期圖片，並上傳到 Supabase Storage 以獲取永久連結。
        如果失敗，則回傳原本的 image_url（作為最後手段）。
        """
        if not image_url or not self.supabase:
            return image_url
            
        # 避免重複上傳已經在 Supabase 的圖片
        if "supabase.co" in image_url:
            print(f"⏩ [ImageService] URL is already in Supabase, skipping upload: {image_url}")
            return image_url
            
        print(f"☁️ [ImageService] Uploading to Supabase: {image_url}")
        try:
            # 下載圖片到記憶體
            res = requests.get(image_url, headers=self.headers, timeout=15)
            if res.status_code != 200:
                print(f"❌ [ImageService] Download failed: HTTP {res.status_code}")
                return image_url
                
            content_type = res.headers.get('content-type', '')
            if not content_type.startswith('image/'):
                content_type = 'image/jpeg'
                
            # 決定副檔名
            ext = mimetypes.guess_extension(content_type) or '.jpg'
            if ext == '.jpe': ext = '.jpg'
            
            # 產生隨機檔名以免碰撞
            filename = f"{uuid.uuid4().hex}{ext}"
            
            # 上傳至 Supabase Storage (pubo-images bucket)
            self.supabase.storage.from_("pubo-images").upload(
                file=res.content,
                path=filename,
                file_options={"content-type": content_type}
            )
            
            # 取得公開的永久 URL
            public_url = self.supabase.storage.from_("pubo-images").get_public_url(filename)
            print(f"✅ [ImageService] Upload successful! Permanent URL: {public_url}")
            return public_url
            
        except Exception as e:
            print(f"❌ [ImageService] Upload Error: {e}")
            return image_url

    def upload_bytes_to_supabase(self, image_bytes: bytes, content_type: str) -> Optional[str]:
        """
        上傳原始二進位資料到 Supabase Storage (主要用於截圖上傳)，並獲取永久連結。
        """
        if not self.supabase:
            print("⚠️ [ImageService] No supabase client for bytes upload.")
            return None
            
        print(f"☁️ [ImageService] Uploading bytes to Supabase. Content-Type: {content_type}")
        try:
            # 決定副檔名
            ext = mimetypes.guess_extension(content_type) or '.jpg'
            if ext == '.jpe': ext = '.jpg'
            
            # 產生隨機檔名以免碰撞
            filename = f"screenshot_{uuid.uuid4().hex}{ext}"
            
            # 上傳至 Supabase Storage (pubo-images bucket)
            self.supabase.storage.from_("pubo-images").upload(
                file=image_bytes,
                path=filename,
                file_options={"content-type": content_type}
            )
            
            # 取得公開的永久 URL
            public_url = self.supabase.storage.from_("pubo-images").get_public_url(filename)
            print(f"✅ [ImageService] Bytes upload successful! Permanent URL: {public_url}")
            return public_url
            
        except Exception as e:
            print(f"❌ [ImageService] Bytes Upload Error: {e}")
            return None


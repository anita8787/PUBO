import requests
import re
import json
from typing import Optional

class ImageService:
    """
    提供景點圖片的「自動補水」功能。
    當 Google Places 或原始社群貼文都沒有圖片時，透過搜尋引擎尋找相關圖片。
    """
    
    def __init__(self):
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }

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
                # 我們優先選擇影像品質較好的 thumbnail 或原文 URL
                img_url = data["results"][0].get("image")
                print(f"✅ [ImageService] Found image: {img_url}")
                return img_url
                
            return None
            
        except Exception as e:
            print(f"❌ [ImageService] Search failed for '{query}': {e}")
            return None

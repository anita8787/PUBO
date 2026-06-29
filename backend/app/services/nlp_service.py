import os
import json
import requests
from typing import List, Dict, Any, Optional
from dotenv import load_dotenv

load_dotenv()

class NLPService:
    def __init__(self):
        # 讀取 GEMINI_API_KEY
        self.api_key = os.getenv("GEMINI_API_KEY")
        
        # 偵測是否為佔位符
        if self.api_key and ("your_gemini_api_key_here" in self.api_key or not self.api_key.strip()):
            print("Warning: GEMINI_API_KEY is placeholder or empty.")
            self.api_key = None
            
        # 統一設定模型名稱為 gemini-flash-latest (經過驗證，此名稱在 v1beta 下可正常運作)
        self.model_name = "gemini-flash-latest"
        # REST API 基礎 URL
        self.base_url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.model_name}:generateContent"

    def _clean_social_media_text(self, text: str) -> str:
        """
        在發送給 Gemini 前，先在後台強行過濾雜訊，大幅節省 Token 並提升解析速度。
        """
        if not text:
            return ""
        import re
        
        # 1. 移除所有網址 (http, https, bit.ly 等)
        text = re.sub(r'http[s]?://\S+', '', text)
        text = re.sub(r'bit\.ly/\S+', '', text)
        
        # 2. 移除 # 符號，但保留後面的文字 (例如 #九份 -> 九份)
        text = re.sub(r'#', '', text)
        
        # 3. 移除常見廢話 (可依據需求擴充)
        fluff = ["快點標註朋友帶你去", "點擊首頁連結", "客觀評價高達五顆星"]
        for f in fluff:
            text = text.replace(f, "")
            
        # 4. 移除過多的空白與換行
        text = re.sub(r'\n+', '\n', text)
        return text.strip()

    def extract_places_from_text(self, text: str) -> List[Dict[str, Any]]:
        """
        使用 Google Gemini REST API 從文字中抽取出 POI 地點
        """
        if not self.api_key:
            print("Warning: GEMINI_API_KEY not set. Returning empty list.")
            return []

        # 在發送給 AI 前，先極速清洗文本
        cleaned_text = self._clean_social_media_text(text)
        prompt = self._build_extraction_prompt(cleaned_text)
        
        # 設定正確的 Header
        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": self.api_key
        }
        
        # 設定 Payload
        payload = {
            "contents": [
                {
                    "parts": [
                        {"text": prompt}
                    ]
                }
            ],
            "generationConfig": {
                "responseMimeType": "application/json",
                "responseSchema": {
                    "type": "ARRAY",
                    "description": "List of extracted places",
                    "items": {
                        "type": "OBJECT",
                        "properties": {
                            "spot_name": {"type": "STRING", "description": "The name of the place, spot, or store"},
                            "city": {"type": "STRING", "description": "The city or region"},
                            "address": {"type": "STRING", "description": "The full address of the place, if mentioned in the text"},
                            "category": {"type": "STRING", "description": "Category (美食, 景點, 住宿, 購物)"}
                        },
                        "required": ["spot_name"]
                    }
                }
            }
        }

        try:
            print(f"📡 [NLP] Calling Gemini REST API ({self.model_name})...")
            response = requests.post(self.base_url, headers=headers, json=payload, timeout=45)
            
            if response.status_code != 200:
                print(f"❌ [NLP] API Error ({response.status_code}): {response.text}")
                return self._fallback_regex_extraction(text)
                
            result = response.json()
            # 解析 REST API 的回傳結構
            if "candidates" in result and len(result["candidates"]) > 0:
                candidate = result["candidates"][0]
                if "content" in candidate and "parts" in candidate["content"]:
                    content_text = candidate["content"]["parts"][0]["text"].strip()
                    # 移除可能的 Markdown 標籤
                    content_text = content_text.replace('```json', '').replace('```', '').strip()
                    
                    print(f"🤖 [NLP] AI Raw Response: {content_text}")
                    return self._parse_extraction_response(content_text)
            
            print("⚠️ [NLP] No valid candidates found in AI response.")
            return self._fallback_regex_extraction(text)

        except Exception as e:
            print(f"❌ [NLP] REST API Request Failed: {e}")
            return self._fallback_regex_extraction(text)


    def direct_identify_country(self, title: str, text: str, spots: List[Dict[str, Any]] = []) -> str:
        """
        強效國家辨識系統：座標優先 -> 關鍵字其次 -> AI 最後防線
        """
        combined = (title + (text or "")).lower()
        
        # 1. 第一層：座標鎖定 (最精準)
        # 日本範圍：Lat 20-46, Lon 122-154
        # 韓國範圍：Lat 33-39, Lon 124-131
        latitudes = [s.get("latitude") for s in spots if s.get("latitude")]
        longitudes = [s.get("longitude") for s in spots if s.get("longitude")]
        
        if latitudes and longitudes:
            # 韓國範圍 (優先判定，避免與日本經度重疊)
            is_korea = all(33 <= lat <= 39 and 124 <= lon <= 131 for lat, lon in zip(latitudes, longitudes))
            if is_korea: return "韓國"
            
            # 日本範圍
            is_japan = all(24 <= lat <= 46 and 122 <= lon <= 154 for lat, lon in zip(latitudes, longitudes))
            if is_japan: return "日本"

        # 2. 第二層：核心關鍵字 (快取掃描)
        jp_keywords = ["日本", "東京", "大阪", "京都", "北海道", "九州", "沖繩", "奈良", "名古屋", "福岡", "河口湖", "富士山", "japan", "tokyo", "osaka", "kyoto"]
        kr_keywords = ["韓國", "首爾", "釜山", "弘大", "明洞", "濟州", "東大門", "江南", "漢江", "安國", "korea", "seoul", "busan", "jeju"]
        
        for kw in jp_keywords:
            if kw in combined: return "日本"
        for kw in kr_keywords:
            if kw in combined: return "韓國"
            
        return "" # 如果前兩層都失敗，才回傳空字串讓 AI 處理

    def detect_country(self, title: str, text: str, spots: List[Dict[str, Any]] = []) -> str:
        """
        執行多重辨認國家邏輯
        """
        # 執行直接辨認
        direct_result = self.direct_identify_country(title, text, spots)
        if direct_result:
            print(f"✅ [NLP] Directly identified country: {direct_result}")
            return direct_result

        # 如果直接辨認失敗，則使用 AI
        if not self.api_key:
            return "韓國" # 預設

        spot_names = [s.get("name", "") for s in spots[:5]]
        prompt = f"""
        請根據以下旅遊貼文的資訊，判斷它主要介紹的是哪個國家。
        標題：{title}
        內容片段：{text[:200] if text else ""}
        提到的景點：{", ".join(spot_names)}
        
        請只回傳「國家名稱」（例如：日本、韓國、台灣、泰國、美國...等）。
        如果真的無法判斷，請務必回傳「韓國」。嚴禁回傳空值。
        """
        
        headers = {"Content-Type": "application/json", "x-goog-api-key": self.api_key}
        payload = {
            "contents": [{"parts": [{"text": prompt}]}]
        }

        try:
            response = requests.post(self.base_url, headers=headers, json=payload, timeout=20)
            if response.status_code == 200:
                result = response.json()
                country = result["candidates"][0]["content"]["parts"][0]["text"].strip()
                country = country.replace("國家：", "").replace("國家名稱：", "").strip()
                # 確保不為空
                if not country or len(country) > 10:
                    return "韓國"
                return country
        except Exception as e:
            print(f"❌ [NLP] AI Country detection failed: {e}")
            
        return "韓國"

    def _build_extraction_prompt(self, text: str) -> str:
        return f"""
        你是一位高效能、精準的旅遊資料結構化專家，專門為旅遊 App「Pubo」在第一時間清洗並提取社群媒體（IG/Threads/FB）的景點資料。

        你的核心任務是：在最短時間內提取出文中所提及到的景點。為了達成極速提取並避免不必要的 Token 浪費，請直接忽略與景點無關的雜訊。
        如果找不到任何景點，請回傳空的結果。

        【極度重要規則】：
        1. 景點名稱 (spot_name) 請「絕對只保留最乾淨的店名或景點名稱」，務必將「特殊編碼 (如 EF56+78)」、「樓層 (如 1F, B1)」等無意義資訊【徹底刪除】！
        2. 如果原文有明確提供該景點的「具體地址」(例如 3 Chome-31-19...)，請務必將其完整保留，並填入 address 欄位中！

        **待解析內容：**
        \"\"\"
        {text}
        \"\"\"
        """

    def _parse_extraction_response(self, content: str) -> List[Dict[str, Any]]:
        try:
            data = json.loads(content)
            extracted = []
            if isinstance(data, list):
                extracted = data
            elif isinstance(data, dict):
                 # 尋找字典中第一個長得像 list 的值
                 for val in data.values():
                     if isinstance(val, list):
                         extracted = val
                         break
                         
            # 轉換 spot_name 回原本系統需要的 name 等欄位，防止後端崩潰
            for item in extracted:
                if "spot_name" in item and "name" not in item:
                    item["name"] = item["spot_name"]
                if "search_query" not in item:
                    item["search_query"] = item.get("name", "")
                if "country" not in item:
                    item["country"] = ""
                if "evidence_text" not in item:
                    item["evidence_text"] = ""
                if "confidence_score" not in item:
                    item["confidence_score"] = 0.95

            return extracted
        except Exception as e:
            print(f"❌ [NLP] JSON Parse Error: {e}")
            return []

    def _fallback_regex_extraction(self, text: str) -> List[Dict[str, Any]]:
        import re
        print("⚠️ [NLP] AI failed or returned error. Using Regex Fallback...")
        extracted = []
        lines = text.split('\n')
        marker_pattern = re.compile(r'^[▫️■📍📌*]\s*(.+)$')
        for line in lines:
            line = line.strip()
            match = marker_pattern.match(line)
            if match:
                name = match.group(1).split(' @')[0].split('📍')[0].strip()
                if 2 <= len(name) <= 20:
                    extracted.append({
                        "name": name, "search_query": name, "country": "Unknown", "city": "Unknown",
                        "category": "景點", "evidence_text": line, "confidence_score": 0.5
                    })
        return extracted

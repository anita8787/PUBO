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

    def extract_places_from_text(self, text: str) -> List[Dict[str, Any]]:
        """
        使用 Google Gemini REST API 從文字中抽取出 POI 地點
        """
        if not self.api_key:
            print("Warning: GEMINI_API_KEY not set. Returning empty list.")
            return []

        prompt = self._build_extraction_prompt(text)
        
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
                "responseMimeType": "application/json"
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

    def extract_places_from_image(self, image_data: bytes, mime_type: str) -> List[Dict[str, Any]]:
        """
        使用 Google Gemini REST API 從圖片(截圖)中抽取出 POI 地點
        """
        import base64
        if not self.api_key:
            print("Warning: GEMINI_API_KEY not set. Returning empty list.")
            return []

        # 圖片需轉為 Base64 才能透過 REST API 傳遞
        base64_image = base64.b64encode(image_data).decode('utf-8')
        
        prompt = self._build_extraction_prompt("這是一張包含景點、餐廳或店家的截圖，請分析圖片中的文字與地標。")
        
        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": self.api_key
        }
        
        payload = {
            "contents": [
                {
                    "parts": [
                        {"text": prompt},
                        {
                            "inlineData": {
                                "mimeType": mime_type,
                                "data": base64_image
                            }
                        }
                    ]
                }
            ],
            "generationConfig": {
                "responseMimeType": "application/json"
            }
        }

        try:
            print(f"🖼️ [NLP] Calling Gemini REST API ({self.model_name}) for Image Extraction...")
            response = requests.post(self.base_url, headers=headers, json=payload, timeout=45)
            
            if response.status_code != 200:
                print(f"❌ [NLP] API Error ({response.status_code}): {response.text}")
                return []
                
            result = response.json()
            if "candidates" in result and len(result["candidates"]) > 0:
                candidate = result["candidates"][0]
                if "content" in candidate and "parts" in candidate["content"]:
                    content_text = candidate["content"]["parts"][0]["text"].strip()
                    content_text = content_text.replace('```json', '').replace('```', '').strip()
                    print(f"🤖 [NLP] AI Image Raw Response: {content_text}")
                    return self._parse_extraction_response(content_text)
            
            return []

        except Exception as e:
            print(f"❌ [NLP] Image REST API Request Failed: {e}")
            return []

    def generate_place_description(self, name: str, address: Optional[str] = None, country: Optional[str] = None, city: Optional[str] = None) -> dict:
        """
        使用 Google Gemini REST API 生成景點的簡短介紹與模擬評價
        """
        if not self.api_key:
            return self._get_default_description(name)

        location_context = ""
        if address:
            location_context = f"真實地址在「{address}」的"
        elif country and city:
            location_context = f"位於{country}{city}的"

        prompt = f"""
        請根據真實地點資訊為{location_context}「{name}」生成以下旅遊資訊，請嚴格限制字數以節省長度：
        1. description: 精簡的繁體中文旅遊介紹，直接點出特色，不超過 50 字。
        2. pro_comment: 一句模擬網友好評（15字內）。
        3. con_comment: 一句模擬網友負評或建議（15字內）。
        
        請直接回傳 JSON 格式：
        {{
            "description": "...",
            "pro_comment": "...",
            "con_comment": "..."
        }}
        """
        
        headers = {"Content-Type": "application/json", "x-goog-api-key": self.api_key}
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"responseMimeType": "application/json"}
        }

        try:
            response = requests.post(self.base_url, headers=headers, json=payload, timeout=45)
            if response.status_code == 200:
                result = response.json()
                content_text = result["candidates"][0]["content"]["parts"][0]["text"].strip()
                content_text = content_text.replace('```json', '').replace('```', '').strip()
                data = json.loads(content_text)
                return {
                    "description": data.get("description", f"{name} 是當地熱門景點。"),
                    "pro_comment": data.get("pro_comment", "值得一訪！"),
                    "con_comment": data.get("con_comment", "人多建議提早。")
                }
        except Exception as e:
            print(f"❌ [NLP] Description failed: {e}")
            
        return self._get_default_description(name)

    def ai_geocoding(self, place_name: str, country: str, city: str) -> Optional[Dict[str, Any]]:
        """
        當 Google Places API 完全找不到地點時，做為最後一道防線，
        請 AI 直接給出該確切地點的近似經緯度與地址資訊。
        """
        if not self.api_key:
            return None
            
        prompt = f"""
        你是一個專業的地理定位專家。請給我位於 {country} {city} 的知名地點或店家「{place_name}」的真實地址與精確座標 (緯度與經度)。
        如果該地點是韓文翻譯過來的，請查明它在韓國的真實位置。
        
        請嚴格遵照以下 JSON 格式回傳，不要加上任何其他解釋：
        {{
            "address": "繁體中文或當地語言的真實詳細地址",
            "latitude": 37.123456,
            "longitude": 127.123456
        }}
        如果真的完全找不到或不存在這個地方，請回傳空 JSON：{{}}
        """
        
        headers = {"Content-Type": "application/json", "x-goog-api-key": self.api_key}
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"responseMimeType": "application/json"}
        }

        try:
            print(f"🤖 [NLP] Emergency Geocoding for {place_name}...")
            response = requests.post(self.base_url, headers=headers, json=payload, timeout=20)
            if response.status_code == 200:
                result = response.json()
                content_text = result["candidates"][0]["content"]["parts"][0]["text"].strip()
                content_text = content_text.replace('```json', '').replace('```', '').strip()
                data = json.loads(content_text)
                
                if data.get("latitude") and data.get("longitude"):
                    return data
        except Exception as e:
            print(f"❌ [NLP] AI Geocoding failed: {e}")
            
        return None

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

    def _get_default_description(self, name: str) -> dict:
        return {
            "description": f"{name} 是當地廣受好評的熱門景點。",
            "pro_comment": "風景非常漂亮！",
            "con_comment": "交通略微不便。"
        }

    def _build_extraction_prompt(self, text: str) -> str:
        return f"""
        你是一位專業的旅遊資料分析師。請分析下方的社群媒體貼文，找出其中提到的「所有具體景點、店家、餐廳、咖啡廳或地標」。
        
        **分析原則：**
        1. **搜尋所有潛在地點**：即使只有縮寫 (例如「安國」)，只要它是個可以去的地方，就應該抓取。
        2. **精準區分店名與地址 (非常重要！)**：許多貼文會把「詳細地址」(例如：📍大阪府大阪市西区南堀江1丁目9-1) 放在文章最下方或行末。這絕對**不是**店名！你必須往上文尋找真正的店鋪名稱、品牌名或景點名 (例如：Billy's)，將它填入 `name`，並將地址納入 `search_query` 來幫助搜尋。千萬不要把純地址當作店名。
        3. **韓國與日本優化**：
           - `name`: 真正的品牌名/店名/景點名 (包含中文名稱加上必要的原文)。
           - `search_query`: 搜尋關鍵字。如果是**韓國**，務必組合為「South Korea [城市] [真實店名/韓文店名] [地址]」。如果是**日本**，必須包含「Japan [城市] [真實店名] [地址]」。
        4. **忽略泛稱**：只抓取具體的店名或景點，忽略「超商」、「回程」等無關的地點。
        
        請回傳一個 JSON Array：
        [
            {{
                "name": "真實店名或景點名稱 (絕不是純地址)",
                "search_query": "用於 Google 搜尋的關鍵字 (可包含地址)",
                "country": "國家",
                "city": "城市",
                "category": "類別",
                "evidence_text": "原文提及片段",
                "confidence_score": 0.95
            }}
        ]

        **貼文內容：**
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

import os
import json
import google.generativeai as genai
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
            
        if self.api_key:
            genai.configure(api_key=self.api_key)
            # 使用 gemini-flash-latest，這通常指向目前穩定且配額寬裕的版本
            self.model_name = "gemini-flash-latest"
            self.model = genai.GenerativeModel(
                model_name=self.model_name,
                generation_config={"response_mime_type": "application/json"}
            )
        else:
            self.model = None

    def extract_places(self, text: str) -> List[Dict[str, Any]]:
        """
        使用 Google Gemini 從文字中抽取出 POI 地點
        """
        if not self.model:
            print("Warning: GEMINI_API_KEY not set. Returning mock extracted places.")
            return self._get_mock_extraction()

        prompt = f"""
        你是一位專業的旅遊資料分析師。請分析下方的社群媒體貼文(包含網友留言)，並完成以下任務：
        1. **提取**：找出文中提到的所有「特定地點」、「店家」或「景點」(POIs)。
        2. **雙軌命名**：
           - `name`: **繁體中文顯示名**。若文中是簡稱，請校正為正式店名。若原文為英文且無通用中文譯名，則保留英文。
           - `search_query`: **在地化外部搜尋字串**。這將用於 Google Maps API 搜尋。請包含「國家 + 城市 + 正式店名 + 當地原文店名」。
        3. **推斷國家 (非常重要)**：若文中未直接說明國家，請務必根據「貨幣(如Won/KRW)」、「語言(如出現韓文)」、「地標」來強制推測。例如在韓國聖水洞的鹽麵包店，`search_query` 應為「Korea Seoul 자연도소금빵 성수」。
        4. **校正與驗證**：利用你的知識庫驗證該地點是否存在。若該地點已歇業或明顯不存在，請忽略。
        
        請嚴格回傳一個 JSON Array，不要包含任何多餘的外掛文字或 Markdown：
        [
            {{
                "name": "繁體中文顯示名稱",
                "search_query": "用於 Google 搜尋的關鍵字 (務必包含推斷出的國家名與城市名)",
                "country": "推斷出的國家名稱(如：韓國、日本、台灣)，用來在後端做雙重驗證",
                "category": "類別(如：餐廳、咖啡、景點、商店)",
                "evidence_text": "原文中提到該地點的句子段落",
                "confidence_score": 0.0~1.0 之間的數值
            }}
        ]

        **重要規則：**
        1. **去重**：如果同一個地點出現多次，請只列出最精確的那一個。
        2. **過濾非主角**：請只抓取這篇貼文真正要介紹或推薦的地點，忽略作為比較或參考用的地標 (如：在台北101附近 -> 忽略台北101)。
        3. **隱藏版好店**：請仔細閱讀「網友留言」區段，作者經常在裡面補充詳細的地點資訊。

        貼文內容：
        \"\"\"
        {text}
        \"\"\"
        """

        try:
            # Gemini 生成內容
            response = self.model.generate_content(prompt)
            content = response.text
            data = json.loads(content)
            
            if isinstance(data, list):
                return data
            if isinstance(data, dict):
                 for key in ["places", "pois", "locations"]:
                     if key in data and isinstance(data[key], list):
                         return data[key]
                 return []
            
            return []

        except Exception as e:
            print(f"NLP Extraction Error (Gemini): {e}")
            return []

    def generate_place_description(self, name: str, address: Optional[str] = None) -> str:
        """
        使用 Google Gemini 生成景點的簡短介紹 (2-3 段)
        """
        if not self.model:
            return f"{name} 是一個值得一探究竟的地點。"

        prompt = f"""
        你是一位專業的旅遊導覽員。請為以下地點撰寫一段簡短且吸引人的介紹：
        地點名稱：{name}
        {f'地址：{address}' if address else ''}
        
        要求：
        1. 使用繁體中文。
        2. 分為 2 到 3 個短句或段落，總字數控制在 100 字以內。
        3. 內容要包含該地點的特色、文化底蘊或必看之處。
        4. 不要使用 Markdown 標題，直接輸出文字內容。
        """

        try:
            response = self.model.generate_content(prompt)
            return response.text.strip()
        except Exception as e:
            print(f"NLP Description Error (Gemini): {e}")
            return f"{name} 提供了豐富的體驗與獨特的氛圍，是當地熱門的地點之一。"

    def _get_mock_extraction(self) -> List[Dict[str, Any]]:
        return [
            {
                "name": "台北101 (Mock Gemini)",
                "category": "景點",
                "evidence_text": "裡面提到台北101",
                "confidence_score": 0.99
            },
            {
                "name": "鼎泰豐 (Mock Gemini)",
                "category": "餐廳",
                "evidence_text": "與鼎泰豐。",
                "confidence_score": 0.98
            }
        ]

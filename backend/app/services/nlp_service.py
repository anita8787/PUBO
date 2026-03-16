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
            self.model = genai.GenerativeModel(self.model_name)
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
        你是一位專業的旅遊資料分析師。請分析下方的社群媒體貼文，並完成以下任務：
        1. **提取**：找出文中提到的所有「特定地點」、「店家」或「景點」(POIs)。
        2. **雙軌命名**：
           - `name`: **繁體中文顯示名**。若文中是簡稱（如「青沐」），請校正為正式店名。若原文為英文且無通用中文譯名，則保留英文。
           - `search_query`: **在地化外部搜尋字串**。這將用於 Google Maps API 搜尋經緯度。請包含「國家 + 城市 + 正式店名 + 當地原文店名(韓文/日文)」。
             *   例如：韓國聖水洞的鹽麵包店，`name` 為「自然島鹽麵包」，`search_query` 應為「Korea Seoul 자연도소금빵 성수」。
        3. **校正與驗證**：利用你的知識庫驗證該地點是否存在。若該地點已歇業或明顯不存在，請忽略。
        
        請嚴格遵守以下 JSON 陣列格式回傳，不要包含 Markdown：
        [
            {{
                "name": "繁體中文顯示名稱",
                "search_query": "用於 Google 搜尋的在地化關鍵字 (包含當地語言原文)",
                "category": "類別(如：餐廳、咖啡、景點、商店)",
                "evidence_text": "原文中提到該地點的句子段落",
                "confidence_score": 0.0~1.0 之間的數值
            }}
        ]

        **重要規則：**
        1. **去重**：如果同一個地點出現多次，請只列出最精確的那一個。
        2. **過濾非主角**：請只抓取這篇貼文真正要介紹或推薦的地點。
           - **❌ 排除地標參考**：(例如：「在 **台北101** 附近」 -> 請忽略 台北101，只抓主角)。
           - **❌ 排除比較對象**：(例如：「比 **鼎泰豐** 還好吃」 -> 請忽略 鼎泰豐)。
           - **❌ 排除廣泛地名**：(例如：「**信義區** 美食」、「**京都** 景點」 -> 請忽略行政區)。
        3. **國家感知**：請根據文中內容判斷地點所屬國家，並在 `search_query` 中加入該國語言的店名。

        貼文內容：
        \"\"\"
        {text}
        \"\"\"
        """

        try:
            # Gemini 生成內容
            response = self.model.generate_content(prompt)
            print(f"🤖 [NLP] Gemini Raw Response: {response.text}") # Debug log
            content = response.text
            
            # 清理 Markdown 標記 (Gemini 有時會包 ```json ... ```)
            content = content.replace("```json", "").replace("```", "").strip()
            
            data = json.loads(content)
            
            if isinstance(data, list):
                return data
            # 若 Gemini 回傳了包含 key 的 dict
            if isinstance(data, dict):
                 # 嘗試尋找常見的 key
                 for key in ["places", "pois", "locations"]:
                     if key in data and isinstance(data[key], list):
                         return data[key]
                 # 若無法識別，回傳空陣列
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

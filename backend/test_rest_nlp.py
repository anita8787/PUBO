import os
import sys
from app.services.nlp_service import NLPService

def test():
    print("🧪 Testing REST NLP Extraction with User Text...")
    nlp = NLPService()
    
    test_text = """
    \ 首爾安國咖啡廳！ /
    去韓國就是要跑咖！ 不要錯過安國~
    這裡推薦幾間：
    📍 London Bagel Museum (倫敦貝果博物館)
    📍 Cafe Onion Anguk
    """
    
    results = nlp.extract_places_from_text(test_text)
    
    print("\n--- Extraction Results ---")
    if not results:
        print("❌ No places extracted.")
    else:
        for i, p in enumerate(results):
            print(f"{i+1}. {p.get('name')} | Query: {p.get('search_query')}")
    
    print("\n--- Final Check ---")
    if len(results) > 0:
        print("✅ Success! REST API worked.")
    else:
        print("⚠️ Warning: 0 places found. Check log above.")

if __name__ == "__main__":
    test()

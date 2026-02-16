import requests
import time
import json
import sys

BASE_URL = "http://127.0.0.1:8000"

def test_full_flow(url: str):
    print(f"🚀 開始測試連結: {url}")
    
    # 1. 提交分享任務
    share_payload = {"url": url}
    try:
        response = requests.post(f"{BASE_URL}/api/v1/share", json=share_payload)
    except requests.exceptions.ConnectionError:
        print("❌ 無法連線至後端服務。請確保已執行 uvicorn app.main:app --reload")
        return
    
    if response.status_code != 200:
        print(f"❌ 提交任務失敗: {response.text}")
        return

    task_data = response.json()
    task_id = task_data["task_id"]
    print(f"✅ 任務已提交, Task ID: {task_id}")

    # 2. 輪詢任務狀態
    while True:
        try:
            status_response = requests.get(f"{BASE_URL}/api/v1/task/{task_id}")
        except requests.exceptions.ConnectionError:
            print("❌ 連線中斷。後端可能正在重新啟動...")
            time.sleep(2)
            continue
            
        if status_response.status_code == 404:
            print("❌ 找不到任務。可能是後端已重啟導致記憶體資料遺失。請重新執行腳本。")
            break
            
        if status_response.status_code != 200:
            print(f"❌ 查詢任務失敗: {status_response.text}")
            break

        status_data = status_response.json()
        status = status_data.get("status")
        print(f"⏳ 正在解析中... (當前狀態: {status})")
        
        if status == "completed":
            print("\n🎉 解析完成！")
            result = status_data.get("result")
            if not result:
                print("⚠️  任務已完成但無結果資料。")
                break
                
            print("--- 內容資訊 ---")
            content = result["content"]
            print(f"標題: {content.get('title')}")
            print(f"作者: {content.get('author_name')}")
            print(f"原文片段: {content.get('text')[:100]}...")
            
            print("\n--- 提取到的建議地點 ---")
            for p in result["suggested_places"]:
                place = p["place"]
                print(f"📍 {place['name']} ({place['category']})")
                print(f"   證據: {p['evidence_text']}")
                print(f"   信心值: {p['confidence_score']}")
            break
        elif status == "failed":
            print(f"❌ 任務失敗: {status_data.get('error')}")
            break
        
        time.sleep(10)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        test_url = sys.argv[1]
    else:
        test_url = "https://www.instagram.com/reel/DNYPFXST6Ws/?utm_source=ig_web_copy_link&igsh=MzRlODBiNWFlZA==" 
        print("ℹ️  正在使用腳本內設定的預設連結進行測試。")
        
    print("-" * 30)
    test_full_flow(test_url)

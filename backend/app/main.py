from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, Response, UploadFile, File
from fastapi.concurrency import run_in_threadpool
from typing import List, Optional
import json
import random
import uuid
import os
from datetime import datetime, timedelta
from .models import schemas
from .models.database import get_db, init_db, Task, SessionLocal, AIAnalysisCache, CuratedPost, Content, Place, ContentPlaceAssociation, PlaceCache, FirestoreSession
from .services.places_service import PlacesService
from .services.apify_service import ApifyService
from .services.nlp_service import NLPService
from .services.youtube_service import YouTubeService
from .services.image_service import ImageService
from .api import collection, trips
import firebase_admin
from firebase_admin import credentials

app = FastAPI()

app.include_router(collection.router, prefix="/api/v1", tags=["collection"])
app.include_router(trips.router, prefix="/api/v1", tags=["trips"])

# 初始化服務
apify_service = ApifyService()
nlp_service = NLPService()
youtube_service = YouTubeService()
places_service = PlacesService()
image_service = ImageService()

@app.on_event("startup")
def on_startup():
    init_db()
    
    # 初始化 Firebase Admin SDK
    if not firebase_admin._apps:
        key_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "firebase-key.json")
        if os.path.exists(key_path):
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK 成功啟動")
        else:
            print(f"⚠️ 找不到 Firebase 私鑰：{key_path}")
    else:
        print("ℹ️ Firebase Admin SDK 已初始化，跳過重複設定")

@app.get("/")
def read_root():
    return {"message": "Welcome to Pubo API"}

@app.get("/api/v1/debug/places")
async def debug_places(query: str):
    """Temporary endpoint to debug Vercel Google Places failures."""
    try:
        if not places_service.api_key:
            return {"error": "API Key is missing"}
            
        url = f"{places_service.base_url}/places:searchText"
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": places_service.api_key,
            "X-Goog-FieldMask": "places.name,places.id,places.formattedAddress,places.location,places.types,places.displayName,places.primaryType"
        }
        payload = {"textQuery": query, "maxResultCount": 1, "languageCode": "zh-TW"}
        
        import requests
        response = requests.post(url, headers=headers, json=payload)
        return {"status_code": response.status_code, "response": response.json(), "key_prefix": places_service.api_key[:5] if places_service.api_key else None}
    except Exception as e:
        return {"error": str(e)}

def normalize_url(url: str) -> str:
    """Normalize URL to improve cache hit rate"""
    import re
    from urllib.parse import urlparse, urlunparse, parse_qs, urlencode
    
    url = url.strip()
    
    # Extract Instagram shortcode and normalize
    ig_match = re.search(r'instagram\.com/(?:p|reels|tv|sh)/([^/?#\s]+)', url)
    if ig_match:
        shortcode = ig_match.group(1).rstrip('/')
        return f"https://www.instagram.com/p/{shortcode}/"
    
    # Remove common tracking parameters
    try:
        parsed = urlparse(url)
        if parsed.query:
            params = parse_qs(parsed.query, keep_blank_values=True)
            # Remove tracking params
            tracking_params = {'igsh', 'igshid', 'utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'img_index', 'fbclid'}
            filtered = {k: v for k, v in params.items() if k not in tracking_params}
            new_query = urlencode(filtered, doseq=True)
            url = urlunparse(parsed._replace(query=new_query))
    except Exception:
        pass
    
    return url

async def process_share_task(task_id: str, url: str):
    """
    非同步處理函數：爬取內容並使用 LLM 解析
    """
    # 背景任務需要獨立的 DB Session
    db = SessionLocal()
    try:
        task = db.query(Task).filter(Task.task_id == task_id).first()
        if not task:
            return

        task.status = "processing"
        task.progress = 0.1
        db.commit()
    
        source_type = "instagram"
        print(f"TASK {task_id}: 開始處理 {url}")
        # Normalize URL to improve cache hit rate
        normalized_url = normalize_url(url)
        
        # --- Layer 1: URL Cache (Check if content already exists) ---
        existing_content = db.query(Content).filter(Content.source_url == normalized_url).first()
        if not existing_content:
            existing_content = db.query(Content).filter(Content.source_url == url).first()
        if existing_content:
            # Query associations from Firestore
            associations = db.query(ContentPlaceAssociation).filter(ContentPlaceAssociation.content_id == existing_content.id).all()
            
            # Check if the cached image URL is the old broken format
            is_broken_image = False
            if existing_content.preview_thumbnail_url and "storage.googleapis.com" in existing_content.preview_thumbnail_url and "token=" not in existing_content.preview_thumbnail_url:
                is_broken_image = True
                
            if len(associations) == 0 or is_broken_image:
                print(f"⚠️ [Cache Miss] Found content but 0 associations or broken image URL. Re-extracting for {url}")
                existing_content = None # Force re-extraction
            else:
                print(f"🎯 [Cache Hit] Layer 1: URL Cache Hit for {url}")
                content_base = schemas.ContentBase(
                    source_type=existing_content.source_type,
                    source_url=existing_content.source_url,
                    title=existing_content.title,
                    text=existing_content.text,
                    author_name=existing_content.author_name,
                    author_avatar_url=existing_content.author_avatar_url,
                    preview_thumbnail_url=existing_content.preview_thumbnail_url,
                    published_at=existing_content.published_at
                )
                suggested_places = []
                for assoc in associations:
                    place_doc = db.db_client.collection("places").document(str(assoc.place_id)).get()
                    place = Place(_doc_id=place_doc.id, **place_doc.to_dict()) if place_doc.exists else None
                    if place:
                        suggested_places.append(schemas.ContentPlaceInfo(
                            place=schemas.PlaceBase(
                                place_id=place.place_id,
                                name=place.name,
                                address=place.address,
                                latitude=place.latitude,
                                longitude=place.longitude,
                                category=place.category,
                                image_url=place.image_url,
                                rating=place.rating,
                                user_ratings_total=place.user_ratings_total,
                                opening_hours=place.opening_hours
                            ),
                            evidence_text=assoc.evidence_text,
                            confidence_score=assoc.confidence_score
                        ))
                
                extraction_response = schemas.ExtractionResponse(
                    content=content_base,
                    suggested_places=suggested_places
                )
                task.result = json.loads(extraction_response.json())
                task.status = "completed"
                task.progress = 1.0
                db.commit()
                return
        # --- End Layer 1 ---

        # --- Layer 1.5: Task Cache (Check recent successful tasks with same URL) ---
        for search_url in [normalized_url, url]:
            existing_tasks = db.query(Task).filter(
                Task.target_url == search_url,
                Task.status == "completed"
            ).all()
            for existing_task in existing_tasks:
                if existing_task and existing_task.result and existing_task.task_id != task_id:
                    # Check if the task result contains a broken image URL
                    is_broken = False
                    cached_thumb = existing_task.result.get("content", {}).get("preview_thumbnail_url")
                    if cached_thumb and "storage.googleapis.com" in cached_thumb and "token=" not in cached_thumb:
                        is_broken = True
                        
                    if not is_broken:
                        print(f"🎯 [Cache Hit] Layer 1.5: Task Cache Hit for {url}")
                        task.result = existing_task.result
                        task.status = "completed"
                        task.progress = 1.0
                        db.commit()
                        return
        # --- End Layer 1.5 ---
        
        # 1. 判斷來源與爬取內容
        scraped_data = None
        extracted_places = []
        is_google_maps = "maps.app.goo.gl" in url or "google.com/maps" in url
        
        if is_google_maps:
            source_type = "google_maps"
            place_name = "Google Maps Location"
            
            # Extract URL from text using regex
            import re
            import requests
            url_match = re.search(r'https?://[^\s]+', url)
            if url_match:
                actual_url = url_match.group(0)
                try:
                    # Fetch the page to get the true title
                    headers = {
                        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1",
                        "Accept-Language": "zh-TW,zh;q=0.9"
                    }
                    resp = requests.get(actual_url, headers=headers, timeout=5)
                    title_match = re.search(r'<title>(.*?)</title>', resp.text, re.IGNORECASE)
                    if title_match:
                        full_title = title_match.group(1)
                        import html
                        full_title = html.unescape(full_title)
                        # Google Maps titles are usually "Name - Google Maps"
                        clean_title = full_title.replace(" - Google Maps", "").replace("Google Maps - ", "").replace(" - Google 網頁版地圖", "").strip()
                        if clean_title and "Google" not in clean_title:
                            place_name = clean_title
                    
                    # If title was empty or default, parse /maps/place/ from HTML body
                    if place_name == "Google Maps Location":
                        import urllib.parse
                        place_matches = re.findall(r'/maps/place/([^/@?"\']+)', resp.text)
                        for pm in place_matches:
                            try:
                                decoded = urllib.parse.unquote(pm)
                                if "%" in decoded:
                                    decoded = urllib.parse.unquote(decoded)
                                decoded = decoded.replace("+", " ").strip()
                                # Check if it is a coordinate
                                is_coord = re.match(r'^[\d\.,\-\s]+$', decoded) is not None
                                if decoded and not is_coord:
                                    place_name = decoded
                                    break
                            except Exception as ex:
                                print(f"⚠️ [Backend] Error decoding HTML place match: {ex}")
                except Exception as e:
                    print(f"⚠️ [Backend] Error fetching Google Maps title: {e}")
            
            # Fallback if scraping failed
            if place_name == "Google Maps Location":
                lines = [line.strip() for line in url.split("\n") if line.strip()]
                if len(lines) > 0 and not lines[0].startswith("http"):
                    place_name = lines[0]
            
            # 🔥 極度暴力清洗：直接從源頭砍掉地址、加號碼、中間點
            address = ""
            original_search_query = place_name
            if place_name and place_name != "Google Maps Location":
                import re
                # 1. 將 `·` 或 `•` 後面的東西切分出來，當作 address 保留
                parts = re.split(r'\s*[·•]\s*', place_name)
                clean_name = parts[0]
                if len(parts) > 1:
                    address = parts[1]
                
                # 針對 clean_name 進行暴力清洗
                # 2. 砍掉 Plus Code (如 EF56+78)
                clean_name = re.sub(r'[A-Z0-9]{2,4}\+[A-Z0-9]{2,4}.*$', '', clean_name)
                # 3. 砍掉常見的日本英文地址開頭 (如 1 Chome, 2-chome)
                clean_name = re.sub(r'\s*\d+\s*[Cc]home.*$', '', clean_name)
                # 4. 砍掉樓層 (如 1F, B1)
                clean_name = re.sub(r'\s*\d+[Ff]\b.*$', '', clean_name)
                clean_name = re.sub(r'\s*[Bb]\d+\b.*$', '', clean_name)
                clean_name = clean_name.strip()
                
                place_name = clean_name
            
            scraped_data = {
                "text": url,
                "title": f"來自 Google Maps: {place_name}",
                "preview_thumbnail_url": None,
                "author_name": None,
                "author_avatar_url": None
            }
            # 【核心修正】將 address 放入 dictionary 中，供 stage_1_query 使用
            extracted_places = [{"name": place_name, "search_query": original_search_query, "address": address, "category": "景點"}]
            print(f"🎯 [Backend] Detected Google Maps share. Extracted name: {place_name}")
            
        elif not url.startswith("http://") and not url.startswith("https://"):
            source_type = "plain_text"
            scraped_data = {
                "text": url,
                "title": "來自純文字的匯入",
                "preview_thumbnail_url": None,
                "author_name": None,
                "author_avatar_url": None
            }
        elif "youtube.com" in url or "youtu.be" in url:
            source_type = "youtube"
            # 使用 YouTubeService (Sync -> Threadpool)
            scraped_data = await run_in_threadpool(youtube_service.process_video, url)
        elif "threads.net" in url or "threads.com" in url:
            source_type = "threads"
            scraped_data = await run_in_threadpool(apify_service.scrape_threads_post, url)
        else:
            source_type = "instagram"
            scraped_data = await run_in_threadpool(apify_service.extract_instagram_post, url)
            
        if scraped_data:
            print(f"🔍 [Backend] Final Scraped Text: {scraped_data.get('text', '')[:200]}...") # Log 前200字
            
        print(f"TASK {task_id}: {source_type} 爬取完成，結果: {True if scraped_data else False}")

        if not scraped_data:
            task.status = "failed"
            task.error = "無法爬取該連結內容"
            db.commit()
            return

        task.progress = 0.4
        db.commit()

        # 2. 使用 LLM 解析地點名稱 (僅在非 Google Maps 時執行)
        if not extracted_places:
            print("🤖 [Backend] Sending to NLP Service...")
            extracted_places = await run_in_threadpool(nlp_service.extract_places_from_text, scraped_data["text"])
        
        task.progress = 0.6
        db.commit()

        # 3. 使用 Google Places API 搜尋確切地點資訊 (Parallel Execution)
        import asyncio
        
        async def enrich_place(p, post_thumbnail=None):
            # --- 搜尋重試機制 ---
            search_name = p.get("search_query", p.get("name", "Unknown"))
            display_name = p.get("name", "Unknown")
            inferred_country = p.get("country", "")
            
            print(f"🔍 [Backend] Searching for: {search_name} (Display: {display_name}, Country: {inferred_country})")
            
            # --- Layer 2: Place Cache ---
            from app.models.database import PlaceCache
            
            cache_key = f"{inferred_country}_{p.get('city', '')}_{search_name}"
            
            # Use separate DB session inside threadpool? No, we are in async def but calling sync db methods.
            # Fast check cache
            cached_place = db.query(PlaceCache).filter(PlaceCache.search_key == cache_key).first()
            if cached_place and cached_place.updated_at > datetime.utcnow() - timedelta(days=7):
                if cached_place.status == "not_found":
                    print(f"🛑 [Cache Hit] Layer 2: Negative Cache for {cache_key}. Skipping...")
                    return None
                elif cached_place.google_place_id:
                    db_p = db.query(Place).filter(Place.place_id == cached_place.google_place_id).first()
                    if db_p:
                        print(f"🎯 [Cache Hit] Layer 2: Found {cache_key} in Place DB")
                    place_data = {
                        "place_id": db_p.place_id,
                        "name": db_p.name,
                        "address": db_p.address,
                        "latitude": db_p.latitude,
                        "longitude": db_p.longitude,
                        "category": db_p.category,
                        "image_url": db_p.image_url,
                        "rating": db_p.rating,
                        "user_ratings_total": db_p.user_ratings_total,
                        "opening_hours": db_p.opening_hours,
                        "google_place_id": cached_place.google_place_id
                    }
                    return schemas.ContentPlaceInfo(
                        place=schemas.PlaceBase(**place_data),
                        evidence_text=p.get("evidence_text"),
                        confidence_score=p.get("confidence_score", 0.0)
                    )

            # --- New 2-Stage Fallback Search ---
            # Stage 1: {Country} {City} {Name} {Address}
            stage_1_query = f"{inferred_country} {p.get('city', '')} {search_name} {p.get('address', '')}".strip()
            print(f"🔍 [Backend] Stage 1 Search: {stage_1_query}")
            google_place = await run_in_threadpool(places_service.search_place, stage_1_query)
            
            # Stage 2: {Name} only (Loose Search)
            if not google_place:
                stage_2_query = display_name
                print(f"🔄 [Backend] Stage 1 failed. Stage 2 (Loose Search): {stage_2_query}")
                google_place = await run_in_threadpool(places_service.search_place, stage_2_query)

            if not google_place:
                print(f"⚠️ [Backend] All Places API searches failed for {display_name}. Saving to Negative Cache and Skipping...")
                if cached_place:
                    cached_place.status = "not_found"
                    cached_place.updated_at = datetime.utcnow()
                else:
                    new_cache = PlaceCache(search_key=cache_key, status="not_found")
                    db.add(new_cache)
                db.commit()
                return None
            
            place_data = {
                "place_id": f"temp_{random.randint(1000, 9999)}",
                "name": display_name,
                "address": None,
                "latitude": 0.0,
                "longitude": 0.0,
                "category": p.get("category", "其他"),
                "google_place_id": None
            }

            # Use the place_id from Text Search Advanced, no more Place Details API calls
            search_id = google_place.get("id") or (google_place.get("name", "").split("/")[-1] if "/" in google_place.get("name", "") else google_place.get("name"))
            real_id = search_id
            
            place_data["place_id"] = real_id
            place_data["google_place_id"] = real_id
            place_data["address"] = google_place.get("formattedAddress", "")
            
            # 🌟 修正：用 Google 官方正式名稱覆蓋，確保 100% 精確與 Google Maps 一致
            if "displayName" in google_place and isinstance(google_place["displayName"], dict):
                place_data["name"] = google_place["displayName"].get("text", display_name)
            
            location = google_place.get("location", {})
            place_data["latitude"] = location.get("latitude", 0.0)
            place_data["longitude"] = location.get("longitude", 0.0)
            
            # 雖然我們從 FieldMask 中移除了 rating/opening_hours，這裡保留以防未來擴充，safe.get 回傳 None
            place_data["rating"] = google_place.get("rating")
            place_data["user_ratings_total"] = google_place.get("userRatingCount")
            place_data["opening_hours"] = google_place.get("regularOpeningHours")
            place_data["open_now"] = google_place.get("currentOpeningHours", {}).get("openNow")
            
            if "primaryType" in google_place:
                place_data["category"] = google_place["primaryType"].replace("_", " ").title()

            # 🔴 抗灰格方案：如果這個景點目前還沒有圖片，則繼承貼文原始封面圖 (防止行程出現灰色方塊)
            if not place_data.get("image_url") and post_thumbnail:
                place_data["image_url"] = post_thumbnail
                    
            original_image_url = place_data.get("image_url")
            place_data["image_url"] = "" # 設為空，讓前端顯示 loading 狀態

            # Create transient Place object to return, the caller loop will save it and update PlaceCache
            info_to_return = schemas.ContentPlaceInfo(
                place=schemas.PlaceBase(**place_data),
                evidence_text=p.get("evidence_text"),
                confidence_score=p.get("confidence_score", 0.0)
            )
            # Attach cache_key for the caller to save it
            setattr(info_to_return, "_cache_key", cache_key)
            setattr(info_to_return, "_google_place_id", real_id)
            setattr(info_to_return, "_original_image_url", original_image_url)
            return info_to_return

        # 先將封面圖片在前景上傳，因為只上傳一張圖片很快（約1秒），可以讓使用者馬上看到！
        # 其餘景點的多張圖片則維持在背景非同步上傳
        original_post_thumb = scraped_data.get("preview_thumbnail_url")
        post_thumb = original_post_thumb
        if post_thumb:
            try:
                print(f"TASK {task_id}: 正在前景上傳封面圖片...")
                permanent_thumb = await run_in_threadpool(image_service.upload_to_firebase, post_thumb)
                if permanent_thumb:
                    scraped_data["preview_thumbnail_url"] = permanent_thumb
                    post_thumb = permanent_thumb
            except Exception as e:
                print(f"TASK {task_id}: 封面圖片上傳失敗: {e}")
            
        enriched_places_raw = await asyncio.gather(*(enrich_place(p, post_thumb) for p in extracted_places))
        enriched_places = [p for p in enriched_places_raw if p is not None]
        
        task.progress = 0.9
        db.commit()

        # 4. 封裝結果
        content_base = schemas.ContentBase(
            source_type=source_type,
            source_url=url,
            title=scraped_data.get("title", f"來自 {source_type} 的分享"),
            text=scraped_data["text"],
            author_name=scraped_data.get("author_name"),
            author_avatar_url=scraped_data.get("author_avatar_url"),
            preview_thumbnail_url=scraped_data.get("preview_thumbnail_url"),
            published_at=None
        )

        extraction_response = schemas.ExtractionResponse(
            content=content_base,
            suggested_places=enriched_places
        )
        
        # 5. 持久化到資料庫 (供將來收藏與管理使用)
        # --- Save Content ---
        db_content = db.query(Content).filter(Content.source_url == url).first()
        if not db_content:
            db_content = Content(
                source_type=source_type,
                source_url=url,
                title=content_base.title,
                text=content_base.text,
                author_name=content_base.author_name,
                author_avatar_url=content_base.author_avatar_url,
                preview_thumbnail_url=content_base.preview_thumbnail_url
            )
            db.add(db_content)
            db.commit()
            db.refresh(db_content)
        
        # --- Save Places and Associations ---
        for info in enriched_places:
            p = info.place
            # Check if place exists (by place_id if available, or name/lat/lon)
            db_place = None
            if p.place_id:
                db_place = db.query(Place).filter(Place.place_id == p.place_id).first()
            
            if not db_place:
                db_place = Place(
                    place_id=p.place_id,
                    name=p.name,
                    address=p.address,
                    latitude=p.latitude,
                    longitude=p.longitude,
                    category=p.category,
                    image_url=p.image_url,
                    rating=p.rating,
                    user_ratings_total=p.user_ratings_total,
                    opening_hours=p.opening_hours
                )
                db.add(db_place)
                db.commit()
                db.refresh(db_place)
            
            # Check Association
            assoc = db.query(ContentPlaceAssociation).filter(
                ContentPlaceAssociation.content_id == db_content.id,
                ContentPlaceAssociation.place_id == db_place.id
            ).first()
            if not assoc:
                db.add(ContentPlaceAssociation(
                    content_id=db_content.id,
                    place_id=db_place.id,
                    evidence_text=info.evidence_text,
                    confidence_score=info.confidence_score
                ))
            
            # --- Save to PlaceCache ---
            if hasattr(info, "_cache_key"):
                cache_key = info._cache_key
                google_pid = info._google_place_id
                db_cache = db.query(PlaceCache).filter(PlaceCache.search_key == cache_key).first()
                if not db_cache:
                    db_cache = PlaceCache(search_key=cache_key, place_id=db_place.id, google_place_id=google_pid, status="found")
                    db.add(db_cache)
                else:
                    db_cache.place_id = db_place.id
                    db_cache.google_place_id = google_pid
                    db_cache.status = "found"
                    db_cache.updated_at = datetime.utcnow()
        
        db.commit()
        
        # 存入 Result (需 dump 為 JSON 相容格式)
        task.result = json.loads(extraction_response.json())
        task.status = "completed"
        task.progress = 1.0
        db.commit()

        # 6. 背景非同步轉存景點圖片到 Firebase (不阻塞客戶端)
        print(f"TASK {task_id}: 開始背景轉存圖片...")
        try:
            for info in enriched_places:
                orig_url = getattr(info, "_original_image_url", None)
                if orig_url:
                    permanent_url = await run_in_threadpool(image_service.upload_to_firebase, orig_url)
                    if permanent_url:
                        db_place = db.query(Place).filter(Place.place_id == info.place.place_id).first()
                        if db_place:
                            db_place.image_url = permanent_url
                            db.commit()
            print(f"TASK {task_id}: 背景圖片轉存完成！")
        except Exception as e:
            print(f"TASK {task_id}: 背景圖片轉存失敗: {e}")

    except Exception as e:
        print(f"Task Error: {e}")
        task.status = "failed"
        task.error = str(e)
        db.commit()
    finally:
        db.close()

@app.post("/api/v1/share", response_model=schemas.TaskResponse)
async def share_content(request: schemas.ShareRequest, background_tasks: BackgroundTasks, db: FirestoreSession = Depends(get_db)):
    """
    接收社群分享連結，啟期異步解析任務
    """
    task_id = str(uuid.uuid4())
    
    new_task = Task(
        task_id=task_id,
        status="pending",
        target_url=request.url
    )
    db.add(new_task)
    db.commit()
    db.refresh(new_task)
    
    background_tasks.add_task(process_share_task, task_id, request.url)
    
    return schemas.TaskResponse(
        task_id=new_task.task_id,
        status=schemas.TaskStatus(new_task.status),
        result=None,
        error=None
    )

@app.get("/api/v1/task/{task_id}", response_model=schemas.TaskResponse)
async def get_task_status(task_id: str, response: Response, db: FirestoreSession = Depends(get_db)):
    """
    查詢任務狀態與結果
    """
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    task = db.query(Task).filter(Task.task_id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="找不到該任務")
        
    return schemas.TaskResponse(
        task_id=task.task_id,
        status=schemas.TaskStatus(task.status),
        progress=task.progress,
        result=task.result,
        error=task.error
    )

@app.get("/api/v1/library/contents", response_model=List[schemas.ContentResponse])
async def list_contents(db: FirestoreSession = Depends(get_db)):
    """
    顯示收藏庫中的內容模式 (連結模式)
    """
    contents = db.query(Content).filter(Content.is_collected == 1).all()
    contents.sort(key=lambda x: getattr(x, "created_at", None) or datetime.min, reverse=True)
    return contents
    
@app.get("/api/v1/library/places", response_model=List[schemas.PlaceBase])
async def list_places(db: FirestoreSession = Depends(get_db)):
    """
    顯示收藏庫中的地點模式 (地點模式)
    """
    places = db.query(Place).order_by(Place.created_at.desc()).all()
    # 轉換為 Pydantic 模型
    return [schemas.PlaceBase(
        place_id=p.place_id,
        name=p.name,
        address=p.address,
        latitude=p.latitude,
        longitude=p.longitude,
        category=p.category,
        image_url=p.image_url,
        rating=p.rating,
        user_ratings_total=p.user_ratings_total,
        opening_hours=p.opening_hours
    ) for p in places]

# --- Curated Posts API ---

@app.get("/api/v1/curated", response_model=List[schemas.CuratedPostResponse])
async def list_curated_posts(country: Optional[str] = None, trip_category: Optional[str] = None, db: FirestoreSession = Depends(get_db)):
    """
    獲取精選 IG 貼文列表 (首頁靈感庫)，支援國家與行程分類篩選
    """
    query = db.query(CuratedPost)
    if country:
        query = query.filter(CuratedPost.country == country)
    if trip_category:
        query = query.filter(CuratedPost.trip_category == trip_category)
    results = query.all()
    
    def get_sort_key(item):
        val = getattr(item, "created_at", None)
        if not val:
            return ""
        if hasattr(val, "isoformat"):
            return val.isoformat()
        return str(val)
        
    results.sort(key=get_sort_key, reverse=True)
    return results


def detect_trip_category(title: str, spots_data: list) -> str:
    """
    根據貼文標題和景點分類，自動判斷行程類型。
    分類：shopping / dessert / meal / sightseeing / mixed
    """
    title_lower = (title or "").lower()
    
    # 關鍵字映射
    shopping_keywords = ["購物", "逛街", "shopping", "商店", "百貨", "市場", "outlet", "便宜", "折扣", "免稅", "買"]
    dessert_keywords  = ["甜點", "下午茶", "咖啡", "dessert", "cafe", "甜食", "蛋糕", "冰淇淋", "抹茶", "鬆餅", "布丁", "巧克力", "珍奶", "奶茶", "飲料", "tea"]
    meal_keywords     = ["美食", "拉麵", "壽司", "燒肉", "居酒屋", "火鍋", "炸物", "串燒", "dinner", "lunch", "餐廳", "食堂", "料理", "吃飯", "吃貨", "麵", "飯", "牛排", "seafood", "海鮮"]
    sightseeing_keywords = ["景點", "觀光", "寺廟", "神社", "博物館", "公園", "花", "夜景", "古城", "古蹟", "城堡", "瀑布", "海灘", "mountain", "hiking", "溫泉", "花火", "打卡"]
    
    def keyword_score(text: str, keywords: list) -> int:
        return sum(1 for kw in keywords if kw in text)
    
    # 也從景點分類分析
    spot_categories = [str(s.get("category", "")).lower() for s in (spots_data or [])]
    food_spot_count = sum(1 for c in spot_categories if c in ["food", "meal", "restaurant"])
    shopping_spot_count = sum(1 for c in spot_categories if c in ["shopping", "mall"])
    
    scores = {
        "shopping":    keyword_score(title_lower, shopping_keywords) + shopping_spot_count * 2,
        "dessert":     keyword_score(title_lower, dessert_keywords),
        "meal":        keyword_score(title_lower, meal_keywords) + food_spot_count,
        "sightseeing": keyword_score(title_lower, sightseeing_keywords),
    }
    
    max_score = max(scores.values())
    if max_score >= 1:
        # 取分數最高的分類
        best = max(scores, key=lambda k: scores[k])
        return best
    
    return "mixed"


def auto_create_curated_post(content_obj: Content, spots_data: list, db: FirestoreSession):
    """
    從分析結果自動建立精選貼文 (用於推薦行程首頁)
    新增：阻斷景點數為 0 的無效貼文，並防止網址重複。
    """
    from .models.database import CuratedPost
    import uuid
    
    # 0. 阻斷機制：如果沒有成功辨識出任何景點，則不建立精選貼文，避免污染推薦清單
    if not spots_data or len(spots_data) == 0:
        print(f"⚠️ [Curated] Skipping generation for {content_obj.title}: No spots identified.")
        return None

    # 1. 檢查網址是否已存在於精選貼文中
    existing_post = db.query(CuratedPost).filter(CuratedPost.source_url == content_obj.source_url).first()
    
    # 使用 AI 偵測國家
    nlp_service = NLPService()
    final_country = nlp_service.detect_country(content_obj.title, content_obj.text, spots_data)
    
    final_category = detect_trip_category(content_obj.title, spots_data)
    
    if existing_post:
        print(f"🔄 [Curated] Updating existing curated post: {content_obj.title}")
        existing_post.title = content_obj.title
        # 確保使用永久連結
        existing_post.cover_image = image_service.upload_to_firebase(content_obj.preview_thumbnail_url)
        existing_post.author = content_obj.author_name
        existing_post.spots = spots_data
        existing_post.spot_count = len(spots_data)
        existing_post.country = final_country
        existing_post.trip_category = final_category
        db.commit()
        db.refresh(existing_post)
        return existing_post
    
    print(f"🚀 [Curated] Creating new curated post: {content_obj.title} (分類: {final_category})")
    new_curated = CuratedPost(
        id=str(uuid.uuid4()),
        title=content_obj.title,
        cover_image=image_service.upload_to_firebase(content_obj.preview_thumbnail_url),
        author=content_obj.author_name,
        source_url=content_obj.source_url,
        spots=spots_data,
        spot_count=len(spots_data),
        country=final_country,
        trip_category=final_category
    )
    db.add(new_curated)
    db.commit()
    db.refresh(new_curated)
    return new_curated

@app.post("/api/v1/curated", response_model=schemas.CuratedPostResponse)
async def create_curated_post(post: schemas.CuratedPostCreate, db: FirestoreSession = Depends(get_db)):
    """
    手動新增精選貼文
    """
    import uuid
    
    # Check if this source_url + title already exists, so we don't overwrite user's split posts
    existing = None
    if post.source_url and post.source_url.strip() != "" and post.source_url != "null":
        # We need to fetch all with this url, and find one with the same title
        all_with_url = db.query(CuratedPost).filter(CuratedPost.source_url == post.source_url).all()
        for p in all_with_url:
            if p.title == post.title:
                existing = p
                break
        
    if existing:
        # Update existing post instead of failing
        existing.title = post.title
        existing.cover_image = await run_in_threadpool(image_service.upload_to_firebase, post.cover_image)
        existing.author = post.author
        existing.spots = post.spots
        existing.spot_count = post.spot_count or len(post.spots)
        existing.country = post.country
        existing.trip_category = detect_trip_category(post.title, post.spots)
        if post.uploader_id:
            existing.uploader_id = post.uploader_id
        db.commit()
        db.refresh(existing)
        return existing
    
    # 使用 AI 偵測國家 (如果前端傳來的為空或是預設佔位符)
    final_country = post.country
    if not final_country or final_country == "" or final_country == "韓國":
        final_country = nlp_service.detect_country(post.title, "", post.spots)

    final_category = detect_trip_category(post.title, post.spots)
    new_post = CuratedPost(
        id=str(uuid.uuid4()),
        title=post.title,
        cover_image=await run_in_threadpool(image_service.upload_to_firebase, post.cover_image),
        author=post.author,
        source_url=post.source_url,
        spots=post.spots,
        spot_count=post.spot_count or len(post.spots),
        country=final_country,
        trip_category=final_category,
        uploader_id=post.uploader_id
    )
    try:
        db.add(new_post)
        db.commit()
        return new_post
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"建立精選貼文失敗: {str(e)}")

@app.delete("/api/v1/curated/{post_id}")
async def delete_curated_post(post_id: str, db: FirestoreSession = Depends(get_db)):
    """
    刪除精選貼文
    """
    post_doc = db.db_client.collection("curated_posts").document(post_id).get()
    post = CuratedPost(_doc_id=post_doc.id, **post_doc.to_dict()) if post_doc.exists else None
    
    if not post:
        raise HTTPException(status_code=404, detail="Curated post not found")
    
    try:
        db.delete(post)
        db.commit()
        return {"status": "success"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/curated/auto", response_model=schemas.CuratedPostResponse)
async def auto_create_curated_post_endpoint(request: schemas.ShareRequest, db: FirestoreSession = Depends(get_db)):
    """
    輸入任何 IG 連結，自動爬取 + 解析 + 存入精選資料庫
    """
    # 1. Scrape IG
    info = await run_in_threadpool(apify_service.extract_instagram_post, request.url)
    if not info:
        raise HTTPException(status_code=404, detail="無法爬取該貼文")
    
    # 2. Extract Spots
    spots = await run_in_threadpool(nlp_service.extract_places_from_text, info.get("text", ""))
    
    # 3. Detect Country
    title = info.get("title") or f"{info.get('author_name', '旅遊達人')} 的分享"
    text = info.get("text", "")
    country = await run_in_threadpool(nlp_service.detect_country, title, text, spots)
    
    # 4. Create CuratedPost
    post_id = str(uuid.uuid4())
    new_post = CuratedPost(
        id=post_id,
        title=title,
        cover_image=await run_in_threadpool(image_service.upload_to_firebase, info.get("preview_thumbnail_url")),
        author=info.get("author_name"),
        source_url=request.url,
        spots=spots,
        spot_count=len(spots),
        country=country
    )
    db.add(new_post)
    db.commit()
    return new_post

@app.post("/api/v1/upload/image")
async def upload_image(file: UploadFile = File(...)):
    """
    上傳自訂景點圖片到 Firebase Storage，並回傳永久公開 URL
    """
    try:
        contents = await file.read()
        content_type = file.content_type or "image/jpeg"
        
        # 使用 image_service 上傳二進位資料
        public_url = await run_in_threadpool(image_service.upload_bytes_to_firebase, contents, content_type)
        if not public_url:
            raise HTTPException(status_code=500, detail="上傳圖片到 Firebase Storage 失敗")
            
        return {"url": public_url}
    except Exception as e:
        print(f"❌ [main.py] upload_image error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

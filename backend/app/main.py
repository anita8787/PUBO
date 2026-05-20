from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, Response, UploadFile, File
from fastapi.concurrency import run_in_threadpool
from typing import List, Optional
import json
import random
import uuid
import os
from sqlalchemy.orm import Session
from .models import schemas
from .models.database import get_db, init_db, Task, SessionLocal, AIAnalysisCache, CuratedPost, Content, Place, ContentPlaceAssociation
from .services.places_service import PlacesService
from .services.apify_service import ApifyService
from .services.nlp_service import NLPService
from .services.youtube_service import YouTubeService
from .services.image_service import ImageService
from .api import trips, collection
import firebase_admin
from firebase_admin import credentials

app = FastAPI()

app.include_router(trips.router, prefix="/api/v1", tags=["trips"])
app.include_router(collection.router, prefix="/api/v1", tags=["collection"])

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
            "X-Goog-FieldMask": "places.name,places.id,places.formattedAddress,places.location,places.types,places.rating,places.userRatingCount,places.displayName,places.primaryType,places.currentOpeningHours,places.regularOpeningHours"
        }
        payload = {"textQuery": query, "maxResultCount": 1, "languageCode": "zh-TW"}
        
        import requests
        response = requests.post(url, headers=headers, json=payload)
        return {"status_code": response.status_code, "response": response.json(), "key_prefix": places_service.api_key[:5] if places_service.api_key else None}
    except Exception as e:
        return {"error": str(e)}

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
        
        # 1. 爬取內容
        scraped_data = None
        if not url.startswith("http://") and not url.startswith("https://"):
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

        # 2. 使用 LLM 解析地點名稱 (Sync -> Threadpool)
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
            
            # --- 搜尋重試機制 (3-Stage Fallback) ---
            # 1. 精確搜尋 (國家 + 城市 + 搜尋字串)
            google_place = await run_in_threadpool(places_service.search_place, f"{inferred_country} {search_name}")
            
            # 2. 失敗則嘗試：名稱 + 城市
            if not google_place:
                retry_query_1 = f"{search_name} {p.get('city', '')}"
                print(f"🔄 [Backend] Precise search failed. Retrying: {retry_query_1}")
                google_place = await run_in_threadpool(places_service.search_place, retry_query_1)
            
            # 3. 失敗則嘗試：直接搜店名 (寬鬆搜尋)
            if not google_place:
                retry_query_2 = display_name
                print(f"🔄 [Backend] City search failed. Retrying with name only: {retry_query_2}")
                google_place = await run_in_threadpool(places_service.search_place, retry_query_2)

            # 4. 終極方案：如果 Google Maps API 都找不到，呼叫 AI 強制給出近似地點資訊
            ai_fallback_data = None
            if not google_place:
                print(f"⚠️ [Backend] All Places API searches failed for {display_name}. Falling back to AI Geocoding...")
                ai_fallback_data = await run_in_threadpool(nlp_service.ai_geocoding, display_name, inferred_country, p.get('city', ''))
            
            place_data = {
                "place_id": f"temp_{random.randint(1000, 9999)}",
                "name": display_name,
                "address": None,
                "latitude": 0.0,
                "longitude": 0.0,
                "category": p.get("category", "其他"),
                "google_place_id": None
            }

            if google_place:
                formatted_address = google_place.get("formattedAddress", "")
                
                # Use Google Place ID as the primary ID to ensure deduplication on client side
                real_id = google_place.get("name", "").split("/")[-1] if "/" in google_place.get("name", "") else google_place.get("id")
                
                place_data["place_id"] = real_id
                place_data["google_place_id"] = real_id
                place_data["address"] = formatted_address
                
                location = google_place.get("location", {})
                place_data["latitude"] = location.get("latitude", 0.0)
                place_data["longitude"] = location.get("longitude", 0.0)
                
                place_data["rating"] = google_place.get("rating")
                place_data["user_ratings_total"] = google_place.get("userRatingCount")
                place_data["opening_hours"] = google_place.get("regularOpeningHours")
                place_data["open_now"] = google_place.get("currentOpeningHours", {}).get("openNow")
                
                if "primaryType" in google_place:
                    place_data["category"] = google_place["primaryType"].replace("_", " ").title()
            elif ai_fallback_data:
                # Use AI Geocoding Data as last resort
                place_data["address"] = ai_fallback_data.get("address")
                place_data["latitude"] = ai_fallback_data.get("latitude", 0.0)
                place_data["longitude"] = ai_fallback_data.get("longitude", 0.0)
                print(f"✅ [Backend] Successfully applied AI Geocoding for {display_name}")

            # 🔴 抗灰格方案：如果這個景點目前還沒有圖片，則繼承貼文原始封面圖 (防止行程出現灰色方塊)
            if not place_data.get("image_url") and post_thumbnail:
                place_data["image_url"] = post_thumbnail
            
            # 🔵 終極補水方案：如果還是沒圖片，則透過搜尋引擎強行「補照片」
            if not place_data.get("image_url"):
                fallback_img = await run_in_threadpool(image_service.fetch_fallback_image, search_name)
                if fallback_img:
                    place_data["image_url"] = fallback_img
                    
            # ☁️ 上傳到 Supabase 獲得永久存取連結
            if place_data.get("image_url"):
                permanent_url = await run_in_threadpool(image_service.upload_to_supabase, place_data["image_url"])
                place_data["image_url"] = permanent_url

            return schemas.ContentPlaceInfo(
                place=schemas.PlaceBase(**place_data),
                evidence_text=p.get("evidence_text"),
                confidence_score=p.get("confidence_score", 0.0)
            )

        # 並行執行所有搜尋，同時傳入貼文封面作為備援圖
        post_thumb = scraped_data.get("preview_thumbnail_url")
        if post_thumb:
            # 提前把主封面也存入 Supabase 變成永久網址，供下方景點繼承
            post_thumb = await run_in_threadpool(image_service.upload_to_supabase, post_thumb)
            scraped_data["preview_thumbnail_url"] = post_thumb
            
        enriched_places = await asyncio.gather(*(enrich_place(p, post_thumb) for p in extracted_places))
        
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
                assoc = ContentPlaceAssociation(
                    content_id=db_content.id,
                    place_id=db_place.id,
                    evidence_text=info.evidence_text,
                    confidence_score=info.confidence_score
                )
                db.add(assoc)
        
        db.commit()
        
        # 存入 Result (需 dump 為 JSON 相容格式)
        task.result = json.loads(extraction_response.json())
        task.status = "completed"
        task.progress = 1.0
        db.commit()

    except Exception as e:
        print(f"Task Error: {e}")
        task.status = "failed"
        task.error = str(e)
        db.commit()
    finally:
        db.close()

@app.post("/api/v1/share", response_model=schemas.TaskResponse)
async def share_content(request: schemas.ShareRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """
    接收社群分享連結，啟動異步解析任務
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
async def get_task_status(task_id: str, response: Response, db: Session = Depends(get_db)):
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
async def list_contents(db: Session = Depends(get_db)):
    """
    顯示收藏庫中的內容模式 (連結模式)
    """
    from sqlalchemy.orm import joinedload
    contents = db.query(Content).options(
        joinedload(Content.place_associations).joinedload(ContentPlaceAssociation.place)
    ).filter(Content.is_collected == 1).order_by(Content.created_at.desc()).all()
    
    return contents
    
@app.get("/api/v1/library/places", response_model=List[schemas.PlaceBase])
async def list_places(db: Session = Depends(get_db)):
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

@app.post("/api/v1/analyze/place", response_model=schemas.AnalyzeResponse)
async def analyze_place(request: schemas.AnalyzeRequest, db: Session = Depends(get_db)):
    """
    使用 AI 生成地點介紹與正反點評 (包含 Cache 機制)
    """
    # 1. Check Cache
    cache_entry = db.query(AIAnalysisCache).filter(
        AIAnalysisCache.place_name == request.name,
        AIAnalysisCache.address == request.address
    ).first()
    
    # NEW: Detect and skip cache if it contains the fallback template text
    is_template = False
    if cache_entry:
        res = cache_entry.result
        desc = res.get("description", "")
        # Robust Template Detection
        template_keywords = ["備受好評", "熱門地點", "值得一訪", "附近交通可能較擁擠"]
        if any(keyword in desc for keyword in template_keywords):
            is_template = True
            print(f"♻️ [Cache Invalidation] Fallback template detected for: {request.name}. Wiping and re-generating...")
            db.delete(cache_entry)
            db.commit()
    
    if cache_entry and not is_template:
        print(f"🚀 [Cache Hit] Using existing analysis for: {request.name}")
        res = cache_entry.result
        return schemas.AnalyzeResponse(
            description=res.get("description", ""),
            pro_comment=res.get("pro_comment", ""),
            con_comment=res.get("con_comment", "")
        )
    
    # 2. Call AI (with country/city context)
    print(f"🤖 [Analyze] Calling AI for: {request.name} (country={request.country}, city={request.city})")
    result = await run_in_threadpool(
        nlp_service.generate_place_description,
        request.name,
        request.address,
        request.country,
        request.city
    )
    
    # 3. Save to Cache (Overwrite if is_template)
    if is_template:
        cache_entry.result = result
        db.add(cache_entry)
        print(f"✅ [Cache Updated] Replaced template with real AI content for: {request.name}")
    else:
        new_cache = AIAnalysisCache(
            place_name=request.name,
            address=request.address,
            result=result
        )
        db.add(new_cache)
    
    db.commit()
    
    return schemas.AnalyzeResponse(
        description=result.get("description", ""),
        pro_comment=result.get("pro_comment", ""),
        con_comment=result.get("con_comment", "")
    )

@app.post("/api/v1/analyze/screenshot", response_model=schemas.ExtractionResponse)
async def analyze_screenshot(file: UploadFile = File(...), db: Session = Depends(get_db)):
    """
    接收使用者上傳的單張截圖，透過 Gemini 1.5 Flash 辨識地點，並豐富 Google Places 資訊。
    """
    image_data = await file.read()
    
    # 0. Upload screenshot to Supabase to get a permanent URL
    screenshot_url = await run_in_threadpool(image_service.upload_bytes_to_supabase, image_data, file.content_type)
    final_source_url = screenshot_url if screenshot_url else f"screenshot_{uuid.uuid4().hex[:8]}"
    
    # 1. 使用 LLM 解析地點名稱
    extracted_places = await run_in_threadpool(nlp_service.extract_places_from_image, image_data, file.content_type)
    
    if not extracted_places:
        raise HTTPException(status_code=400, detail="無法從截圖中辨識出任何景點資訊")

    import asyncio

    async def enrich_place_for_screenshot(p):
        search_name = p.get("search_query", p.get("name", "Unknown"))
        display_name = p.get("name", "Unknown")
        inferred_country = p.get("country", "")
        
        google_place = await run_in_threadpool(places_service.search_place, f"{inferred_country} {search_name}")
        if not google_place:
            google_place = await run_in_threadpool(places_service.search_place, f"{search_name} {p.get('city', '')}")
        if not google_place:
            google_place = await run_in_threadpool(places_service.search_place, display_name)
            
        ai_fallback_data = None
        if not google_place:
            ai_fallback_data = await run_in_threadpool(nlp_service.ai_geocoding, display_name, inferred_country, p.get('city', ''))
        
        place_data = {
            "place_id": f"temp_{random.randint(1000, 9999)}",
            "name": display_name,
            "address": None,
            "latitude": 0.0,
            "longitude": 0.0,
            "category": p.get("category", "其他"),
            "google_place_id": None
        }

        if google_place:
            place_data["place_id"] = google_place.get("name", "").split("/")[-1] if "/" in google_place.get("name", "") else google_place.get("id")
            place_data["google_place_id"] = place_data["place_id"]
            place_data["address"] = google_place.get("formattedAddress", "")
            location = google_place.get("location", {})
            place_data["latitude"] = location.get("latitude", 0.0)
            place_data["longitude"] = location.get("longitude", 0.0)
            place_data["rating"] = google_place.get("rating")
            place_data["user_ratings_total"] = google_place.get("userRatingCount")
            place_data["opening_hours"] = google_place.get("regularOpeningHours")
            place_data["open_now"] = google_place.get("currentOpeningHours", {}).get("openNow")
            if "primaryType" in google_place:
                place_data["category"] = google_place["primaryType"].replace("_", " ").title()
        elif ai_fallback_data:
            place_data["address"] = ai_fallback_data.get("address")
            place_data["latitude"] = ai_fallback_data.get("latitude", 0.0)
            place_data["longitude"] = ai_fallback_data.get("longitude", 0.0)

        # 🔵 終極補水方案：如果還是沒圖片，則透過搜尋引擎強行「補照片」
        if not place_data.get("image_url"):
            fallback_img = await run_in_threadpool(image_service.fetch_fallback_image, search_name)
            if fallback_img:
                place_data["image_url"] = fallback_img
                # Upload to Supabase for permanent URL
                permanent_url = await run_in_threadpool(image_service.upload_to_supabase, place_data["image_url"])
                place_data["image_url"] = permanent_url

        return schemas.ContentPlaceInfo(
            place=schemas.PlaceBase(**place_data),
            evidence_text=p.get("evidence_text"),
            confidence_score=p.get("confidence_score", 0.0)
        )

    enriched_places = await asyncio.gather(*(enrich_place_for_screenshot(p) for p in extracted_places))

    # 封裝結果
    content_base = schemas.ContentBase(
        source_type="screenshot",
        source_url=final_source_url,
        title="來自截圖的景點分析",
        text="",
        author_name="Me",
        author_avatar_url=None,
        preview_thumbnail_url=screenshot_url,
        published_at=None
    )

    return schemas.ExtractionResponse(
        content=content_base,
        suggested_places=enriched_places
    )

# --- Curated Posts API ---

@app.get("/api/v1/curated", response_model=List[schemas.CuratedPostResponse])
async def list_curated_posts(country: Optional[str] = None, db: Session = Depends(get_db)):
    """
    獲取精選 IG 貼文列表 (首頁靈感庫)
    """
    query = db.query(CuratedPost)
    if country:
        query = query.filter(CuratedPost.country == country)
    return query.order_by(CuratedPost.created_at.desc()).all()

def auto_create_curated_post(content_obj: Content, spots_data: list, db: Session):
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
    
    if existing_post:
        print(f"🔄 [Curated] Updating existing curated post: {content_obj.title}")
        existing_post.title = content_obj.title
        # 確保使用永久連結
        existing_post.cover_image = image_service.upload_to_supabase(content_obj.preview_thumbnail_url)
        existing_post.author = content_obj.author_name
        existing_post.spots = spots_data
        existing_post.spot_count = len(spots_data)
        existing_post.country = final_country
        db.commit()
        db.refresh(existing_post)
        return existing_post
    
    print(f"🚀 [Curated] Creating new curated post: {content_obj.title}")
    new_curated = CuratedPost(
        id=str(uuid.uuid4()),
        title=content_obj.title,
        cover_image=image_service.upload_to_supabase(content_obj.preview_thumbnail_url),
        author=content_obj.author_name,
        source_url=content_obj.source_url,
        spots=spots_data,
        spot_count=len(spots_data),
        country=final_country
    )
    db.add(new_curated)
    db.commit()
    db.refresh(new_curated)
    return new_curated

@app.post("/api/v1/curated", response_model=schemas.CuratedPostResponse)
async def create_curated_post(post: schemas.CuratedPostCreate, db: Session = Depends(get_db)):
    """
    手動新增精選貼文
    """
    import uuid
    from sqlalchemy.exc import IntegrityError
    
    # Check if this source_url already exists
    existing = db.query(CuratedPost).filter(CuratedPost.source_url == post.source_url).first()
    if existing:
        # Update existing post instead of failing
        existing.title = post.title
        existing.cover_image = await run_in_threadpool(image_service.upload_to_supabase, post.cover_image)
        existing.author = post.author
        existing.spots = post.spots
        existing.spot_count = post.spot_count or len(post.spots)
        existing.country = post.country
        db.commit()
        db.refresh(existing)
        return existing
    
    # 使用 AI 偵測國家 (如果前端傳來的為空或是預設佔位符)
    final_country = post.country
    if not final_country or final_country == "" or final_country == "韓國":
        final_country = nlp_service.detect_country(post.title, "", post.spots)

    new_post = CuratedPost(
        id=str(uuid.uuid4()),
        title=post.title,
        cover_image=await run_in_threadpool(image_service.upload_to_supabase, post.cover_image),
        author=post.author,
        source_url=post.source_url,
        spots=post.spots,
        spot_count=post.spot_count or len(post.spots),
        country=final_country
    )
    try:
        db.add(new_post)
        db.commit()
        db.refresh(new_post)
        return new_post
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="此貼文已存在於推薦行程中")

@app.post("/api/v1/curated/auto", response_model=schemas.CuratedPostResponse)
async def auto_create_curated_post(request: schemas.ShareRequest, db: Session = Depends(get_db)):
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
        cover_image=await run_in_threadpool(image_service.upload_to_supabase, info.get("preview_thumbnail_url")),
        author=info.get("author_name"),
        source_url=request.url,
        spots=spots,
        spot_count=len(spots),
        country=country
    )
    db.add(new_post)
    db.commit()
    db.refresh(new_post)
    return new_post

from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, Response, UploadFile, File
from fastapi.concurrency import run_in_threadpool
from mangum import Mangum
from typing import List, Optional
import json
import random
import uuid
import os
import sys

# ─── 讓 functions/ 可以 import 上層 app/ 模組 ───────────────────────────────
# functions/ 與 app/ 同在 backend/ 底下，需要把 backend/ 加入 Python path
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

# ─── Firebase Admin SDK（Cloud Functions 環境不需要傳入憑證）────────────────
import firebase_admin
if not firebase_admin._apps:
    firebase_admin.initialize_app()   # ✅ 無參數模式：由 GCP 環境自動注入憑證
    print("✅ Firebase Admin SDK 成功啟動 (Cloud Functions 模式)")

# ─── 從上層 app/ 引入原有模組 ─────────────────────────────────────────────
from sqlalchemy.orm import Session
from app.models import schemas
from app.models.database import (
    get_db, init_db, Task, SessionLocal,
    AIAnalysisCache, CuratedPost, Content,
    Place, ContentPlaceAssociation
)
from app.services.places_service import PlacesService
from app.services.apify_service import ApifyService
from app.services.nlp_service import NLPService
from app.services.youtube_service import YouTubeService
from app.services.image_service import ImageService
from app.api import trips, collection

# ─── FastAPI App ──────────────────────────────────────────────────────────────
app = FastAPI(title="Pubo API", version="2.0.0")

app.include_router(trips.router, prefix="/api/v1", tags=["trips"])
app.include_router(collection.router, prefix="/api/v1", tags=["collection"])

# ─── 初始化服務 ───────────────────────────────────────────────────────────────
apify_service = ApifyService()
nlp_service   = NLPService()
youtube_service = YouTubeService()
places_service  = PlacesService()
image_service   = ImageService()

# ─── Startup Event ────────────────────────────────────────────────────────────
@app.on_event("startup")
def on_startup():
    init_db()

@app.get("/")
def read_root():
    return {"message": "Welcome to Pubo API (Firebase Functions)"}

# ──────────────────────────────────────────────────────────────────────────────
# 以下將原本 backend/app/main.py 的所有 endpoint 完整搬入
# ──────────────────────────────────────────────────────────────────────────────

@app.get("/api/v1/debug/places")
async def debug_places(query: str):
    """Temporary endpoint to debug Google Places failures."""
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
        import requests as req
        response = req.post(url, headers=headers, json=payload)
        return {"status_code": response.status_code, "response": response.json()}
    except Exception as e:
        return {"error": str(e)}


async def process_share_task(task_id: str, url: str):
    """非同步處理函數：爬取內容並使用 LLM 解析"""
    import asyncio
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

        scraped_data = None
        if not url.startswith("http://") and not url.startswith("https://"):
            source_type = "plain_text"
            scraped_data = {"text": url, "title": "來自純文字的匯入", "preview_thumbnail_url": None, "author_name": None, "author_avatar_url": None}
        elif "youtube.com" in url or "youtu.be" in url:
            source_type = "youtube"
            scraped_data = await run_in_threadpool(youtube_service.process_video, url)
        elif "threads.net" in url or "threads.com" in url:
            source_type = "threads"
            scraped_data = await run_in_threadpool(apify_service.scrape_threads_post, url)
        else:
            source_type = "instagram"
            scraped_data = await run_in_threadpool(apify_service.extract_instagram_post, url)

        if not scraped_data:
            task.status = "failed"
            task.error = "無法爬取該連結內容"
            db.commit()
            return

        task.progress = 0.4
        db.commit()

        extracted_places = await run_in_threadpool(nlp_service.extract_places_from_text, scraped_data["text"])
        task.progress = 0.6
        db.commit()

        async def enrich_place(p, post_thumbnail=None):
            search_name     = p.get("search_query", p.get("name", "Unknown"))
            display_name    = p.get("name", "Unknown")
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
                real_id = google_place.get("name", "").split("/")[-1] if "/" in google_place.get("name", "") else google_place.get("id")
                place_data["place_id"] = real_id
                place_data["google_place_id"] = real_id
                place_data["address"] = google_place.get("formattedAddress", "")
                location = google_place.get("location", {})
                place_data["latitude"]  = location.get("latitude", 0.0)
                place_data["longitude"] = location.get("longitude", 0.0)
                place_data["rating"] = google_place.get("rating")
                place_data["user_ratings_total"] = google_place.get("userRatingCount")
                place_data["opening_hours"] = google_place.get("regularOpeningHours")
                place_data["open_now"] = google_place.get("currentOpeningHours", {}).get("openNow")
                if "primaryType" in google_place:
                    place_data["category"] = google_place["primaryType"].replace("_", " ").title()
            elif ai_fallback_data:
                place_data["address"]   = ai_fallback_data.get("address")
                place_data["latitude"]  = ai_fallback_data.get("latitude", 0.0)
                place_data["longitude"] = ai_fallback_data.get("longitude", 0.0)

            if not place_data.get("image_url") and post_thumbnail:
                place_data["image_url"] = post_thumbnail
            if not place_data.get("image_url"):
                fallback_img = await run_in_threadpool(image_service.fetch_fallback_image, search_name)
                if fallback_img:
                    place_data["image_url"] = fallback_img
            if place_data.get("image_url"):
                permanent_url = await run_in_threadpool(image_service.upload_to_supabase, place_data["image_url"])
                place_data["image_url"] = permanent_url

            return schemas.ContentPlaceInfo(
                place=schemas.PlaceBase(**place_data),
                evidence_text=p.get("evidence_text"),
                confidence_score=p.get("confidence_score", 0.0)
            )

        post_thumb = scraped_data.get("preview_thumbnail_url")
        if post_thumb:
            post_thumb = await run_in_threadpool(image_service.upload_to_supabase, post_thumb)
            scraped_data["preview_thumbnail_url"] = post_thumb

        enriched_places = await asyncio.gather(*(enrich_place(p, post_thumb) for p in extracted_places))
        task.progress = 0.9
        db.commit()

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
        extraction_response = schemas.ExtractionResponse(content=content_base, suggested_places=enriched_places)

        db_content = db.query(Content).filter(Content.source_url == url).first()
        if not db_content:
            db_content = Content(
                source_type=source_type, source_url=url,
                title=content_base.title, text=content_base.text,
                author_name=content_base.author_name,
                author_avatar_url=content_base.author_avatar_url,
                preview_thumbnail_url=content_base.preview_thumbnail_url
            )
            db.add(db_content)
            db.commit()
            db.refresh(db_content)

        for info in enriched_places:
            p = info.place
            db_place = db.query(Place).filter(Place.place_id == p.place_id).first() if p.place_id else None
            if not db_place:
                db_place = Place(
                    place_id=p.place_id, name=p.name, address=p.address,
                    latitude=p.latitude, longitude=p.longitude,
                    category=p.category, image_url=p.image_url,
                    rating=p.rating, user_ratings_total=p.user_ratings_total,
                    opening_hours=p.opening_hours
                )
                db.add(db_place)
                db.commit()
                db.refresh(db_place)
            assoc = db.query(ContentPlaceAssociation).filter(
                ContentPlaceAssociation.content_id == db_content.id,
                ContentPlaceAssociation.place_id == db_place.id
            ).first()
            if not assoc:
                db.add(ContentPlaceAssociation(
                    content_id=db_content.id, place_id=db_place.id,
                    evidence_text=info.evidence_text, confidence_score=info.confidence_score
                ))
        db.commit()

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
    task_id = str(uuid.uuid4())
    new_task = Task(task_id=task_id, status="pending", target_url=request.url)
    db.add(new_task)
    db.commit()
    db.refresh(new_task)
    background_tasks.add_task(process_share_task, task_id, request.url)
    return schemas.TaskResponse(task_id=new_task.task_id, status=schemas.TaskStatus(new_task.status), result=None, error=None)


@app.get("/api/v1/task/{task_id}", response_model=schemas.TaskResponse)
async def get_task_status(task_id: str, response: Response, db: Session = Depends(get_db)):
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    task = db.query(Task).filter(Task.task_id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="找不到該任務")
    return schemas.TaskResponse(
        task_id=task.task_id, status=schemas.TaskStatus(task.status),
        progress=task.progress, result=task.result, error=task.error
    )


@app.get("/api/v1/library/contents", response_model=List[schemas.ContentResponse])
async def list_contents(db: Session = Depends(get_db)):
    from sqlalchemy.orm import joinedload
    contents = db.query(Content).options(
        joinedload(Content.place_associations).joinedload(ContentPlaceAssociation.place)
    ).filter(Content.is_collected == 1).order_by(Content.created_at.desc()).all()
    return contents


@app.get("/api/v1/library/places", response_model=List[schemas.PlaceBase])
async def list_places(db: Session = Depends(get_db)):
    places = db.query(Place).order_by(Place.created_at.desc()).all()
    return [schemas.PlaceBase(
        place_id=p.place_id, name=p.name, address=p.address,
        latitude=p.latitude, longitude=p.longitude, category=p.category,
        image_url=p.image_url, rating=p.rating,
        user_ratings_total=p.user_ratings_total, opening_hours=p.opening_hours
    ) for p in places]


@app.post("/api/v1/analyze/place", response_model=schemas.AnalyzeResponse)
async def analyze_place(request: schemas.AnalyzeRequest, db: Session = Depends(get_db)):
    cache_entry = db.query(AIAnalysisCache).filter(
        AIAnalysisCache.place_name == request.name,
        AIAnalysisCache.address == request.address
    ).first()
    is_template = False
    if cache_entry:
        res = cache_entry.result
        desc = res.get("description", "")
        template_keywords = ["備受好評", "熱門地點", "值得一訪", "附近交通可能較擁擠"]
        if any(k in desc for k in template_keywords):
            is_template = True
            db.delete(cache_entry)
            db.commit()
    if cache_entry and not is_template:
        res = cache_entry.result
        return schemas.AnalyzeResponse(
            description=res.get("description", ""),
            pro_comment=res.get("pro_comment", ""),
            con_comment=res.get("con_comment", "")
        )
    result = await run_in_threadpool(
        nlp_service.generate_place_description,
        request.name, request.address, request.country, request.city
    )
    if is_template:
        cache_entry.result = result
        db.add(cache_entry)
    else:
        db.add(AIAnalysisCache(place_name=request.name, address=request.address, result=result))
    db.commit()
    return schemas.AnalyzeResponse(
        description=result.get("description", ""),
        pro_comment=result.get("pro_comment", ""),
        con_comment=result.get("con_comment", "")
    )


@app.post("/api/v1/analyze/screenshot", response_model=schemas.ExtractionResponse)
async def analyze_screenshot(file: UploadFile = File(...), db: Session = Depends(get_db)):
    import asyncio
    image_data = await file.read()
    extracted_places = await run_in_threadpool(nlp_service.extract_places_from_image, image_data, file.content_type)
    if not extracted_places:
        raise HTTPException(status_code=400, detail="無法從截圖中辨識出任何景點資訊")

    async def enrich_for_screenshot(p):
        search_name     = p.get("search_query", p.get("name", "Unknown"))
        display_name    = p.get("name", "Unknown")
        inferred_country = p.get("country", "")
        google_place = await run_in_threadpool(places_service.search_place, f"{inferred_country} {search_name}")
        if not google_place:
            google_place = await run_in_threadpool(places_service.search_place, f"{search_name} {p.get('city', '')}")
        if not google_place:
            google_place = await run_in_threadpool(places_service.search_place, display_name)
        ai_fallback_data = None
        if not google_place:
            ai_fallback_data = await run_in_threadpool(nlp_service.ai_geocoding, display_name, inferred_country, p.get('city', ''))
        place_data = {"place_id": f"temp_{random.randint(1000, 9999)}", "name": display_name, "address": None, "latitude": 0.0, "longitude": 0.0, "category": p.get("category", "其他"), "google_place_id": None}
        if google_place:
            place_data["place_id"] = google_place.get("name", "").split("/")[-1] if "/" in google_place.get("name", "") else google_place.get("id")
            place_data["google_place_id"] = place_data["place_id"]
            place_data["address"] = google_place.get("formattedAddress", "")
            location = google_place.get("location", {})
            place_data["latitude"]  = location.get("latitude", 0.0)
            place_data["longitude"] = location.get("longitude", 0.0)
            place_data["rating"] = google_place.get("rating")
            place_data["user_ratings_total"] = google_place.get("userRatingCount")
            place_data["opening_hours"] = google_place.get("regularOpeningHours")
            place_data["open_now"] = google_place.get("currentOpeningHours", {}).get("openNow")
            if "primaryType" in google_place:
                place_data["category"] = google_place["primaryType"].replace("_", " ").title()
        elif ai_fallback_data:
            place_data["address"]   = ai_fallback_data.get("address")
            place_data["latitude"]  = ai_fallback_data.get("latitude", 0.0)
            place_data["longitude"] = ai_fallback_data.get("longitude", 0.0)
        fallback_img = await run_in_threadpool(image_service.fetch_fallback_image, search_name)
        if fallback_img:
            permanent_url = await run_in_threadpool(image_service.upload_to_supabase, fallback_img)
            place_data["image_url"] = permanent_url
        return schemas.ContentPlaceInfo(place=schemas.PlaceBase(**place_data), evidence_text=p.get("evidence_text"), confidence_score=p.get("confidence_score", 0.0))

    enriched_places = await asyncio.gather(*(enrich_for_screenshot(p) for p in extracted_places))
    content_base = schemas.ContentBase(
        source_type="screenshot", source_url=f"screenshot_{uuid.uuid4().hex[:8]}",
        title="來自截圖的景點分析", text="", author_name="Me",
        author_avatar_url=None, preview_thumbnail_url=None, published_at=None
    )
    return schemas.ExtractionResponse(content=content_base, suggested_places=enriched_places)


@app.get("/api/v1/curated", response_model=List[schemas.CuratedPostResponse])
async def list_curated_posts(country: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(CuratedPost)
    if country:
        query = query.filter(CuratedPost.country == country)
    return query.order_by(CuratedPost.created_at.desc()).all()


@app.post("/api/v1/curated", response_model=schemas.CuratedPostResponse)
async def create_curated_post(post: schemas.CuratedPostCreate, db: Session = Depends(get_db)):
    from sqlalchemy.exc import IntegrityError
    existing = db.query(CuratedPost).filter(CuratedPost.source_url == post.source_url).first()
    if existing:
        existing.title       = post.title
        existing.cover_image = await run_in_threadpool(image_service.upload_to_supabase, post.cover_image)
        existing.author      = post.author
        existing.spots       = post.spots
        existing.spot_count  = post.spot_count or len(post.spots)
        existing.country     = post.country
        db.commit()
        db.refresh(existing)
        return existing
    final_country = post.country
    if not final_country or final_country in ("", "韓國"):
        final_country = nlp_service.detect_country(post.title, "", post.spots)
    new_post = CuratedPost(
        id=str(uuid.uuid4()), title=post.title,
        cover_image=await run_in_threadpool(image_service.upload_to_supabase, post.cover_image),
        author=post.author, source_url=post.source_url,
        spots=post.spots, spot_count=post.spot_count or len(post.spots), country=final_country
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
async def auto_create_curated_post_endpoint(request: schemas.ShareRequest, db: Session = Depends(get_db)):
    info = await run_in_threadpool(apify_service.extract_instagram_post, request.url)
    if not info:
        raise HTTPException(status_code=404, detail="無法爬取該貼文")
    spots   = await run_in_threadpool(nlp_service.extract_places_from_text, info.get("text", ""))
    title   = info.get("title") or f"{info.get('author_name', '旅遊達人')} 的分享"
    country = await run_in_threadpool(nlp_service.detect_country, title, info.get("text", ""), spots)
    new_post = CuratedPost(
        id=str(uuid.uuid4()), title=title,
        cover_image=await run_in_threadpool(image_service.upload_to_supabase, info.get("preview_thumbnail_url")),
        author=info.get("author_name"), source_url=request.url,
        spots=spots, spot_count=len(spots), country=country
    )
    db.add(new_post)
    db.commit()
    db.refresh(new_post)
    return new_post


# ─── Mangum Handler（Firebase/AWS Lambda 入口點）────────────────────────────
handler = Mangum(app)
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.concurrency import run_in_threadpool
from typing import List
import json
import random
import uuid
from sqlalchemy.orm import Session
from .models import schemas
from .models.database import get_db, init_db, Task, SessionLocal
from .services.places_service import PlacesService
from .services.apify_service import ApifyService
from .services.nlp_service import NLPService
from .services.youtube_service import YouTubeService
from .api import trips

app = FastAPI()

app.include_router(trips.router, prefix="/api/v1", tags=["trips"])

# 初始化服務
apify_service = ApifyService()
nlp_service = NLPService()
youtube_service = YouTubeService()
places_service = PlacesService()

@app.on_event("startup")
def on_startup():
    init_db()

@app.get("/")
def read_root():
    return {"message": "Welcome to Pubo API"}

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
        db.commit()
    
        source_type = "instagram"
        print(f"TASK {task_id}: 開始處理 {url}")
        
        # 1. 爬取內容
        scraped_data = None
        if "youtube.com" in url or "youtu.be" in url:
            source_type = "youtube"
            # 使用 YouTubeService (Sync -> Threadpool)
            scraped_data = await run_in_threadpool(youtube_service.process_video, url)
        elif "threads.net" in url or "threads.com" in url:
            source_type = "threads"
            scraped_data = await run_in_threadpool(apify_service.scrape_threads_post, url)
        else:
            source_type = "instagram"
            scraped_data = await run_in_threadpool(apify_service.scrape_instagram_post, url)
            
        if scraped_data:
            print(f"🔍 [Backend] Final Scraped Text: {scraped_data.get('text', '')[:200]}...") # Log 前200字
            
        print(f"TASK {task_id}: {source_type} 爬取完成，結果: {True if scraped_data else False}")

        if not scraped_data:
            task.status = "failed"
            task.error = "無法爬取該連結內容"
            db.commit()
            return

        # 2. 使用 LLM 解析地點名稱 (Sync -> Threadpool)
        extracted_places = await run_in_threadpool(nlp_service.extract_places, scraped_data["text"])

        # 3. 使用 Google Places API 搜尋確切地點資訊 (Parallel Execution)
        import asyncio
        
        async def enrich_place(p):
            place_name = p["name"]
            # 使用 run_in_threadpool 確保同步的 search_place 不會阻塞 Event Loop
            google_place = await run_in_threadpool(places_service.search_place, place_name)
            
            place_data = {
                "place_id": f"temp_{random.randint(1000, 9999)}",
                "name": place_name,
                "address": None,
                "latitude": 0.0,
                "longitude": 0.0,
                "category": p.get("category", "其他"),
                "google_place_id": None
            }

            if google_place:
                # Use Google Place ID as the primary ID to ensure deduplication on client side
                real_id = google_place.get("name", "").split("/")[-1] if "/" in google_place.get("name", "") else google_place.get("id")
                
                place_data["place_id"] = real_id
                place_data["google_place_id"] = real_id
                place_data["name"] = google_place.get("displayName", {}).get("text", place_name)
                place_data["address"] = google_place.get("formattedAddress")
                
                location = google_place.get("location", {})
                place_data["latitude"] = location.get("latitude", 0.0)
                place_data["longitude"] = location.get("longitude", 0.0)
                
                place_data["rating"] = google_place.get("rating")
                place_data["user_ratings_total"] = google_place.get("userRatingCount")
                place_data["opening_hours"] = google_place.get("regularOpeningHours")
                place_data["open_now"] = google_place.get("currentOpeningHours", {}).get("openNow")
                
                if "primaryType" in google_place:
                    place_data["category"] = google_place["primaryType"].replace("_", " ").title()

            return schemas.ContentPlaceInfo(
                place=schemas.PlaceBase(**place_data),
                evidence_text=p.get("evidence_text"),
                confidence_score=p.get("confidence_score", 0.0)
            )

        # 並行執行所有搜尋
        enriched_places = await asyncio.gather(*(enrich_place(p) for p in extracted_places))

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
        
        # 存入 Result (需 dump 為 JSON 相容格式)
        # 由於 Pydantic model dump 需要 dict
        task.result = json.loads(extraction_response.json())
        task.status = "completed"
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
async def get_task_status(task_id: str, db: Session = Depends(get_db)):
    """
    查詢任務狀態與結果
    """
    task = db.query(Task).filter(Task.task_id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="找不到該任務")
        
    return schemas.TaskResponse(
        task_id=task.task_id,
        status=schemas.TaskStatus(task.status),
        result=task.result,
        error=task.error
    )

@app.get("/api/v1/library/contents", response_model=List[schemas.ContentResponse])
async def list_contents():
    """
    顯示收藏庫中的內容模式 (連結模式)
    """
    # TODO: 從資料庫讀取
    return []

@app.get("/api/v1/library/places", response_model=List[schemas.PlaceBase])
async def list_places():
    """
    顯示收藏庫中的地點模式 (地點模式)
    - 規則：地點需去重
    """
    # TODO: 從資料庫讀取並去重
    return []

@app.post("/api/v1/analyze/place", response_model=schemas.AnalyzeResponse)
async def analyze_place(request: schemas.AnalyzeRequest):
    """
    使用 AI 生成地點介紹
    """
    description = await run_in_threadpool(nlp_service.generate_place_description, request.name, request.address)
    return schemas.AnalyzeResponse(description=description)

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from ..models.database import get_db, Content, Place, ContentPlaceAssociation, FirestoreSession
from ..models import schemas
from datetime import datetime

router = APIRouter()

@router.get("/collection", response_model=List[schemas.ContentResponse])
def get_collection(db: FirestoreSession = Depends(get_db)):
    """
    獲取所有已收藏的內容 (連結模式)
    """
    contents = db.query(Content).filter(Content.is_collected == 1).all()
    contents.sort(key=lambda x: getattr(x, "created_at", None) or datetime.min, reverse=True)
    return contents

@router.post("/collection", response_model=schemas.ContentResponse)
def add_to_collection(request: schemas.CollectionRequest, db: FirestoreSession = Depends(get_db)):
    """
    將特定網址標記為收藏。如果網址尚未分析過，則嘗試從相關來源建立基礎紀錄。
    支援 place_ids 列表，用於精選貼文的一鍵匯入同步。
    """
    content = db.query(Content).filter(Content.source_url == request.url).first()
    
    if not content:
        # 如果是從精選貼文匯入，可能 Content 表還沒有紀錄
        # 嘗試尋找是否有對應的 CuratedPost 來獲取基本資訊
        from ..models.database import CuratedPost
        curated = db.query(CuratedPost).filter(CuratedPost.source_url == request.url).first()
        
        content = Content(
            source_url=request.url,
            source_type="instagram",
            title=curated.title if curated else "來自精選行程的收藏",
            author_name=curated.author if curated else None,
            preview_thumbnail_url=curated.cover_image if curated else None,
            is_collected=1
        )
        db.add(content)
        db.commit()
    else:
        content.is_collected = 1
        db.commit()

    # 處理景點關聯 (Sync Associations)
    if request.place_ids:
        for p_id in request.place_ids:
            # 尋找地點
            place = db.query(Place).filter(Place.place_id == p_id).first()
            if not place:
                continue
            
            # 檢查是否已存在關聯
            existing_assoc = db.query(ContentPlaceAssociation).filter(
                ContentPlaceAssociation.content_id == content.id,
                ContentPlaceAssociation.place_id == place.id
            ).first()
            
            if not existing_assoc:
                new_assoc = ContentPlaceAssociation(
                    content_id=content.id,
                    place_id=place.id,
                    confidence_score=1.0,
                    evidence_text="使用者從精選行程匯入"
                )
                db.add(new_assoc)
        
        db.commit()

    # Re-fetch with associations
    return db.query(Content).filter(Content.id == content.id).first()

@router.delete("/collection")
def remove_from_collection(url: str, db: FirestoreSession = Depends(get_db)):
    """
    移除收藏
    """
    content = db.query(Content).filter(Content.source_url == url).first()
    if content:
        content.is_collected = 0
        db.commit()
    return {"message": "Success"}

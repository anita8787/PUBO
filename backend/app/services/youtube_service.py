import re
from typing import Optional, Dict, Any
import yt_dlp

class YouTubeService:
    def __init__(self):
        pass

    def extract_video_id(self, url: str) -> Optional[str]:
        """
        從各類 YouTube URL 提取 Video ID
        支援: youtube.com/watch?v=ID, youtu.be/ID, youtube.com/shorts/ID
        """
        # 正則表達式匹配常見格式
        patterns = [
            r'(?:v=|\/)([0-9A-Za-z_-]{11}).*',
            r'(?:youtu\.be\/)([0-9A-Za-z_-]{11})',
            r'(?:shorts\/)([0-9A-Za-z_-]{11})'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        return None

    def get_video_metadata(self, url: str) -> Optional[Dict[str, Any]]:
        """
        使用 yt-dlp 獲取影片 Metadata (不下載影片)
        """
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'skip_download': True, # 重要：只抓 info，不下載
            'extract_flat': True   # 快速模式
        }
        
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                return {
                    "title": info.get("title"),
                    "description": info.get("description"),
                    "author_name": info.get("uploader"),
                    "author_avatar_url": None, # yt-dlp flat mode 可能不含 avatar，稍後可由 channel_url 推導或忽略
                    "preview_thumbnail_url": info.get("thumbnail"),
                    "published_at": info.get("upload_date"), # 格式通常為 YYYYMMDD
                    "video_id": info.get("id")
                }
        except yt_dlp.utils.DownloadError as e:
            error_msg = str(e)
            if "Private video" in error_msg:
                raise ValueError("PRIVATE_VIDEO")
            elif "Video unavailable" in error_msg:
                raise ValueError("VIDEO_UNAVAILABLE")
            else:
                print(f"yt-dlp Download Error: {e}")
                raise ValueError(f"YOUTUBE_DOWNLOAD_FAILED: {error_msg}")
        except Exception as e:
            print(f"yt-dlp Generic Error: {e}")
            raise Exception(f"YOUTUBE_PROCESSING_FAILED: {str(e)}")

    def process_video(self, url: str) -> Optional[Dict[str, Any]]:
        """
        主要入口：處理影片
        策略：
        1. 抓 Metadata (Description)
        2. 合併回傳 (僅包含影片標題與說明欄)
        """
        video_id = self.extract_video_id(url)
        if not video_id:
            print(f"Invalid YouTube URL: {url}")
            return None
            
        # 1. 取得 Metadata
        metadata = self.get_video_metadata(url)
        if not metadata:
            return None
            
        description = metadata.get("description", "")
        title = metadata.get("title", "")
        
        # 2. 組合最終文本 (僅含標題與說明欄)
        full_text = f"影片標題: {title}\n\n影片說明欄:\n{description}\n"
        
        metadata["text"] = full_text
        return metadata

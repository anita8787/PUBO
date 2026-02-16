import re
from typing import Optional, Dict, Any
from youtube_transcript_api import YouTubeTranscriptApi
from youtube_transcript_api.formatters import TextFormatter
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

    def get_transcript(self, video_id: str) -> str:
        """
        使用 yt-dlp 獲取影片逐字稿 (自動字幕)
        """
        ydl_opts = {
            'skip_download': True,
            'writesubtitles': True,
            'writeautomaticsub': True,
            'subtitleslangs': ['zh-TW', 'zh-Hant', 'zh', 'en'], # 優先順序
            'quiet': True,
            'no_warnings': True
        }

        try:
            url = f"https://www.youtube.com/watch?v={video_id}"
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                
                # 檢查自動生成的字幕
                captions = info.get('automatic_captions') or info.get('subtitles')
                if not captions:
                    return ""

                # 尋找最佳匹配語言
                target_lang = None
                for lang in ['zh-TW', 'zh-Hant', 'zh', 'zh-Hans', 'en']:
                     if lang in captions:
                         target_lang = lang
                         break
                
                if not target_lang and captions:
                    target_lang = list(captions.keys())[0]

                if target_lang:
                    # 這裡比較棘手，extract_info(download=False) 不會回傳字幕內容，只回傳 URL
                    # 我們需要手動下載該 URL 的內容
                    # 或者使用 yt-dlp 的 download_subtitle 雖然它通常寫入檔案
                    
                    # 簡單做法：直接 requests 抓取 json3 格式的字幕 URL
                    subs_list = captions[target_lang]
                    # 優先找 json3
                    json_sub = next((s for s in subs_list if s.get('ext') == 'json3'), None)
                    # 其次 vtt
                    vtt_sub = next((s for s in subs_list if s.get('ext') == 'vtt'), None)
                    
                    import requests
                    
                    if json_sub:
                        res = requests.get(json_sub['url'])
                        if res.status_code == 200:
                            data = res.json()
                            # 解析 json3: events -> segs -> utf8
                            text_segments = []
                            for event in data.get('events', []):
                                segs = event.get('segs', [])
                                if segs:
                                    text = "".join([s.get('utf8', '') for s in segs])
                                    text_segments.append(text)
                            return "\n".join(text_segments)
                            
                    if vtt_sub:
                         res = requests.get(vtt_sub['url'])
                         if res.status_code == 200:
                             # VTT 解析較麻煩，這裡先簡單回傳 raw text 或即使過濾
                             return res.text # 暫時回傳原始 VTT 文本，LLM 應該能讀懂

            return ""
            
        except Exception as e:
            print(f"Transcript Error (yt-dlp) Video {video_id}: {e}")
            return ""

    def process_video(self, url: str) -> Optional[Dict[str, Any]]:
        """
        主要入口：處理影片
        策略：
        1. 抓 Metadata (Description)
        2. 抓 Transcript (若 Description 資訊不足或作為補充)
        3. 合併回傳
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
        
        # 2. 判斷是否需要逐字稿
        # 簡單策略：如果說明欄很短 (< 100 字) 或是使用者強制要求 (這邊先默認開啟)
        # 為了資訊豐富度，我們嘗試獲取字幕作為補充
        transcript_text = self.get_transcript(video_id)
        
        # 3. 組合最終文本
        # 格式：
        # [影片標題] Title
        # [影片說明] Description
        # [影片字幕] Transcript
        
        full_text = f"影片標題: {title}\n\n影片說明欄:\n{description}\n"
        
        if transcript_text:
            # 截斷字幕以免過長 (Gemini 有 Token 限制，但 1.5 Flash 1M window 很大，暫不需擔心，但為了效能可截前 10000 字)
            full_text += f"\n影片逐字稿 (Transcript):\n{transcript_text[:15000]}" 
            
        metadata["text"] = full_text
        return metadata

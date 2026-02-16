import os
from apify_client import ApifyClient
from typing import Optional, Dict, Any
from dotenv import load_dotenv

load_dotenv()

class ApifyService:
    def __init__(self):
        self.api_token = os.getenv("APIFY_API_TOKEN")
        self.client = ApifyClient(self.api_token) if self.api_token else None

    def scrape_instagram_post(self, url: str) -> Optional[Dict[str, Any]]:
        """
        使用 Apify 官方最穩定且支援 URL 的 instagram-scraper
        """
        # 優化：清洗連結，去除多餘參數 (utm_source 等)
        clean_url = url.split("?")[0]
        if not clean_url.endswith("/"):
            clean_url += "/"
            
        print(f"DEBUG: 正在爬取清洗後的連結: {clean_url}")

        if not self.client:
            print("Warning: APIFY_API_TOKEN not set. Returning mock data.")
            return self._get_mock_data(clean_url, "instagram")

        try:
            # 使用 Apify 官方最穩定且支援 URL 的 instagram-scraper
            run_input = {
                "directUrls": [clean_url],
                "resultsLimit": 1,
            }
            
            # 使用 apify/instagram-scraper
            run = self.client.actor("apify/instagram-scraper").call(run_input=run_input)
            
            # 檢查 dataset 是否為空
            dataset_items = list(self.client.dataset(run["defaultDatasetId"]).iterate_items())
            
            if not dataset_items:
                # 若無結果，通常是私人帳號或連結錯誤
                raise ValueError("PRIVATE_ACCOUNT_OR_INVALID_LINK")

            for item in dataset_items:
                # 遍歷可能的內容欄位
                text = item.get("caption") or item.get("text") or ""
                author_name = item.get("ownerUsername") or item.get("owner", {}).get("username") or ""
                author_avatar = item.get("ownerProfilePicUrl") or item.get("owner", {}).get("profilePicUrl") or ""
                thumbnail = item.get("displayUrl") or item.get("images", [None])[0] or ""
                
                return {
                    "text": text,
                    "author_name": author_name,
                    "author_avatar_url": author_avatar,
                    "preview_thumbnail_url": thumbnail,
                    "published_at": item.get("timestamp"),
                }
        except ValueError:
            raise
        except Exception as e:
            print(f"Apify Instagram Scrape Error: {e}")
            raise Exception(f"SCAPING_FAILED: {str(e)}")
        
        return None

    def scrape_threads_post(self, url: str) -> Optional[Dict[str, Any]]:
        """
        使用 Apify Puppeteer Scraper 取得貼文資訊 (解決動態渲染問題)
        """
        # 正規化：Threads 有時會是 .com，統一轉成 .net 較符合爬蟲預期
        clean_url = url.split("?")[0].replace("threads.com", "threads.net")
        print(f"DEBUG: 正在爬取正規化後的 Threads 連結: {clean_url}")

        if not self.client:
            return self._get_mock_data(clean_url, "threads")
            
        try:
            # 使用 apify/puppeteer-scraper
            run_input = {
                "startUrls": [{"url": clean_url}],
                "pageFunction": """async function pageFunction(context) {
                    const { page, request, log } = context;
                    const title = await page.title();
                    // 嘗試抓取主要內容 (根據 Threads 的 HTML 結構)
                    // 這裡先簡單抓取整個 body text，讓 LLM 去處理雜訊
                    // 但為了圖片，我們需要嘗試抓 meta tags
                    
                    const text = await page.evaluate(() => document.body.innerText);
                    
                    const ogTitle = await page.evaluate(() => {
                        const el = document.querySelector('meta[property="og:title"]');
                        return el ? el.content : "";
                    });
                    
                    const ogImage = await page.evaluate(() => {
                        const el = document.querySelector('meta[property="og:image"]');
                        return el ? el.content : "";
                    });
                    
                    const ogDescription = await page.evaluate(() => {
                        const el = document.querySelector('meta[property="og:description"]');
                        return el ? el.content : "";
                    });

                    return { 
                        title, 
                        text,
                        ogTitle,
                        ogImage,
                        ogDescription
                    };
                }"""
            }
            
            run = self.client.actor("apify/puppeteer-scraper").call(run_input=run_input)
            dataset = self.client.dataset(run["defaultDatasetId"])
            items = list(dataset.iterate_items())
            
            if not items:
                print("DEBUG: Apify dataset is empty.")
                raise ValueError("THREADS_POST_NOT_FOUND")

            item = items[0]
            
            # 從 Puppeteer 結果組裝
            # text 通常包含很多雜訊，但 LLM 很強，給他全部就好
            full_text = item.get("text", "")
            
            # 嘗試從 og tags 提取 metadata
            author_name = item.get("ogTitle", "").split("(@")[0].strip() # Example: "User (@username) on Threads"
            if "on Threads" in author_name:
                author_name = author_name.replace(" on Threads", "")
                
            thumbnail = item.get("ogImage", "")
            
            result = {
                "text": full_text[:4000], # 限制長度避免 Token 爆炸，4000字對貼文夠用了
                "author_name": author_name,
                "author_avatar_url": "", # Puppeteer 很難精準抓到 Avatar，暫時留空或用 ogImage
                "preview_thumbnail_url": thumbnail,
                "published_at": None,
            }
            print(f"DEBUG: Extraction Result: {result}")
            return result

        except ValueError:
            raise
        except Exception as e:
            print(f"Apify Threads Scrape Error: {e}")
            raise Exception(f"SCRAPING_FAILED: {str(e)}")
                
            raise ValueError("THREADS_DATAproblem_PARSING_FAILED")

        except ValueError:
            raise
        except Exception as e:
            print(f"Apify Threads Scrape Error: {e}")
            raise Exception(f"SCRAPING_FAILED: {str(e)}")

    def _get_mock_data(self, url: str, source_type: str) -> Dict[str, Any]:
        return {
            "text": f"這是一則來自 {source_type} 的測試貼文內容，裡面提到台北101與鼎泰豐。",
            "author_name": "MockUser",
            "author_avatar_url": "https://example.com/avatar.jpg",
            "preview_thumbnail_url": "https://example.com/thumb.jpg",
            "published_at": None,
        }

import yt_dlp
import json
import requests
import sys

video_id = "GrxSHUrQfhY"
print(f"Testing subs for {video_id}...")

ydl_opts = {
    'skip_download': True,
    'writesubtitles': True,
    'writeautomaticsub': True,
    'subtitleslangs': ['zh-TW', 'zh-Hant', 'zh', 'en'],
    'quiet': True,
    'no_warnings': True
}

try:
    url = f"https://www.youtube.com/watch?v={video_id}"
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        print("Extracting info...")
        info = ydl.extract_info(url, download=False)
        
        # Check manual subs
        print(f"Manual Subs keys: {list(info.get('subtitles', {}).keys())}")
        # Check auto subs
        print(f"Auto Subs keys: {list(info.get('automatic_captions', {}).keys())}")
        
        captions = info.get('automatic_captions') or info.get('subtitles')
        if not captions:
            print("No captions found.")
            sys.exit(0)

        # Logic from youtube_service.py
        target_lang = None
        for lang in ['zh-TW', 'zh-Hant', 'zh', 'zh-Hans', 'en']:
                if lang in captions:
                    target_lang = lang
                    break
        
        if not target_lang and captions:
            target_lang = list(captions.keys())[0]
            
        print(f"Target Lang: {target_lang}")
        
        if target_lang:
            subs_list = captions[target_lang]
            json_sub = next((s for s in subs_list if s.get('ext') == 'json3'), None)
            vtt_sub = next((s for s in subs_list if s.get('ext') == 'vtt'), None)
            
            print(f"JSON3 URL: {json_sub['url'] if json_sub else 'None'}")
            print(f"VTT URL: {vtt_sub['url'] if vtt_sub else 'None'}")
            
            if json_sub:
                res = requests.get(json_sub['url'])
                print(f"Fetch Status: {res.status_code}")
                if res.status_code == 200:
                    data = res.json()
                    text_len = 0
                    snippet = ""
                    for event in data.get('events', []):
                        segs = event.get('segs', [])
                        if segs:
                            text = "".join([s.get('utf8', '') for s in segs])
                            if len(snippet) < 100: snippet += text
                            text_len += len(text)
                    print(f"Extracted Character Count: {text_len}")
                    print(f"Snippet: {snippet}")

except Exception as e:
    print(f"Error: {e}")

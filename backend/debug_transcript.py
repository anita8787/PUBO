from youtube_transcript_api import YouTubeTranscriptApi
import sys
import os

# Add current directory to path just in case
sys.path.insert(0, os.getcwd())

print(f"Python: {sys.executable}")
print(f"YouTubeTranscriptApi: {YouTubeTranscriptApi}")
try:
    print(f"Dir: {dir(YouTubeTranscriptApi)}")
except:
    pass

video_id = "GrxSHUrQfhY" 
print(f"Attempting list_transcripts for {video_id}...")

try:
    transcript_list = YouTubeTranscriptApi.list_transcripts(video_id)
    print("Success! Transcripts found:")
    for t in transcript_list:
        print(f"- {t.language} ({t.language_code}) Generated: {t.is_generated}")
        
    # Try fetching one
    transcript = transcript_list.find_transcript(['zh-TW', 'zh-Hant', 'zh', 'en'])
    result = transcript.fetch()
    print(f"Fetched {len(result)} segments.")
    snippet = " ".join([x['text'] for x in result[:5]])
    print(f"Snippet: {snippet}")
    
except Exception as e:
    print(f"Error: {e}")

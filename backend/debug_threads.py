from app.services.apify_service import ApifyService
import json
import sys

# Mock URL for testing (User can provide a real one if this fails)
# Using a known public Threads post if possible, or just a placeholder to test the scraper
TEST_URL = "https://www.threads.net/@charlie__0801/post/DN213AAUvtf" 

print(f"Testing Threads Scraper with URL: {TEST_URL}")

service = ApifyService()

if not service.client:
    print("Error: APIFY_API_TOKEN not found in environment.")
    sys.exit(1)

try:
    print("Calling Apify (apify/social-media-scraper)...")
    
    # Try using the generic Social Media Scraper
    run_input = {
        "startUrls": [{"url": TEST_URL}],
        "maxDepth": 1
    }
    
    from apify_client import ApifyClient
    import os
    
    client = ApifyClient(os.getenv("APIFY_API_TOKEN"))
    
    # Switch to apify/social-media-scraper - which might just be a wrapper but worth a try
    # Actually, let's try 'apify/website-content-crawler' as a fallback to just get HTML text
    # Or 'apify/puppeteer-scraper' to render the page
    # Let's try 'apify/puppeteer-scraper' to see if we can just grab the page content
    
    run = client.actor("apify/puppeteer-scraper").call(run_input={
        "startUrls": [{"url": TEST_URL}],
        "pageFunction": """async function pageFunction(context) {
            const { page, request, log } = context;
            const title = await page.title();
            const text = await page.evaluate(() => document.body.innerText);
            return { title, text };
        }"""
    })
    
    if run:
        print(f"Run Status: {run.get('status')}")
        dataset = client.dataset(run["defaultDatasetId"])
        items = list(dataset.iterate_items())
        print(f"\n🔍 Raw Items Found: {len(items)}")
        print(json.dumps(items, indent=2, ensure_ascii=False))
    else:
        print("Run failed to start.")
        
    # Also print the raw item for debugging structure
    print("\n🔍 Raw Item Inspection:")
    # We need to access the client to run raw query again or modify service to return raw
    # For now, let's just use the service run method but print the raw item in the loop if possible
    # Actually, I'll just modify the service temporarily or add a method to dump raw
    # Or I can just write a raw script using ApifyClient directly like in the service
    
    from apify_client import ApifyClient
    import os
    
    client = ApifyClient(os.getenv("APIFY_API_TOKEN"))
    run_input = {"startUrls": [{"url": TEST_URL}]}
    run = client.actor("logical_scrapers/threads-post-scraper").call(run_input=run_input)
    dataset = client.dataset(run["defaultDatasetId"])
    items = list(dataset.iterate_items())
    print(json.dumps(items, indent=2, ensure_ascii=False))

except Exception as e:
    print(f"\n❌ Extraction Error: {e}")

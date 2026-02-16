import os
import asyncio
from app.services.places_service import PlacesService
from dotenv import load_dotenv

# Load env vars
load_dotenv()

async def test_places():
    api_key = os.getenv("GOOGLE_PLACES_API_KEY")
    if not api_key or "your_google_places_api_key_here" in api_key:
        print("❌ Error: GOOGLE_PLACES_API_KEY is not set in .env file!")
        print("Please edit backend/.env and add your key.")
        return

    service = PlacesService()
    
    # 1. Test Search
    query = "弘大"
    print(f"\n🔍 Searching for '{query}'...")
    place = service.search_place(query)
    
    if place:
        print(f"✅ Found: {place.get('displayName', {}).get('text')} ({place.get('name')})")
        print(f"   Address: {place.get('formattedAddress')}")
        
        # 2. Test Details
        place_id = place.get("name").split("/")[-1]
        print(f"\nℹ️ Getting details for ID: {place_id}...")
        details = service.get_place_details(place_id)
        
        if details:
            print("✅ Details fetched successfully!")
            print(f"   Rating: {details.get('rating')}")
            print(f"   Opening Hours: {details.get('currentOpeningHours', {}).get('openNow', 'Unknown')}")
        else:
            print("❌ Failed to get details.")
    else:
        print("❌ Place not found.")

if __name__ == "__main__":
    asyncio.run(test_places())

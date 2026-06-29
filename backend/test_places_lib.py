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
        place_id = place.get("id") or (place.get("name", "").split("/")[-1] if "/" in place.get("name", "") else place.get("name"))
        print(f"✅ Found Place ID from search: {place_id} ({place.get('name')})")
        # Under Option B Essentials SKU, displayName and formattedAddress should not be in the search result:
        print(f"   DisplayName in Search (should be None): {place.get('displayName')}")
        print(f"   Address in Search (should be None): {place.get('formattedAddress')}")
        
        # 2. Test Details
        print(f"\nℹ️ Getting details for ID: {place_id}...")
        details = service.get_place_details(place_id)
        
        if details:
            print("✅ Details fetched successfully!")
            print(f"   Official Name (displayName): {details.get('displayName', {}).get('text')}")
            print(f"   Formatted Address: {details.get('formattedAddress')}")
            print(f"   Location: {details.get('location')}")
            # The following should be None because we removed them from the FieldMask to save cost
            print(f"   Rating (should be None): {details.get('rating')}")
            print(f"   Opening Hours (should be None): {details.get('currentOpeningHours')}")
        else:
            print("❌ Failed to get details.")
    else:
        print("❌ Place not found.")

if __name__ == "__main__":
    asyncio.run(test_places())

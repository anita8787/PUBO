import os
import requests
import json
from typing import Optional, Dict, Any, List

class PlacesService:
    def __init__(self):
        self.api_key = os.getenv("GOOGLE_PLACES_API_KEY")
        self.base_url = "https://places.googleapis.com/v1"

    def search_place(self, query: str) -> Optional[Dict[str, Any]]:
        """
        Search for a place using Text Search (New) API.
        Returns the first result with basic details.
        """
        if not self.api_key:
            print("Warning: GOOGLE_PLACES_API_KEY not set.")
            return None

        url = f"{self.base_url}/places:searchText"
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.api_key,
            # FieldMask specifices which fields to return to save cost/latency
            "X-Goog-FieldMask": "places.name,places.id,places.formattedAddress,places.location,places.types,places.rating,places.userRatingCount,places.displayName,places.primaryType,places.currentOpeningHours,places.regularOpeningHours"
        }
        payload = {
            "textQuery": query,
            "maxResultCount": 1,
            "languageCode": "zh-TW"
        }

        try:
            response = requests.post(url, headers=headers, json=payload)
            response.raise_for_status()
            data = response.json()
            
            if "places" in data and len(data["places"]) > 0:
                return data["places"][0]
            return None

        except Exception as e:
            print(f"Error searching place '{query}': {e}")
            return None

    def get_place_details(self, place_id: str) -> Optional[Dict[str, Any]]:
        """
        Get details for a specific place.
        """
        if not self.api_key:
            return None
            
        # For New Places API, place_id is part of the URL path: places/{placeId}
        # But wait, looking at docs, it's usually just GET /v1/places/{placeId}
        # Ensure place_id doesn't already have 'places/' prefix if passed from search result
        
        clean_place_id = place_id
        if "places/" in place_id:
             clean_place_id = place_id.split("places/")[1]

        url = f"{self.base_url}/places/{clean_place_id}"
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.api_key,
            "X-Goog-FieldMask": "id,displayName,formattedAddress,location,currentOpeningHours,regularOpeningHours,types,primaryType,rating,userRatingCount,priceLevel,websiteUri"
        }

        try:
            params = {"languageCode": "zh-TW"}
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Error getting details for place '{place_id}': {e}")
            return None

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
            # Update to Text Search (Advanced) to fetch all required fields in one call to save costs.
            "X-Goog-FieldMask": "places.id,places.name,places.displayName,places.formattedAddress,places.location,places.primaryType"
        }
        payload = {
            "textQuery": query,
            "maxResultCount": 1,
            "languageCode": "zh-TW"
        }

        try:
            response = requests.post(url, headers=headers, json=payload, timeout=10.0)
            response.raise_for_status()
            data = response.json()
            
            if "places" in data and len(data["places"]) > 0:
                return data["places"][0]
            return None

        except Exception as e:
            print(f"Error searching place '{query}': {e}")
            return None



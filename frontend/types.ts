
export interface Trip {
  id: string;
  title: string;
  date: string;
  coverImage: string;
  spots: number;
  color: 'yellow' | 'orange' | 'red' | 'blue';
}

export interface ItinerarySpot {
  id: string;
  time: string; // Used for starting time or time window "11:00 - 12:00"
  name: string;
  duration: string; 
  category: 'spot' | 'food' | 'transport';
  image: string;
  subLabel?: string; 
  notes?: string[]; 
  travelToNext?: { 
    time: string;
    distance: string;
    type: 'walk' | 'train' | 'car';
  };
}

export interface ItineraryDay {
  dayLabel: string; 
  date: string;     
  weekday: string;  
  title?: string;   
  spots: ItinerarySpot[];
}

export interface Post {
  id: string;
  author: string;
  avatar: string;
  content: string;
  image: string;
  platform: 'instagram' | 'youtube' | 'threads';
  tags: string[];
}

export interface SavedItem {
  id: string;
  title: string;
  location: string;
  category: 'food' | 'spot' | 'stay';
  imageUrl: string;
  originalLink?: string;
  platform?: 'instagram' | 'threads' | 'youtube';
}

export enum Tab {
  MAP = 'MAP',
  ITINERARY = 'ITINERARY',
  HOME = 'HOME',
  SEARCH = 'SEARCH',
  PROFILE = 'PROFILE'
}


import React, { useState } from 'react';
import { MapPin, Clock, Star, X, Utensils, Navigation as NavigationIcon, ChevronLeft } from 'lucide-react';

interface MapViewProps {
  onBack?: () => void;
}

interface Place {
  id: string;
  name: string;
  rating: number;
  category: string;
  time: string;
  address: string;
  image: string;
  lat: number;
  lng: number;
}

const mockPlaces: Place[] = [
  {
    id: '1',
    name: '契茶小豆',
    rating: 4.3,
    category: '餐廳',
    time: '11:00am - 17:00pm',
    address: '台北市士林區德惠街49號',
    image: 'https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?q=80&w=400&auto=format&fit=crop',
    lat: 40,
    lng: 40
  },
  {
    id: '2',
    name: '豪德寺',
    rating: 4.8,
    category: '景點',
    time: '09:00am - 18:00pm',
    address: '東京都世田谷区豪徳寺',
    image: 'https://images.unsplash.com/photo-1570459027562-4a916cc6113f?q=80&w=400&auto=format&fit=crop',
    lat: 60,
    lng: 60
  }
];

const MapView: React.FC<MapViewProps> = ({ onBack }) => {
  const [selectedPlace, setSelectedPlace] = useState<Place | null>(null);

  return (
    <div className="absolute inset-0 bg-white z-0 flex flex-col overflow-hidden">
      {/* Map Background Placeholder */}
      <div className="absolute inset-0 z-0">
        <img 
          src="https://lh3.googleusercontent.com/d/1cKI5B7O59vYFhtftmMjCz3bjnaWp-4E3" 
          className="w-full h-full object-cover opacity-60 grayscale" 
          alt="Map" 
        />
        
        {/* Connection Path (SVG) */}
        <svg className="absolute inset-0 w-full h-full pointer-events-none">
          <path 
            d="M 180 400 L 220 280" 
            stroke="#E84011" 
            strokeWidth="3" 
            fill="none"
            strokeDasharray="0"
          />
        </svg>

        {/* Current Direction Arrow */}
        <div className="absolute top-[400px] left-[180px] -translate-x-1/2 -translate-y-1/2">
           <div className="w-12 h-12 bg-pubo-red/20 rounded-full flex items-center justify-center relative">
              <div className="w-8 h-8 bg-pubo-red rounded-full flex items-center justify-center border-2 border-white shadow-lg transform -rotate-45">
                 <NavigationIcon size={18} fill="white" className="text-white" />
              </div>
           </div>
        </div>

        {/* Markers */}
        {mockPlaces.map((place) => (
          <button 
            key={place.id}
            onClick={() => setSelectedPlace(place)}
            className={`absolute transition-transform active:scale-90 ${place.id === '1' ? 'top-[280px] left-[220px]' : 'top-[150px] left-[300px]'} -translate-x-1/2 -translate-y-1/2`}
          >
            <div className="relative">
              <div className="w-12 h-12 bg-pubo-yellow rounded-full flex items-center justify-center border-2 border-white shadow-lg">
                 <Utensils size={20} className="text-white" />
              </div>
              {/* Marker Tail */}
              <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-4 h-4 bg-pubo-yellow rotate-45 border-r-2 border-b-2 border-white -z-10" />
            </div>
          </button>
        ))}

        {/* Simple grey dots for other spots */}
        <div className="absolute top-[500px] left-[250px] w-4 h-4 bg-gray-300 rounded-full border-2 border-white shadow-sm" />
        <div className="absolute top-[350px] left-[320px] w-4 h-4 bg-gray-300 rounded-full border-2 border-white shadow-sm" />
        <div className="absolute top-[200px] left-[100px] w-4 h-4 bg-gray-300 rounded-full border-2 border-white shadow-sm" />
      </div>

      {/* Floating Header UI */}
      <div className="absolute top-12 left-0 right-0 px-6 flex justify-between items-center z-20">
          <button 
            onClick={onBack}
            className="w-10 h-10 bg-white border-2 border-black rounded-full flex items-center justify-center shadow-retro-sm active:translate-y-0.5 active:shadow-none transition-all"
          >
            <ChevronLeft size={24} className="text-black" />
          </button>
      </div>

      {/* Bottom Detail Card - Full width and bottom aligned */}
      {selectedPlace && (
        <div 
          className="absolute inset-x-0 bottom-0 z-30 animate-in slide-in-from-bottom duration-500 ease-[cubic-bezier(0.32,0.72,0,1)]"
          onClick={(e) => e.stopPropagation()}
        >
          <div className="bg-white border-t-2 border-pubo-orange rounded-t-[2.5rem] p-6 pb-14 shadow-[0_-10px_40px_rgba(0,0,0,0.1)] relative overflow-hidden flex gap-4 w-full">
             {/* Image Area */}
             <div className="w-28 h-28 rounded-2xl overflow-hidden shrink-0 border border-gray-100 shadow-sm">
                <img src={selectedPlace.image} className="w-full h-full object-cover" />
             </div>

             {/* Content Area */}
             <div className="flex-1 min-w-0 py-1">
                <div className="flex justify-between items-start">
                  <h3 className="text-2xl font-black text-pubo-navy truncate">{selectedPlace.name}</h3>
                  <button onClick={() => setSelectedPlace(null)} className="text-gray-300 hover:text-gray-500 transition-colors">
                    <X size={24} strokeWidth={2.5} />
                  </button>
                </div>
                
                <div className="flex items-center gap-2 mt-2">
                  <div className="flex items-center gap-1 bg-[#FFF5E9] px-2 py-0.5 rounded text-[11px] font-black text-pubo-orange">
                    <span>{selectedPlace.rating}分</span>
                    <Star size={12} fill="#E84011" />
                  </div>
                  <span className="text-[11px] font-bold text-gray-400 bg-gray-100 px-2 py-0.5 rounded uppercase">{selectedPlace.category}</span>
                </div>

                <div className="mt-4 space-y-2">
                  <div className="flex items-center gap-2 text-gray-400">
                    <Clock size={16} strokeWidth={2.5} />
                    <span className="text-xs font-bold">{selectedPlace.time}</span>
                  </div>
                  <div className="flex items-center gap-2 text-gray-400">
                    <MapPin size={16} strokeWidth={2.5} className="text-pubo-blue" />
                    <span className="text-xs font-bold truncate">{selectedPlace.address}</span>
                  </div>
                </div>
             </div>

             {/* Drag Handle Top Overlay */}
             <div className="absolute top-3 left-1/2 -translate-x-1/2 w-12 h-1.5 bg-gray-100 rounded-full" />
          </div>
        </div>
      )}
      
      {/* Background Dim for active card */}
      {selectedPlace && (
        <div 
          className="absolute inset-0 bg-black/10 z-10 animate-in fade-in duration-300"
          onClick={() => setSelectedPlace(null)}
        />
      )}
    </div>
  );
};

export default MapView;

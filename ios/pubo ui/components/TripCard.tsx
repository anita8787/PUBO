
import React from 'react';
import { Trip } from '../types';
import { Share, MapPin } from 'lucide-react';

const TripCard: React.FC<{ trip: Trip }> = ({ trip }) => {
  // 根據 trip.color 映射對應的背景顏色
  const getBgColor = (color: string) => {
    switch (color) {
      case 'yellow': return 'bg-pubo-yellow';
      case 'orange': return 'bg-pubo-orange';
      case 'red': return 'bg-pubo-red';
      case 'blue': return 'bg-pubo-blue';
      default: return 'bg-pubo-yellow';
    }
  };

  return (
    <div className={`w-full ${getBgColor(trip.color)} border-2 border-black rounded-[2rem] p-6 shadow-retro mb-5 relative overflow-hidden group active:translate-y-1 active:shadow-none transition-all`}>
      
      {/* Top Handle Decoration */}
      <div className="absolute top-3 left-1/2 -translate-x-1/2 w-12 h-1 bg-black/10 rounded-full" />

      <div className="flex justify-between items-start mt-2">
         <div>
            <h3 className="text-3xl font-black text-white mb-2 tracking-tight uppercase">{trip.title}</h3>
            <div className="flex flex-col gap-1">
               <p className="text-white/80 font-bold text-[12px]">{trip.date}</p>
               <div className="flex items-center gap-1.5">
                  <MapPin size={10} className="text-white/60 fill-current" />
                  <span className="text-white/60 font-black text-[10px] uppercase">{trip.spots} 個景點</span>
               </div>
            </div>
         </div>

         <div className="flex gap-2">
            <button className="w-10 h-10 bg-white border-2 border-black rounded-full flex items-center justify-center shadow-retro-sm active:translate-y-0.5 active:shadow-none transition-all">
                <Share size={18} className="text-black" />
            </button>
         </div>
      </div>
      
      <div className="h-4" /> 
    </div>
  );
};

export default TripCard;

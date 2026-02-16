import React, { useState, useRef } from 'react';
import { Share2, Download, ChevronLeft, MapPin } from 'lucide-react';
import { Trip, ItineraryDay } from '../types';

interface LongImagePreviewProps {
  trip: Trip;
  itineraryDays: ItineraryDay[];
  onClose: () => void;
}

type PreviewTab = 'PLAN' | 'ROUTE' | 'LUGGAGE';

const LongImagePreview: React.FC<LongImagePreviewProps> = ({ trip, itineraryDays, onClose }) => {
  const [activeTab, setActiveTab] = useState<PreviewTab>('PLAN');
  const [cardScrollTop, setCardScrollTop] = useState(0);
  const scrollContainerRef = useRef<HTMLDivElement>(null);

  const handleHorizontalScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const scrollLeft = e.currentTarget.scrollLeft;
    const width = e.currentTarget.clientWidth;
    const index = Math.round(scrollLeft / width);
    
    if (index === 0) setActiveTab('PLAN');
    else if (index === 1) setActiveTab('ROUTE');
    else if (index === 2) setActiveTab('LUGGAGE');
  };

  const scrollToTab = (tab: PreviewTab) => {
    if (!scrollContainerRef.current) return;
    const width = scrollContainerRef.current.clientWidth;
    let targetX = 0;
    if (tab === 'ROUTE') targetX = width;
    if (tab === 'LUGGAGE') targetX = width * 2;
    
    scrollContainerRef.current.scrollTo({ left: targetX, behavior: 'smooth' });
  };

  const renderCheckeredHeader = () => (
    <div className="w-full h-10 flex flex-wrap shrink-0">
      {Array.from({ length: 24 }).map((_, i) => (
        <div 
          key={i} 
          className={`w-[8.33%] h-5 ${
            (Math.floor(i / 12) + (i % 12)) % 2 === 0 ? 'bg-[#023B7E]' : 'bg-[#FFC849]'
          }`}
        />
      ))}
      <div className="absolute top-3 left-1/2 -translate-x-1/2 w-6 h-6 bg-white border-2 border-black rounded-full flex items-center justify-center">
        <div className="w-3 h-0.5 bg-gray-200 rounded-full" />
      </div>
    </div>
  );

  const renderCardFrame = (children: React.ReactNode) => {
    // Fade out white gradient when user scrolls more than 20px
    const gradientOpacity = cardScrollTop > 20 ? 0 : 1;

    return (
      <div className="bg-[#FDFAEE] border-2 border-black rounded-[2.5rem] overflow-hidden shadow-retro-sm relative w-[260px] h-[520px] mx-auto flex flex-col">
        {renderCheckeredHeader()}
        
        <div 
          onScroll={(e) => setCardScrollTop(e.currentTarget.scrollTop)}
          className="flex-1 overflow-y-auto no-scrollbar relative flex flex-col px-5 pt-8"
        >
          {/* Title Section - OUTSIDE the red border box */}
          <div className="text-center mb-6 shrink-0">
            <h2 className="text-2xl font-black text-[#E84011] mb-2">{trip.title}7日遊</h2>
            <div className="inline-block px-3 py-1 border-[1.5px] border-[#023B7E] bg-white rounded-full">
              <span className="text-[#023B7E] font-black text-[10px]">7天6夜</span>
            </div>
          </div>

          {/* Itinerary content - Wrapped in red border box */}
          <div className="bg-white border-[2px] border-[#E84011] rounded-[1.8rem] flex flex-col mb-16 h-fit p-5">
            {children}
            {/* Safe bottom spacer inside border */}
            <div className="h-10" />
          </div>
        </div>

        {/* Fading pure white gradient at the bottom - only visible at top of scroll */}
        <div 
          className="absolute bottom-0 left-0 right-0 h-28 bg-gradient-to-t from-white via-white/80 to-transparent pointer-events-none z-10 transition-opacity duration-500 ease-in-out"
          style={{ opacity: gradientOpacity }}
        />
      </div>
    );
  };

  const renderPlan = () => (
    <div className="space-y-6">
      {itineraryDays.map((day, idx) => (
        <div key={idx} className="relative">
          <div className="flex items-center justify-between mb-2">
            <div className="px-2 py-0.5 bg-white border border-[#E84011] rounded-full">
              <span className="text-[#E84011] text-[9px] font-black">第{['一','二','三','四','五','六','七'][idx]}天</span>
            </div>
            <div className="flex items-center gap-1">
              <MapPin size={9} className="text-[#E84011] fill-current" />
              <span className="text-[9px] font-black text-gray-400">{day.spots.length}個行程</span>
            </div>
          </div>
          <div className="pl-3 space-y-1.5 border-l border-dashed border-gray-200 ml-5">
            {day.spots.length > 0 ? day.spots.map((spot, sIdx) => (
              <p key={sIdx} className="text-[11px] font-black text-pubo-navy leading-tight">{spot.name}</p>
            )) : <p className="text-[9px] font-bold text-gray-300">尚未安排行程</p>}
          </div>
        </div>
      ))}
    </div>
  );

  const renderRoute = () => (
    <div className="relative w-full aspect-[3/5] rounded-xl overflow-hidden border border-gray-100 mb-4">
      <img 
        src="https://lh3.googleusercontent.com/d/1cKI5B7O59vYFhtftmMjCz3bjnaWp-4E3" 
        className="w-full h-full object-cover" 
        alt="Route Map" 
      />
      <div className="absolute inset-0">
        <div className="absolute top-1/4 left-1/4 w-6 h-6 bg-[#E84011] border-2 border-white rounded-full flex items-center justify-center text-white text-[10px] font-black shadow-lg">1</div>
        <div className="absolute top-1/3 right-1/4 w-6 h-6 bg-[#E84011] border-2 border-white rounded-full flex items-center justify-center text-white text-[10px] font-black shadow-lg">2</div>
      </div>
    </div>
  );

  const renderLuggage = () => (
    <div className="space-y-3">
      <h3 className="font-black text-xs text-pubo-navy mb-3">必備物品</h3>
      {['護照','日幣現金','行動電源','充電線','日本網卡','換洗衣物','藥品'].map((item, i) => (
        <div key={i} className="flex items-center gap-2 py-1.5 border-b border-gray-50">
          <div className="w-4 h-4 border border-gray-200 rounded shrink-0" />
          <span className="text-xs font-bold text-gray-600">{item}</span>
        </div>
      ))}
    </div>
  );

  return (
    <div className="fixed inset-0 z-[100] bg-pubo-bg flex flex-col animate-in fade-in duration-300 overflow-hidden">
      {/* Status Bar */}
      <div className="h-10 flex items-center justify-center px-6 shrink-0 bg-transparent">
        <span className="text-[11px] font-black">4:19</span>
        <div className="mx-auto w-20 h-5 bg-black rounded-full" />
        <div className="flex gap-1">
          <div className="w-3.5 h-1.5 bg-black rounded-sm" />
          <div className="w-3.5 h-1.5 bg-black rounded-sm" />
        </div>
      </div>

      {/* Navigation Tabs - Underline made thinner (1.5px) and shorter (w-4) */}
      <div className="px-6 py-4 flex items-center shrink-0 bg-transparent">
        <button onClick={onClose} className="w-8 h-8 rounded-full border-2 border-black flex items-center justify-center shadow-retro-sm bg-white active:translate-y-0.5">
          <ChevronLeft size={20} />
        </button>
        <div className="flex-1 flex justify-end gap-4 pl-4">
          {[
            { id: 'PLAN', label: '行程計畫' },
            { id: 'ROUTE', label: '行程路線' },
            { id: 'LUGGAGE', label: '行李清單' }
          ].map((tab) => (
            <button 
              key={tab.id}
              onClick={() => scrollToTab(tab.id as PreviewTab)}
              className={`relative py-1 text-lg font-black transition-colors whitespace-nowrap ${activeTab === tab.id ? 'text-[#E84011]' : 'text-gray-300'}`}
            >
              {tab.label}
              {activeTab === tab.id && (
                <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-4 h-[1.5px] bg-[#E84011] rounded-full" />
              )}
            </button>
          ))}
        </div>
      </div>

      {/* Main Preview Swipe Container */}
      <div 
        ref={scrollContainerRef}
        onScroll={handleHorizontalScroll}
        className="flex-1 overflow-x-auto snap-x snap-mandatory no-scrollbar flex items-start pt-4"
      >
        <div className="min-w-full snap-center px-6 flex justify-center">
          {renderCardFrame(renderPlan())}
        </div>
        <div className="min-w-full snap-center px-6 flex justify-center">
          {renderCardFrame(renderRoute())}
        </div>
        <div className="min-w-full snap-center px-6 flex justify-center">
          {renderCardFrame(renderLuggage())}
        </div>
      </div>

      {/* Pagination Progress Bar - Placed below card */}
      <div className="w-full flex justify-center py-3 z-20">
        <div className="flex gap-2.5">
          <div className={`transition-all duration-500 h-1.5 rounded-full ${activeTab === 'PLAN' ? 'w-5 bg-[#FFC849]' : 'w-1.5 bg-gray-200'}`} />
          <div className={`transition-all duration-500 h-1.5 rounded-full ${activeTab === 'ROUTE' ? 'w-5 bg-[#FFC849]' : 'w-1.5 bg-gray-200'}`} />
          <div className={`transition-all duration-500 h-1.5 rounded-full ${activeTab === 'LUGGAGE' ? 'w-5 bg-[#FFC849]' : 'w-1.5 bg-gray-200'}`} />
        </div>
      </div>

      {/* Action Buttons - Made smaller as requested */}
      <div className="px-6 pt-1 pb-10 flex justify-center gap-14 shrink-0 relative z-20 bg-transparent">
        <div className="flex flex-col items-center gap-1.5">
          <button className="w-12 h-12 bg-white border border-gray-100 rounded-full flex items-center justify-center text-gray-700 active:bg-gray-50 shadow-sm transition-all">
            <Share2 size={20} />
          </button>
          <span className="text-[10px] font-black text-gray-400">分享</span>
        </div>
        <div className="flex flex-col items-center gap-1.5">
          <button className="w-12 h-12 bg-white border border-gray-100 rounded-full flex items-center justify-center text-gray-700 active:bg-gray-50 shadow-sm transition-all">
            <Download size={20} />
          </button>
          <span className="text-[10px] font-black text-gray-400">下載圖片</span>
        </div>
      </div>
    </div>
  );
};

export default LongImagePreview;
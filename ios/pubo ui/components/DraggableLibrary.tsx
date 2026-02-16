import React, { useState, useRef, useEffect } from 'react';
import { SavedItem } from '../types';
import { ChevronUp, Instagram } from 'lucide-react';

interface DraggableLibraryProps {
  items: SavedItem[];
}

const PlatformIcon = ({ platform }: { platform?: 'instagram' | 'threads' | 'youtube' }) => {
  if (platform === 'instagram') {
    return (
      <div className="w-5 h-5 rounded-full flex items-center justify-center shrink-0 overflow-hidden bg-gradient-to-tr from-[#FFDC80] via-[#E1306C] to-[#833AB4]">
        <Instagram size={12} className="text-white" strokeWidth={3} />
      </div>
    );
  }
  if (platform === 'threads') {
    return (
      <div className="w-5 h-5 rounded-full flex items-center justify-center shrink-0 bg-black">
        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M14.28 15.66c-.66.6-1.56.93-2.52.93-.96 0-1.86-.33-2.52-.93m5.04-3.32c-.66.6-1.56.93-2.52.93-.96 0-1.86-.33-2.52-.93M22 12c0 5.52-4.48 10-10 10S2 17.52 2 12 6.48 2 12 2s10 4.48 10 10z" stroke="white" strokeWidth="2.5" strokeLinecap="round"/>
        </svg>
      </div>
    );
  }
  return null;
};

const DraggableLibrary: React.FC<DraggableLibraryProps> = ({ items }) => {
  const [isExpanded, setIsExpanded] = useState(false);
  const [activeFilter, setActiveFilter] = useState('全部');
  const [dragY, setDragY] = useState(0);
  
  const startY = useRef<number | null>(null);
  const sheetRef = useRef<HTMLDivElement>(null);
  
  const stateRef = useRef({ isExpanded, dragY });
  useEffect(() => {
    stateRef.current = { isExpanded, dragY };
  }, [isExpanded, dragY]);

  const filters = [
    { label: '全部', id: '全部' },
    { label: '美食 🍜', id: 'food' },
    { label: '景點 🗻', id: 'spot' },
    { label: '住宿 🏠', id: 'stay' },
    { label: '購物 🛍️', id: 'shop' },
    { label: '親子 🧒', id: 'family' },
  ];

  const performDragMove = (currentY: number) => {
    if (startY.current === null) return;
    const deltaY = currentY - startY.current;
    const { isExpanded } = stateRef.current;
    
    if (isExpanded) {
        if (deltaY > 0) setDragY(deltaY);
    } else {
        if (deltaY < 0) setDragY(deltaY);
    }
  };

  const performDragEnd = () => {
    if (startY.current === null) return;
    const { isExpanded, dragY } = stateRef.current;
    const threshold = 50; 
    
    if (isExpanded) {
        if (dragY > threshold) {
            setIsExpanded(false);
        }
    } else {
        if (dragY < -threshold) {
            setIsExpanded(true);
        }
    }
    
    setDragY(0);
    startY.current = null;
  };

  const handleTouchStart = (e: React.TouchEvent) => {
    startY.current = e.touches[0].clientY;
  };
  const handleTouchMove = (e: React.TouchEvent) => {
    performDragMove(e.touches[0].clientY);
  };
  const handleTouchEnd = () => {
    performDragEnd();
  };

  const handleMouseDown = (e: React.MouseEvent) => {
    if (e.button !== 0) return;
    startY.current = e.clientY;
    const handleWindowMouseMove = (ev: MouseEvent) => {
      performDragMove(ev.clientY);
    };
    const handleWindowMouseUp = () => {
      performDragEnd();
      window.removeEventListener('mousemove', handleWindowMouseMove);
      window.removeEventListener('mouseup', handleWindowMouseUp);
    };
    window.addEventListener('mousemove', handleWindowMouseMove);
    window.addEventListener('mouseup', handleWindowMouseUp);
  };

  const style = {
    transform: dragY !== 0 ? `translateY(${dragY}px)` : undefined,
  };

  return (
    <>
      <div 
        className={`fixed inset-0 bg-black/20 z-15 transition-opacity duration-300 ${isExpanded ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'}`}
        onClick={() => setIsExpanded(false)}
      />

      <div 
        ref={sheetRef}
        style={style}
        className={`fixed left-0 right-0 z-20 bg-white border-t-4 border-l-2 border-r-2 border-pubo-navy rounded-t-[2.5rem] flex flex-col transition-[top] duration-500 ease-[cubic-bezier(0.32,0.72,0,1)]
            ${isExpanded ? 'top-24 bottom-0' : 'top-[calc(100%-190px)] bottom-0'}
        `}
      >
        <div 
            className="shrink-0 touch-none bg-white rounded-t-[2.3rem]"
            onTouchStart={handleTouchStart}
            onTouchMove={handleTouchMove}
            onTouchEnd={handleTouchEnd}
            onMouseDown={handleMouseDown}
        >
            <div 
                className="w-full pt-4 pb-2 flex items-center justify-center cursor-grab active:cursor-grabbing"
                onClick={() => setIsExpanded(!isExpanded)}
            >
            <div className="w-12 h-1.5 bg-gray-200 rounded-full" />
            </div>

            <div className="px-6 mb-4">
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-2xl font-black text-pubo-navy tracking-tight">
                    收藏庫
                </h2>
                <button onClick={() => setIsExpanded(!isExpanded)}>
                    <ChevronUp className={`text-pubo-navy transition-transform duration-300 ${isExpanded ? 'rotate-180' : ''}`} />
                </button>
            </div>
            
            <div className="flex gap-4 overflow-x-auto no-scrollbar pb-3 pt-1 px-1 touch-pan-x">
                {filters.map(f => (
                    <button 
                        key={f.id}
                        onClick={(e) => { e.stopPropagation(); setActiveFilter(f.id); }}
                        className={`px-4 py-2 rounded-full text-xs font-black whitespace-nowrap transition-all active:scale-95 ${
                            activeFilter === f.id 
                            ? 'bg-pubo-cardBeige text-pubo-navy border-0 shadow-[2px_2px_0px_0px_#FFC849]' 
                            : 'bg-white border-2 border-gray-100 text-gray-400'
                        }`}
                    >
                        {f.label}
                    </button>
                ))}
            </div>
            </div>
        </div>

        <div 
            className={`px-6 flex-1 overflow-y-auto no-scrollbar pb-32 ${!isExpanded ? 'touch-none cursor-grab' : ''}`}
            onTouchStart={!isExpanded ? handleTouchStart : undefined}
            onTouchMove={!isExpanded ? handleTouchMove : undefined}
            onTouchEnd={!isExpanded ? handleTouchEnd : undefined}
            onMouseDown={!isExpanded ? handleMouseDown : undefined}
        >
            <div className="grid grid-cols-2 gap-4">
                {items.map((item) => (
                <div key={item.id} className="flex flex-col gap-3 group cursor-pointer">
                    <div className="aspect-[4/5] rounded-3xl overflow-hidden relative group-active:scale-[0.98] transition-all bg-gray-100">
                      <img src={item.imageUrl} alt={item.title} className="w-full h-full object-cover" />
                    </div>
                    <div className="px-1">
                      <div className="flex items-center gap-2 mb-1.5">
                        <PlatformIcon platform={item.platform} />
                        <h4 className="font-bold text-black text-sm leading-tight line-clamp-2">{item.title}</h4>
                      </div>
                      <div className="flex gap-2">
                        <span className="text-[10px] bg-gray-100 text-gray-400 px-2 py-0.5 rounded-full font-bold">
                          {item.id === '1' ? '2 個地點' : '4 個地點'}
                        </span>
                      </div>
                    </div>
                </div>
                ))}
            </div>
            
            <div className="h-24" />
        </div>
      </div>
    </>
  );
};

export default DraggableLibrary;
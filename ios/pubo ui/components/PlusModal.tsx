
import React, { useState, useEffect, useRef } from 'react';
import { Search, Star, Hotel, Sparkles, FileText, Loader2 } from 'lucide-react';
import { parseTravelContent } from '../services/geminiService';
import { Trip } from '../types';

interface PlusModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAdd: (data: any) => void;
  onOpenLibrary?: () => void;
  currentTrip?: Trip;
}

const PlusModal: React.FC<PlusModalProps> = ({ isOpen, onClose, onAdd, onOpenLibrary }) => {
  const [loading, setLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 500);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleSmartImport = async () => {
    setLoading(true);
    const mockContent = "智能導入中...";
    const result = await parseTravelContent(mockContent);
    setLoading(false);
    if (result.locations && result.locations.length > 0) {
        onAdd(result.locations);
        onClose();
    }
  };

  return (
    <>
      {/* 全屏半透明遮罩 */}
      <div 
        className="fixed inset-0 z-[120] bg-black/20 backdrop-blur-[2px] transition-opacity duration-300 animate-in fade-in"
        onClick={onClose}
      />
      
      {/* 功能面板容器 - 無背景，純浮動 */}
      <div className="fixed inset-x-0 bottom-0 z-[130] flex flex-col justify-end p-6 pb-14 pointer-events-none">
        <div className="w-full max-w-lg mx-auto pointer-events-auto">
          
          {/* 功能方塊區域：更扁平的長方形 (h-[70px]) */}
          <div className="flex gap-2.5 mb-5">
            
            {/* 1. 智能導入 - 藍色 (帶動畫延遲) */}
            <button 
                onClick={handleSmartImport}
                className="flex-[1.2] h-[70px] bg-white border-[1.5px] border-pubo-blue rounded-2xl flex flex-col items-start justify-between p-3 shadow-[2px_2px_0px_0px_#023B7E] active:translate-y-0.5 active:shadow-none transition-all animate-in slide-in-from-bottom-8 zoom-in-95 duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)]"
            >
              <div className="text-black">
                {loading ? <Loader2 size={18} className="animate-spin" /> : <Sparkles size={18} strokeWidth={2.5} />}
              </div>
              <span className="text-[12px] font-black text-black uppercase tracking-tight">智能導入</span>
            </button>

            {/* 2. 住宿 - 紅色 (帶動畫延遲) */}
            <button className="flex-1 h-[70px] bg-white border-[1.5px] border-pubo-red rounded-2xl flex flex-col items-start justify-between p-3 shadow-[2px_2px_0px_0px_#E84011] active:translate-y-0.5 active:shadow-none transition-all animate-in slide-in-from-bottom-10 zoom-in-95 delay-75 duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)]">
              <Hotel size={18} className="text-black" strokeWidth={2.5} />
              <span className="text-[12px] font-black text-black uppercase tracking-tight">住宿</span>
            </button>

            {/* 3. 收藏庫 - 紅色 (帶動畫延遲) */}
            <button 
                onClick={() => { onOpenLibrary?.(); onClose(); }}
                className="flex-1 h-[70px] bg-white border-[1.5px] border-pubo-red rounded-2xl flex flex-col items-start justify-between p-3 shadow-[2px_2px_0px_0px_#E84011] active:translate-y-0.5 active:shadow-none transition-all animate-in slide-in-from-bottom-12 zoom-in-95 delay-100 duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)]"
            >
              <Star size={18} className="text-black" strokeWidth={2.5} />
              <span className="text-[12px] font-black text-black uppercase tracking-tight">收藏庫</span>
            </button>

            {/* 4. 自定義 - 紅色 (帶動畫延遲) */}
            <button className="flex-1 h-[70px] bg-white border-[1.5px] border-pubo-red rounded-2xl flex flex-col items-start justify-between p-3 shadow-[2px_2px_0px_0px_#E84011] active:translate-y-0.5 active:shadow-none transition-all animate-in slide-in-from-bottom-14 zoom-in-95 delay-150 duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)]">
              <FileText size={18} className="text-black" strokeWidth={2.5} />
              <span className="text-[12px] font-black text-black uppercase tracking-tight">自定義</span>
            </button>
          </div>

          {/* 白色搜尋列 - 增加一點陰影與彈入感 */}
          <div className="relative animate-in slide-in-from-bottom-16 fade-in duration-700 delay-200 ease-out">
            <div className="absolute left-6 top-1/2 -translate-y-1/2">
                <Search size={22} className="text-gray-300" />
            </div>
            <input 
              ref={inputRef}
              type="text" 
              placeholder="搜尋地點"
              className="w-full h-15 bg-white rounded-full pl-16 pr-6 font-bold text-lg placeholder:text-gray-200 focus:outline-none shadow-[0_10px_30px_-10px_rgba(0,0,0,0.1)] border border-white/40"
            />
          </div>
        </div>
      </div>
    </>
  );
};

export default PlusModal;

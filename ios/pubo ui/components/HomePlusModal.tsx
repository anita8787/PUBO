
import React, { useState } from 'react';
import { Plus, Link as LinkIcon, Camera, X, Loader2 } from 'lucide-react';
import { parseTravelContent } from '../services/geminiService';

interface HomePlusModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCreateTripClick?: () => void;
}

const HomePlusModal: React.FC<HomePlusModalProps> = ({ 
  isOpen, 
  onClose, 
  onCreateTripClick 
}) => {
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  const handleSmartImport = async () => {
    setLoading(true);
    // 這裡調用智能導入邏輯
    setTimeout(() => {
        setLoading(false);
        onClose();
    }, 1500);
  };

  return (
    <>
        {/* 背景毛玻璃全屏遮罩 */}
        <div 
            className="fixed inset-0 z-[100] bg-white/20 backdrop-blur-2xl transition-all duration-500 animate-in fade-in"
            onClick={onClose}
        />

        {/* 使用口令按鈕 (右上角) */}
        <div className="fixed top-12 right-6 z-[110] animate-in slide-in-from-top-4 duration-500">
          <button className="px-5 py-2.5 bg-white/80 backdrop-blur-md border border-black/5 rounded-full text-sm font-black text-black shadow-sm active:scale-95 transition-all">
            使用口令
          </button>
        </div>

        {/* 功能卡片容器 */}
        <div className="fixed inset-x-0 bottom-0 z-[110] flex flex-col items-center p-8 pb-16 pointer-events-none">
            
            <div className="w-full max-w-sm space-y-4 mb-12 pointer-events-auto animate-in slide-in-from-bottom-8 duration-500 ease-[cubic-bezier(0.23,1,0.32,1)]">
                
                {/* 1. 創建新的行程 - 黑色背景 */}
                <button 
                    onClick={() => { onCreateTripClick?.(); onClose(); }}
                    className="w-full h-32 bg-black rounded-[2.8rem] px-10 flex items-center justify-between group active:scale-[0.97] transition-all shadow-2xl"
                >
                    <span className="text-2xl font-black text-white tracking-tight">創建新的行程</span>
                    <div className="w-11 h-11 rounded-full border-2 border-white/20 flex items-center justify-center text-white">
                        <Plus size={24} strokeWidth={3} />
                    </div>
                </button>

                {/* 2. 智能導入地點/行程 - 白色背景 */}
                <button 
                    onClick={handleSmartImport}
                    className="w-full h-32 bg-white rounded-[2.8rem] px-10 flex items-center justify-between group active:scale-[0.97] transition-all shadow-xl"
                >
                    <div className="flex flex-col items-start text-left">
                        <div className="flex items-center gap-2">
                          <span className="text-2xl font-black text-black tracking-tight">智能導入地點/行程</span>
                          {loading && <Loader2 className="animate-spin text-pubo-blue" size={18} />}
                        </div>
                        <p className="text-sm font-bold text-black/30 mt-1 leading-relaxed">
                          粘貼筆記鏈接、行程文本，<br />或上傳圖片進行識別
                        </p>
                    </div>
                    <div className="w-11 h-11 rounded-full border-2 border-black/5 flex items-center justify-center text-black">
                        <LinkIcon size={22} strokeWidth={2.5} />
                    </div>
                </button>

                {/* 3. 「採集」識別 - 白色背景 */}
                <button 
                    className="w-full h-32 bg-white rounded-[2.8rem] px-10 flex items-center justify-between group active:scale-[0.97] transition-all shadow-xl"
                >
                    <div className="flex flex-col items-start text-left">
                        <span className="text-2xl font-black text-black tracking-tight">「採集」識別</span>
                        <p className="text-sm font-bold text-black/30 mt-1">識別同時收藏你的生活</p>
                    </div>
                    <div className="w-11 h-11 rounded-full border-2 border-black/5 flex items-center justify-center text-black">
                        <Camera size={22} strokeWidth={2.5} />
                    </div>
                </button>
            </div>

            {/* 底部關閉按鈕 */}
            <button 
                onClick={onClose}
                className="w-16 h-16 bg-black/5 backdrop-blur-md rounded-full flex items-center justify-center text-black/40 pointer-events-auto active:scale-90 transition-all border border-black/5"
            >
                <X size={32} strokeWidth={2.5} />
            </button>
        </div>
    </>
  );
};

export default HomePlusModal;

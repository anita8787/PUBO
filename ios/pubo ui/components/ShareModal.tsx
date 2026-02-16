import React from 'react';
import { Link2, Mail, QrCode, MoreHorizontal } from 'lucide-react';

interface ShareModalProps {
  isOpen: boolean;
  onClose: () => void;
  onGenerateLongImage?: () => void;
}

const ShareModal: React.FC<ShareModalProps> = ({ isOpen, onClose, onGenerateLongImage }) => {
  if (!isOpen) return null;

  return (
    <>
      {/* Backdrop */}
      <div 
        className="fixed inset-0 z-[60] bg-black/40 backdrop-blur-sm transition-opacity duration-300 animate-in fade-in"
        onClick={onClose}
      />

      {/* Bottom Sheet */}
      <div className="fixed inset-x-0 bottom-0 z-[70] flex flex-col justify-end pointer-events-none">
        <div className="bg-white w-full rounded-t-[2.5rem] p-6 pb-12 shadow-2xl pointer-events-auto animate-in slide-in-from-bottom duration-300 relative border-t-2 border-black">
          
          {/* Handle Bar */}
          <div className="flex justify-center mb-6">
            <div className="w-12 h-1 bg-gray-200 rounded-full" />
          </div>

          <div className="flex justify-between items-center mb-6 px-2">
            <h3 className="text-xl font-black text-pubo-navy">分享行程</h3>
          </div>

          {/* Main Action Cards - Height kept at h-32 */}
          <div className="grid grid-cols-2 gap-4 mb-10">
            {/* 1. Co-editing / Invite Partners */}
            <div className="relative h-32 bg-pubo-yellow rounded-[2.2rem] border-2 border-black p-5 flex flex-col justify-start overflow-hidden shadow-retro-sm active:translate-y-0.5 active:shadow-none transition-all cursor-pointer group">
              <div className="relative z-10">
                <h4 className="text-lg font-black text-black leading-tight">共同編輯</h4>
                <p className="text-[10px] font-bold text-black/60 mt-1">邀請你的旅遊夥伴</p>
              </div>
              
              {/* Character Illustration - Two Girls Sticker */}
              <div className="absolute -right-1 -bottom-1 w-24 h-24 transition-transform group-hover:scale-105 duration-300 pointer-events-none">
                <img 
                  src="https://lh3.googleusercontent.com/d/1p0ypn7o8ElRknvdUN7mqsuOPrf3el32W" 
                  alt="Co-edit Illustration" 
                  className="w-full h-full object-contain"
                />
              </div>
            </div>

            {/* 2. Generate Long Image / Export */}
            <div 
              onClick={() => {
                onGenerateLongImage?.();
                onClose();
              }}
              className="relative h-32 bg-[#003472] rounded-[2.2rem] border-2 border-black p-5 flex flex-col justify-start overflow-hidden shadow-retro-sm active:translate-y-0.5 active:shadow-none transition-all cursor-pointer group"
            >
              <div className="relative z-10">
                <h4 className="text-lg font-black text-white leading-tight">生成長圖</h4>
                <p className="text-[10px] font-bold text-white/60 mt-1">匯出完整的行程表</p>
              </div>

              {/* Updated Printer Sticker Illustration */}
              <div className="absolute -right-2 -bottom-2 w-20 h-20 transition-transform group-hover:scale-105 duration-300 pointer-events-none">
                <img 
                  src="https://lh3.googleusercontent.com/d/1WrlAcMj4yt3rhHPc1PG8FqTzm7s3SPdS" 
                  alt="Printer Illustration" 
                  className="w-full h-full object-contain"
                />
              </div>
            </div>
          </div>

          {/* Horizontal divider */}
          <div className="h-px bg-gray-100 w-full mb-8" />

          {/* Secondary Sharing Options */}
          <div className="flex justify-between items-center px-4">
            <div className="flex flex-col items-center gap-2">
              <button className="w-14 h-14 bg-gray-50 border border-gray-100 rounded-full flex items-center justify-center text-gray-700 active:bg-gray-200 transition-colors">
                <Link2 size={24} />
              </button>
              <span className="text-[10px] font-bold text-gray-400">複製連結</span>
            </div>

            <div className="flex flex-col items-center gap-2">
              <button className="w-14 h-14 bg-gray-50 border border-gray-100 rounded-full flex items-center justify-center text-gray-700 active:bg-gray-200 transition-colors">
                <Mail size={24} />
              </button>
              <span className="text-[10px] font-bold text-gray-400">Email</span>
            </div>

            <div className="flex flex-col items-center gap-2">
              <button className="w-14 h-14 bg-gray-50 border border-gray-100 rounded-full flex items-center justify-center text-gray-700 active:bg-gray-200 transition-colors">
                <QrCode size={24} />
              </button>
              <span className="text-[10px] font-bold text-gray-400">掃碼分享</span>
            </div>

            <div className="flex flex-col items-center gap-2">
              <button className="w-14 h-14 bg-gray-50 border border-gray-100 rounded-full flex items-center justify-center text-gray-700 active:bg-gray-200 transition-colors">
                <MoreHorizontal size={24} />
              </button>
              <span className="text-[10px] font-bold text-gray-400">更多</span>
            </div>
          </div>
          
          {/* Safe Area Spacer */}
          <div className="h-6" />
        </div>
      </div>
    </>
  );
};

export default ShareModal;
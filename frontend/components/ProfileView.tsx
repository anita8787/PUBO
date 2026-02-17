
import React from 'react';
import { ChevronLeft, Pencil, Box, MapPin, Heart, MessageSquare, Send } from 'lucide-react';

interface ProfileViewProps {
  onBack: () => void;
}

const ProfileView: React.FC<ProfileViewProps> = ({ onBack }) => {
  return (
    <div className="absolute inset-0 bg-[#FDFAEE] z-[60] flex flex-col animate-in slide-in-from-right duration-300">
      <div className="pt-16 px-6 pb-2 flex items-center justify-between">
        <button onClick={onBack} className="text-gray-400">
          <ChevronLeft size={24} />
        </button>
        <h2 className="text-lg font-black text-gray-400">個人</h2>
        <div className="w-6" />
      </div>

      <div className="flex-1 overflow-y-auto px-6 pt-2 no-scrollbar">
        {/* User Info - Downsized */}
        <div className="flex items-center gap-3 mb-6">
          <div className="w-20 h-20 rounded-full border-[2px] border-white shadow-lg overflow-hidden bg-pubo-yellow">
            <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=Nita" className="w-full h-full" />
          </div>
          <div className="flex flex-col">
            <div className="flex items-center gap-1">
              <h1 className="text-xl font-black text-pubo-navy">Nita</h1>
              <Pencil size={12} className="text-pubo-navy" />
            </div>
            <p className="text-[10px] font-bold text-pubo-navy/60">123 粉絲  100追蹤</p>
          </div>
        </div>

        {/* Stats Card - Updated with Yellow Shadow */}
        <div className="bg-white border-2 border-pubo-yellow rounded-[2rem] p-4 shadow-[4px_4px_0px_0px_#FFC849] flex mb-8">
          <div className="flex-1 flex flex-col items-center border-r border-gray-100">
            <span className="text-2xl font-black text-[#E84011]">56</span>
            <span className="text-[10px] font-bold text-gray-400">個徽章</span>
          </div>
          <div className="flex-1 flex flex-col items-center">
            <span className="text-2xl font-black text-[#E84011]">4</span>
            <span className="text-[10px] font-bold text-gray-400">個行程</span>
          </div>
        </div>

        {/* Quick Actions - Reduced Gaps, Updated Shadows & Text Size */}
        <div className="flex justify-center gap-8 mb-10">
          <div className="flex flex-col items-center gap-2">
            <div className="w-14 h-14 rounded-full border-2 border-pubo-yellow flex items-center justify-center bg-white shadow-[3px_3px_0px_0px_#FFC849] active:scale-95 transition-transform cursor-pointer">
              <Box className="text-pubo-navy" size={24} />
            </div>
            <span className="text-xs font-black text-pubo-navy">旅行命運</span>
          </div>
          <div className="flex flex-col items-center gap-2">
            <div className="w-14 h-14 rounded-full border-2 border-pubo-yellow flex items-center justify-center bg-white shadow-[3px_3px_0px_0px_#FFC849] active:scale-95 transition-transform cursor-pointer">
              <MapPin className="text-pubo-navy" size={24} />
            </div>
            <span className="text-xs font-black text-pubo-navy">旅行足跡</span>
          </div>
          <div className="flex flex-col items-center gap-2">
            <div className="w-14 h-14 rounded-full border-2 border-pubo-yellow flex items-center justify-center bg-white shadow-[3px_3px_0px_0px_#FFC849] active:scale-95 transition-transform cursor-pointer">
              <Heart className="text-pubo-navy" size={24} />
            </div>
            <span className="text-xs font-black text-pubo-navy">收藏地點</span>
          </div>
        </div>

        {/* List Items Card */}
        <div className="bg-white border-2 border-pubo-navy rounded-[2rem] p-5 pb-32 relative">
          <div className="absolute top-0 left-1/2 -translate-x-1/2 -translate-y-1/2 w-24 h-8 bg-white border-2 border-pubo-navy rounded-full shadow-retro-sm flex items-center justify-center">
            <div className="w-10 h-1 bg-gray-100 rounded-full" />
          </div>
          
          <div className="space-y-5 pt-3">
            <div className="flex items-center gap-3">
              <MessageSquare className="text-gray-400" size={20} />
              <span className="flex-1 font-bold text-sm text-gray-700">意見回饋</span>
            </div>
            <div className="h-px bg-gray-50" />
            <div className="flex items-center gap-3">
              <Send className="text-gray-400" size={20} />
              <span className="flex-1 font-bold text-sm text-gray-700">貼文管理</span>
            </div>
            <div className="h-px bg-gray-50" />
            <div className="flex items-center gap-3">
              <MessageSquare className="text-gray-400" size={20} />
              <span className="flex-1 font-bold text-sm text-gray-700">意見回饋</span>
            </div>
          </div>

          {/* Activity Gauge */}
          <div className="mt-10 p-6 border-2 border-[#E84011] rounded-[2.5rem] relative overflow-hidden bg-white">
            <div className="flex flex-col items-center">
              <div className="relative w-full max-w-[180px] flex flex-col items-center">
                <svg className="w-full" viewBox="0 0 100 65" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path 
                    d="M 10 55 A 40 40 0 0 1 90 55" 
                    fill="none" 
                    stroke="#FFDCC8" 
                    strokeWidth="8" 
                    strokeLinecap="round" 
                  />
                  <path 
                    d="M 10 55 A 40 40 0 0 1 78.28 26.72" 
                    fill="none" 
                    stroke="#FFC849" 
                    strokeWidth="8" 
                    strokeLinecap="round" 
                  />
                  <circle cx="78.28" cy="26.72" r="4" fill="#E84011" stroke="white" strokeWidth="1" />
                </svg>
                
                <div className="flex flex-col items-center mt-[-15px] pb-2">
                  <h3 className="text-3xl font-black text-pubo-navy">2,241步</h3>
                  <p className="text-[10px] font-black text-pubo-navy mt-1">今日活力值</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ProfileView;

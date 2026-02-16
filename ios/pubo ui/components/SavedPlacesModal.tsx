import React, { useState } from 'react';
import { X, Plus, Search } from 'lucide-react';

interface SavedPlacesModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSelect?: (item: any) => void;
}

const SavedPlacesModal: React.FC<SavedPlacesModalProps> = ({ isOpen, onClose, onSelect }) => {
  const [activeFilter, setActiveFilter] = useState('大阪市');

  if (!isOpen) return null;

  const filters = ['大阪市', '城東', '泉州市', '鍾路', '箕面'];
  
  const savedLocations = [
    { id: '1', name: 'Hankyu Department Store U...', category: '購物', address: '8-7 Kakudachō, Kita Ward, Osaka, 530...', image: 'https://images.unsplash.com/photo-1590674852885-8c645e09003e?q=80&w=2070&auto=format&fit=crop' },
    { id: '2', name: '難波八阪神社', category: '景點', address: '2-chōme-9-19 Motomachi, Naniwa Wa...', image: 'https://images.unsplash.com/photo-1545569341-9eb8b30979d9?q=80&w=2070&auto=format&fit=crop' },
    { id: '3', name: 'Shinsaibashisuji', category: '其他', address: 'Shinsaibashisuji, Chuo Ward, Osaka, 54...', image: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=2070&auto=format&fit=crop' },
    { id: '4', name: '&ISLAND アンドアイランド 北浜', category: '吃喝', address: '2-chōme-1-23 Kitahama, Chuo Ward,...', image: 'https://images.unsplash.com/photo-1550966841-3ee7adac1661?q=80&w=2070&auto=format&fit=crop' },
    { id: '5', name: '通天閣本通商店會', category: '交通', address: '日本〒556-0002 Osaka, Naniwa Ward,...', image: 'https://images.unsplash.com/photo-1576675466969-38eeae4b41f6?q=80&w=2070&auto=format&fit=crop' },
    { id: '6', name: 'EST', category: '購物', address: '3-25 Kakudachō, Kita Ward, Osaka, 53...', image: 'https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=2070&auto=format&fit=crop' },
    { id: '7', name: 'Harukas 300 (Observation De...', category: '其他', address: '1-chōme-1-43 Abenosuji, Abeno Ward,...', image: 'https://images.unsplash.com/photo-1493780474015-ba834ff0ce2f?q=80&w=2070&auto=format&fit=crop' },
  ];

  const getCategoryColor = (cat: string) => {
    switch (cat) {
      case '購物': return 'text-green-500';
      case '景點': return 'text-green-600';
      case '吃喝': return 'text-orange-500';
      case '交通': return 'text-blue-500';
      default: return 'text-gray-500';
    }
  };

  return (
    <>
      <div 
        className="fixed inset-0 z-[80] bg-black/30 backdrop-blur-[2px] transition-opacity duration-300 animate-in fade-in"
        onClick={onClose}
      />
      <div className="fixed inset-x-0 bottom-0 z-[90] flex flex-col justify-end pointer-events-none">
        <div className="bg-white w-full h-[92vh] rounded-t-[2.5rem] flex flex-col shadow-2xl pointer-events-auto animate-in slide-in-from-bottom duration-700 ease-[cubic-bezier(0.32,0.72,0,1)] relative overflow-hidden">
          
          {/* Header */}
          <div className="shrink-0 p-6 pb-2">
            <div className="flex justify-center mb-4">
              <div className="w-12 h-1.5 bg-gray-200 rounded-full" />
            </div>
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-3xl font-black text-black">已收藏的地點</h3>
              <button onClick={onClose} className="p-2 text-gray-400">
                <X size={24} />
              </button>
            </div>

            {/* Filters Pills */}
            <div className="flex gap-3 overflow-x-auto no-scrollbar pb-4 -mx-6 px-6">
              {filters.map((f) => (
                <button
                  key={f}
                  onClick={() => setActiveFilter(f)}
                  className={`px-5 py-2 rounded-full border-2 text-sm font-bold whitespace-nowrap transition-all ${
                    activeFilter === f 
                    ? 'bg-white border-black text-black shadow-retro-sm' 
                    : 'bg-white border-gray-100 text-gray-400'
                  }`}
                >
                  {f}
                </button>
              ))}
            </div>
          </div>

          {/* Scrollable List */}
          <div className="flex-1 overflow-y-auto px-6 pb-12 no-scrollbar">
            <div className="space-y-6">
              {savedLocations.map((loc) => (
                <div key={loc.id} className="flex items-center gap-4 group">
                  <div className="w-16 h-16 rounded-2xl overflow-hidden shrink-0 bg-gray-100">
                    <img src={loc.image} alt={loc.name} className="w-full h-full object-cover" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <h4 className="font-black text-black text-lg truncate leading-tight">{loc.name}</h4>
                    <div className="flex items-center gap-2 mt-1">
                      <span className={`text-xs font-bold ${getCategoryColor(loc.category)}`}>{loc.category}</span>
                      <span className="text-xs text-gray-300 font-medium truncate">| {loc.address}</span>
                    </div>
                  </div>
                  <button 
                    onClick={() => onSelect?.(loc)}
                    className="w-10 h-10 rounded-full border-2 border-gray-100 flex items-center justify-center text-gray-400 active:bg-gray-100 active:border-black active:text-black transition-all"
                  >
                    <Plus size={20} strokeWidth={2.5} />
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default SavedPlacesModal;

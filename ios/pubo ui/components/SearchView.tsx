
import React from 'react';
import { Search, ChevronLeft } from 'lucide-react';

interface SearchViewProps {
  onBack: () => void;
}

const destinations = [
  { name: '上海市', image: 'https://images.unsplash.com/photo-1548848221-0c2e497ed557?q=80&w=400&auto=format&fit=crop' },
  { name: '北京市', image: 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?q=80&w=400&auto=format&fit=crop' },
  { name: '廣州市', image: 'https://images.unsplash.com/photo-1541410965313-d53b3c16ef17?q=80&w=400&auto=format&fit=crop' },
  { name: '青島市', image: 'https://images.unsplash.com/photo-1510253430543-9807577517c2?q=80&w=400&auto=format&fit=crop' },
  { name: '南京市', image: 'https://images.unsplash.com/photo-1559239115-ce3eb7cb87ea?q=80&w=400&auto=format&fit=crop' },
  { name: '成都市', image: 'https://images.unsplash.com/photo-1543097692-fa13c6cd8595?q=80&w=400&auto=format&fit=crop' },
  { name: '重慶市', image: 'https://images.unsplash.com/photo-1536562555261-04285854492b?q=80&w=400&auto=format&fit=crop' },
  { name: '杭州市', image: 'https://images.unsplash.com/photo-1512100356956-c1b47ce152e8?q=80&w=400&auto=format&fit=crop' },
  { name: '韓國', image: 'https://images.unsplash.com/photo-1517154421773-0529f29ea451?q=80&w=400&auto=format&fit=crop' },
  { name: '香港(中國)', image: 'https://images.unsplash.com/photo-1507450491953-76d33f208261?q=80&w=400&auto=format&fit=crop' },
];

const SearchView: React.FC<SearchViewProps> = ({ onBack }) => {
  return (
    <div className="absolute inset-0 bg-white z-[60] flex flex-col animate-in slide-in-from-right duration-300">
      <div className="pt-16 px-6 pb-4 flex items-center gap-4">
        <div className="flex-1 relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
          <input 
            type="text" 
            placeholder="請輸入地點，發現更多精選行程"
            className="w-full h-12 pl-12 pr-4 bg-gray-100 rounded-2xl font-bold text-sm focus:outline-none"
            autoFocus
          />
        </div>
        <button onClick={onBack} className="text-pubo-navy font-black">取消</button>
      </div>

      <div className="flex-1 overflow-y-auto px-6 pt-6">
        <h2 className="text-xl font-black text-pubo-navy mb-6">熱門目的地行程</h2>
        <div className="grid grid-cols-2 gap-x-6 gap-y-8">
          {destinations.map((dest, i) => (
            <div key={i} className="flex items-center gap-3 cursor-pointer active:scale-95 transition-transform">
              <div className="w-14 h-14 rounded-xl overflow-hidden shadow-sm">
                <img src={dest.image} className="w-full h-full object-cover" />
              </div>
              <span className="font-black text-pubo-navy text-lg">{dest.name}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default SearchView;

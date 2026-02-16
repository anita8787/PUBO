
import React, { useState } from 'react';
import Navigation from './components/Navigation';
import HomePlusModal from './components/HomePlusModal';
import DraggableLibrary from './components/DraggableLibrary';
import SavedPlacesModal from './components/SavedPlacesModal';
import ExploreCard from './components/ExploreCard';
import TripCard from './components/TripCard';
import ItineraryView from './components/ItineraryView';
import SearchView from './components/SearchView';
import ProfileView from './components/ProfileView';
import MapView from './components/MapView';
import CreateTripModal from './components/CreateTripModal';
import { Tab, Post, Trip, SavedItem, ItineraryDay, ItinerarySpot } from './types';
import { Search, User, Sparkles, Heart, Star, Plane, ChevronRight } from 'lucide-react';

const initialSpots: ItinerarySpot[] = [
  { id: '1', time: '11:00', duration: '11:00營業', name: '東京車站', category: 'spot', image: 'https://lh3.googleusercontent.com/d/1t-MldFqZClPBgCEREk4JGobsPhmgZflx', subLabel: '10分鐘', notes: ['要逛的店', 'kite', 'paroco'], travelToNext: { time: '10分鐘', distance: '2.4公里', type: 'train' } },
  { id: '2', time: '09:00', duration: '11:00營業', name: '豪德寺', category: 'spot', image: 'https://images.unsplash.com/photo-1570459027562-4a916cc6113f?q=80&w=1587&auto=format&fit=crop', subLabel: '10分鐘', travelToNext: { time: '10分鐘', distance: '2.4公里', type: 'train' } },
  { id: '3', time: '12:30', duration: '午餐', name: 'neel', category: 'food', image: 'https://images.unsplash.com/photo-1578469645742-46cae010e5d4?q=80&w=1740&auto=format&fit=crop', subLabel: '10分鐘' },
];

const mockItineraryDaysData: ItineraryDay[] = [
  { dayLabel: 'Day1', date: '02/20', weekday: '週一', spots: initialSpots },
  { dayLabel: 'Day2', date: '02/21', weekday: '週二', spots: [] },
  { dayLabel: 'Day3', date: '02/22', weekday: '週三', spots: [] },
  { dayLabel: 'Day4', date: '02/23', weekday: '週四', spots: [] },
  { dayLabel: 'Day5', date: '02/24', weekday: '週五', spots: [] },
  { dayLabel: 'Day6', date: '02/25', weekday: '週六', spots: [] },
  { dayLabel: 'Day7', date: '02/26', weekday: '週日', spots: [] },
];

const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<Tab>(Tab.HOME);
  const [isOverlayOpen, setIsOverlayOpen] = useState(false);
  const [isSavedPlacesOpen, setIsSavedPlacesOpen] = useState(false);
  const [isCreateTripModalOpen, setIsCreateTripModalOpen] = useState(false);
  const [isTabBarVisible, setIsTabBarVisible] = useState(true);
  
  const [itineraryDays, setItineraryDays] = useState<ItineraryDay[]>(mockItineraryDaysData);
  const [selectedDayIndex, setSelectedDayIndex] = useState<number>(0);

  const posts: Post[] = [
    { id: '1', author: 'Nita', avatar: '', content: 'Fuji View', image: 'https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?q=80&w=1740&auto=format&fit=crop', platform: 'instagram', tags: ['富士山'] },
    { id: '2', author: 'Nita', avatar: '', content: 'Lucky Cat Temple', image: 'https://images.unsplash.com/photo-1570459027562-4a916cc6113f?q=80&w=1587&auto=format&fit=crop', platform: 'instagram', tags: ['豪德寺'] },
    { id: '3', author: 'Nita', avatar: '', content: 'Shibuya Crossing', image: 'https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=1740&auto=format&fit=crop', platform: 'instagram', tags: ['澀谷'] },
    { id: '4', author: 'Nita', avatar: '', content: 'Kyoto Alley', image: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=1740&auto=format&fit=crop', platform: 'instagram', tags: ['京都'] },
    { id: '5', author: 'Nita', avatar: '', content: 'Osaka Castle', image: 'https://images.unsplash.com/photo-1590674852885-8c645e09003e?q=80&w=1740&auto=format&fit=crop', platform: 'instagram', tags: ['大阪'] },
  ];

  const recommendations = [
    { id: 'r1', category: '景點', name: '京都古都巡禮', rating: 4.8, reviews: '1.2k', image: 'https://images.unsplash.com/photo-1545569341-9eb8b30979d9?q=80&w=400&auto=format&fit=crop' },
    { id: 'r2', category: '美食', name: '大阪道頓堀拉麵', rating: 4.5, reviews: '850', image: 'https://images.unsplash.com/photo-1576675466969-38eeae4b41f6?q=80&w=400&auto=format&fit=crop' },
    { id: 'r3', category: '購物', name: '銀座豪華購物區', rating: 4.3, reviews: '2.1k', image: 'https://images.unsplash.com/photo-1555617766-c94804975da3?q=80&w=400&auto=format&fit=crop' },
    { id: 'r4', category: '文化', name: '淺草寺雷門', rating: 4.7, reviews: '3.4k', image: 'https://images.unsplash.com/photo-1524413840807-0c3cb6fa808d?q=80&w=400&auto=format&fit=crop' },
  ];

  const trips: Trip[] = [
    { id: '1', title: '東京', date: '2026/08/20-08/26', coverImage: '', spots: 22, color: 'yellow' },
    { id: '2', title: '大阪', date: '2026/08/20-08/26', coverImage: '', spots: 22, color: 'orange' },
    { id: '3', title: '韓國', date: '2026/08/20-08/26', coverImage: '', spots: 22, color: 'red' },
    { id: '4', title: '泰國', date: '2026/08/20-08/26', coverImage: '', spots: 22, color: 'red' },
    { id: '5', title: '中國', date: '2026/08/20-08/26', coverImage: '', spots: 22, color: 'blue' },
  ];

  const savedItems: SavedItem[] = [
    { id: '1', title: '日本富士山一日遊怎麼玩', location: 'Fuji', category: 'spot', imageUrl: 'https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?q=80&w=1740&auto=format&fit=crop', platform: 'instagram' },
  ];

  const handleOpenSavedPlaces = () => {
    setIsSavedPlacesOpen(true);
  };

  return (
    <div className="relative w-full h-screen bg-pubo-bg overflow-hidden flex flex-col font-sans text-black">
      {activeTab === Tab.ITINERARY ? (
        <ItineraryView 
          trips={trips} 
          itineraryDays={itineraryDays}
          setItineraryDays={setItineraryDays}
          selectedDayIndex={selectedDayIndex}
          setSelectedDayIndex={setSelectedDayIndex}
          onTripSelectionChange={(isSelected) => setIsTabBarVisible(!isSelected)}
          onAddClick={() => setIsOverlayOpen(true)}
          onBack={() => setActiveTab(Tab.HOME)}
        />
      ) : activeTab === Tab.SEARCH ? (
        <SearchView onBack={() => setActiveTab(Tab.HOME)} />
      ) : activeTab === Tab.PROFILE ? (
        <ProfileView onBack={() => setActiveTab(Tab.HOME)} />
      ) : activeTab === Tab.MAP ? (
        <MapView onBack={() => setActiveTab(Tab.HOME)} />
      ) : (
        <>
            <header className="pt-16 pb-4 px-6 flex items-center justify-between z-10 bg-pubo-bg shrink-0">
                <div className="flex items-center gap-3">
                    <div className="w-16 h-16 rounded-full overflow-hidden border-2 border-white shadow-lg shrink-0">
                        <img src="https://lh3.googleusercontent.com/d/1XyUeGfWlH5jI-5y6-V6w_pY-9pYy5fYp" alt="Avatar" className="w-full h-full object-cover" />
                    </div>
                    <div className="flex flex-col items-start">
                        <h1 className="text-3xl font-black text-pubo-navy leading-tight tracking-tight uppercase">Hi! Nita</h1>
                    </div>
                </div>
                <div className="flex items-center gap-3">
                    <button onClick={() => setActiveTab(Tab.SEARCH)} className="w-10 h-10 border-2 border-pubo-navy bg-white rounded-full flex items-center justify-center text-pubo-navy active:bg-pubo-navy active:text-white transition-colors duration-200"><Search size={22} strokeWidth={2.5} /></button>
                    <button onClick={() => setActiveTab(Tab.PROFILE)} className="w-10 h-10 border-2 border-pubo-navy bg-white rounded-full flex items-center justify-center text-pubo-navy active:bg-pubo-navy active:text-white transition-colors duration-200"><User size={22} /></button>
                </div>
            </header>
            <main className="flex-1 overflow-y-auto no-scrollbar relative pb-[250px]">
                {/* 1. 即將出發 */}
                <section className="mt-4 mb-10 px-6">
                    <h2 className="text-2xl font-black text-pubo-navy mb-4 tracking-tight">即將出發</h2>
                    <div className="w-full border-[2.5px] border-[#203B93] rounded-[1.8rem] overflow-hidden shadow-retro bg-white">
                        <div className="bg-[#FFC849] px-6 py-3.5 flex justify-between items-center border-b-2 border-[#203B93]">
                            <span className="text-[9px] font-black text-[#203B93] uppercase tracking-[0.25em]">Boarding Pass</span>
                            <span className="text-[9px] font-black text-[#203B93] uppercase tracking-[0.25em]">CONFIRMED</span>
                        </div>
                        <div className="px-6 py-5">
                            <div className="flex justify-between items-center mb-0.5">
                                <div className="flex flex-col">
                                    <span className="text-[9px] font-bold text-[#203B93] uppercase leading-none mb-1.5">From</span>
                                    <h3 className="text-3xl font-black text-[#203B93] leading-none mb-1.5">台北</h3>
                                    <span className="text-[10px] font-normal text-black leading-none uppercase tracking-widest">Taipei</span>
                                </div>
                                <div className="flex-1 px-8 relative flex flex-col items-center">
                                    <span className="text-[9px] font-bold text-[#203B93] mb-1.5 tracking-wider">NH852</span>
                                    <div className="w-full h-[1.5px] bg-[#203B93] relative">
                                        <div className="absolute left-1/2 -translate-x-1/2 -top-[7px] bg-white px-1.5">
                                            <Plane size={14} className="text-[#203B93] rotate-90" fill="#203B93" />
                                        </div>
                                    </div>
                                </div>
                                <div className="flex flex-col items-end text-right">
                                    <span className="text-[9px] font-bold text-[#203B93] uppercase leading-none mb-1.5">To</span>
                                    <h3 className="text-3xl font-black text-[#203B93] leading-none mb-1.5">大阪</h3>
                                    <span className="text-[10px] font-normal text-black leading-none uppercase tracking-widest">Osaka</span>
                                </div>
                            </div>
                        </div>
                        <div className="bg-[#EBF2FF] border-t border-dashed border-[#203B93]/30 grid grid-cols-4 px-6 py-1.5">
                            <div className="flex flex-col items-start">
                                <span className="text-[8px] font-bold text-[#203B93] uppercase mb-0.5 tracking-wider">Date</span>
                                <p className="text-[10px] font-normal text-black uppercase">02.20 THU</p>
                            </div>
                            <div className="flex flex-col items-start">
                                <span className="text-[8px] font-bold text-[#203B93] uppercase mb-0.5 tracking-wider">Time</span>
                                <p className="text-[10px] font-normal text-black uppercase">12:30 PM</p>
                            </div>
                            <div className="flex flex-col items-start">
                                <span className="text-[8px] font-bold text-[#203B93] uppercase mb-0.5 tracking-wider">Seat</span>
                                <p className="text-[10px] font-normal text-black uppercase">12A</p>
                            </div>
                            <div className="flex flex-col items-start">
                                <span className="text-[8px] font-bold text-[#203B93] uppercase mb-0.5 tracking-wider">Gate</span>
                                <p className="text-[10px] font-normal text-black uppercase">B7</p>
                            </div>
                        </div>
                    </div>
                </section>

                {/* 2. 推薦行程 */}
                <section className="mb-10">
                    <div className="flex items-center justify-between mb-4 px-6">
                        <h2 className="text-2xl font-black text-pubo-navy tracking-tight">推薦行程</h2>
                        <button className="text-gray-400 font-bold text-sm flex items-center uppercase">More <ChevronRight size={16} /></button>
                    </div>
                    <div className="flex gap-5 overflow-x-auto no-scrollbar px-6 pb-2 snap-x">
                        {recommendations.map((item) => (
                            <div key={item.id} className="min-w-[170px] bg-white border-[2.5px] border-[#C8252B] rounded-[1.2rem] overflow-hidden flex flex-col shrink-0 snap-start">
                                <div className="h-[115px] w-full relative border-b-2 border-[#C8252B]">
                                    <img src={item.image} className="w-full h-full object-cover" />
                                    <div className="absolute top-2 right-2 w-7 h-7 bg-white border-2 border-[#C8252B] rounded-full flex items-center justify-center">
                                        <Heart size={14} className="text-[#C8252B]" />
                                    </div>
                                </div>
                                <div className="p-3 bg-white flex flex-col gap-2">
                                    <div className="border border-[#C8252B] rounded-md px-2 py-0.5 w-fit">
                                        <span className="text-[10px] font-black text-[#C8252B] uppercase">{item.category}</span>
                                    </div>
                                    <div className="flex flex-col gap-0.5">
                                       <p className="text-[12px] font-black text-black truncate leading-tight uppercase">{item.name}</p>
                                       <div className="flex items-center gap-1 mt-1">
                                          <div className="flex">
                                             {[...Array(5)].map((_, i) => (
                                                <Star key={i} size={10} fill={i < 4 ? "#C8252B" : "none"} className="text-[#C8252B]" />
                                             ))}
                                          </div>
                                          <span className="text-[10px] font-bold text-[#C8252B]">{item.rating}</span>
                                       </div>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                </section>

                {/* 3. 我的行程 */}
                <section className="mb-10 px-6">
                    <div className="flex items-center gap-2 mb-4">
                        <h2 className="text-2xl font-black text-pubo-navy tracking-tight">我的行程</h2>
                        <Sparkles className="text-pubo-cardYellow fill-current" strokeWidth={0} size={24}/>
                    </div>
                    {trips.slice(0, 1).map(trip => <TripCard key={trip.id} trip={trip} />)}
                </section>

                {/* 4. 探索 */}
                <section className="mb-12">
                    <h2 className="text-2xl font-black text-pubo-navy mb-4 tracking-tight px-6">探索</h2>
                    <div className="flex gap-4 overflow-x-auto no-scrollbar px-6 snap-x">
                        {posts.map(post => <ExploreCard key={post.id} post={post} />)}
                    </div>
                </section>
            </main>
        </>
      )}
      {activeTab === Tab.HOME && <DraggableLibrary items={savedItems} />}
      {isTabBarVisible && activeTab !== Tab.MAP && <Navigation activeTab={activeTab === Tab.PROFILE || activeTab === Tab.SEARCH ? Tab.HOME : activeTab} onTabChange={setActiveTab} onPlusClick={() => setIsOverlayOpen(true)} />}
      
      {/* 首頁專屬加號彈窗 */}
      <HomePlusModal 
        isOpen={isOverlayOpen} 
        onClose={() => setIsOverlayOpen(false)} 
        onCreateTripClick={() => setIsCreateTripModalOpen(true)}
      />
      
      <SavedPlacesModal isOpen={isSavedPlacesOpen} onClose={() => setIsSavedPlacesOpen(false)} onSelect={(item) => { }} />
      <CreateTripModal isOpen={isCreateTripModalOpen} onClose={() => setIsCreateTripModalOpen(false)} onCreate={() => {}} />
    </div>
  );
};

export default App;

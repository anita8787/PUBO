
import React, { useState } from 'react';
import { Trip, ItineraryDay, ItinerarySpot } from '../types';
import {
  ArrowLeft, Share2, Settings, ListOrdered,
  Clock, Footprints, Car, Train, Edit3, Calendar,
  Map as MapLucide, PlusCircle, Briefcase, Menu, Plus, ChevronDown, ChevronUp, CheckSquare,
  FileText
} from 'lucide-react';
import PlusModal from './PlusModal';
import CreateTripModal from './CreateTripModal';
import ShareModal from './ShareModal';
import LongImagePreview from './LongImagePreview';

interface ItineraryViewProps {
  trips: Trip[];
  itineraryDays: ItineraryDay[];
  setItineraryDays: React.Dispatch<React.SetStateAction<ItineraryDay[]>>;
  selectedDayIndex: number;
  setSelectedDayIndex: React.Dispatch<React.SetStateAction<number>>;
  onTripSelectionChange?: (isSelected: boolean) => void;
  onAddClick?: () => void;
  onBack?: () => void;
}

const ItineraryView: React.FC<ItineraryViewProps> = ({
  trips,
  itineraryDays = [],
  setItineraryDays,
  selectedDayIndex,
  setSelectedDayIndex,
  onTripSelectionChange,
  onBack
}) => {
  const [selectedTrip, setSelectedTrip] = useState<Trip | null>(null);
  const [viewMode, setViewMode] = useState<'list' | 'map'>('list');
  const [mapSubMode, setMapSubMode] = useState<'overview' | 'daily'>('daily');
  const [isOverviewExpanded, setIsOverviewExpanded] = useState(false);
  const [isConcise, setIsConcise] = useState(false);
  const [isPlusModalOpen, setIsPlusModalOpen] = useState(false);
  const [isCreateTripModalOpen, setIsCreateTripModalOpen] = useState(false);
  const [isShareModalOpen, setIsShareModalOpen] = useState(false);
  const [isLongImageOpen, setIsLongImageOpen] = useState(false);
  const [isMemoEditable, setIsMemoEditable] = useState(false);
  const [activeMemoId, setActiveMemoId] = useState<string | null>(null);

  const [editingSpot, setEditingSpot] = useState<{ dayIdx: number, spotIdx: number, spot: ItinerarySpot, startTime: string, endTime: string } | null>(null);

  const currentDay = itineraryDays[selectedDayIndex] || (itineraryDays.length > 0 ? itineraryDays[0] : null);

  const TransportIcon = ({ type }: { type: 'walk' | 'train' | 'car' }) => {
    switch (type) {
      case 'walk': return <Footprints size={12} />;
      case 'car': return <Car size={12} />;
      case 'train': return <Train size={12} />;
    }
  };

  const calculateStayTime = (start: string, end: string) => {
    try {
      const [sH, sM] = start.split(':').map(Number);
      const [eH, eM] = end.split(':').map(Number);
      const diff = (eH * 60 + eM) - (sH * 60 + sM);
      return diff > 0 ? `${diff}` : '0';
    } catch { return '0'; }
  };

  const handleEditSpot = (dayIdx: number, spotIdx: number, spot: ItinerarySpot) => {
    const times = (spot.time || '11:00').split(' - ');
    setEditingSpot({
      dayIdx, spotIdx, spot: { ...spot },
      startTime: times[0] || '11:00',
      endTime: times[1] || '12:00'
    });
    setIsMemoEditable(false);
  };

  const handleSaveEdit = () => {
    if (!editingSpot) return;
    const newDays = [...itineraryDays];
    const stayTimeNum = calculateStayTime(editingSpot.startTime, editingSpot.endTime);
    const updatedSpot = {
      ...editingSpot.spot,
      time: `${editingSpot.startTime} - ${editingSpot.endTime}`,
      subLabel: `${stayTimeNum}分鐘`
    };
    newDays[editingSpot.dayIdx].spots[editingSpot.spotIdx] = updatedSpot;
    setItineraryDays(newDays);
    setEditingSpot(null);
  };

  const formatDisplayTime = (timeStr: string) => {
    try {
      const [h, m] = timeStr.split(':').map(Number);
      const period = h >= 12 ? '下午' : '上午';
      const displayH = h === 0 ? 12 : (h > 12 ? h - 12 : h);
      return `${period} ${displayH}:${m.toString().padStart(2, '0')}`;
    } catch { return timeStr; }
  };

  const AddItineraryButton = () => (
    <button
      onClick={() => setIsPlusModalOpen(true)}
      className="w-full h-16 border-2 border-dashed border-gray-300 rounded-[1.5rem] flex items-center justify-center gap-2 mt-4 mb-12 hover:bg-gray-50 transition-colors group"
    >
      <div className="w-6 h-6 rounded-full bg-gray-100 flex items-center justify-center group-active:scale-95 transition-transform">
        <Plus size={14} className="text-gray-400" />
      </div>
      <span className="text-xs font-black text-gray-300 uppercase">添加行程</span>
    </button>
  );

  const renderListView = () => (
    <div className="h-screen w-full flex flex-col bg-pubo-yellow font-sans overflow-hidden relative">
      <div className="pt-12 px-6 pb-4 shrink-0">
        <div className="flex items-center justify-between mb-5">
          <button onClick={() => { setSelectedTrip(null); onTripSelectionChange?.(false); }} className="w-10 h-10 bg-pubo-white border-2 border-black rounded-full flex items-center justify-center shadow-retro-sm"><ArrowLeft size={22} className="text-black" /></button>
          <div className="flex gap-3">
            <button onClick={() => setIsShareModalOpen(true)} className="w-10 h-10 bg-pubo-white border-2 border-black rounded-full flex items-center justify-center shadow-retro-sm"><Share2 size={18} /></button>
            <button className="w-10 h-10 bg-pubo-white border-2 border-black rounded-full flex items-center justify-center shadow-retro-sm"><Settings size={18} /></button>
          </div>
        </div>
        <h2 className="text-[2.2rem] font-black text-pubo-navy leading-none mb-2 tracking-tighter uppercase">大阪7日遊 ☁️</h2>
        <div className="flex items-center gap-1.5 px-1 py-1">
          <span className="text-pubo-navy/60 font-bold text-sm tracking-wide">2026/08/20 - 08/26</span>
          <Calendar size={13} className="text-pubo-navy/60" />
        </div>
      </div>
      <div className="px-6 mb-2 flex shrink-0 h-[65px] overflow-hidden">
        <div className="flex gap-3 overflow-x-auto no-scrollbar items-center w-full">
          {itineraryDays.map((day, idx) => (
            <button key={idx} onClick={() => setSelectedDayIndex(idx)} className={`flex flex-col items-center shrink-0 w-[38px] h-[52px] rounded-[19px] border-[2px] transition-all justify-center ${selectedDayIndex === idx ? 'bg-pubo-white border-pubo-navy shadow-[2.5px_2.5px_0px_0px_#023B7E]' : 'border-transparent text-pubo-navy opacity-30'}`}>
              <span className="text-[7px] font-black uppercase leading-none mb-0.5">FEB</span>
              <span className="text-[14px] font-black leading-none">{day.date.split('/')[1]}</span>
            </button>
          ))}
        </div>
      </div>
      <div className="flex-1 bg-pubo-beige rounded-t-[2.5rem] border-t-2 border-pubo-navy relative flex flex-col overflow-hidden">
        <div className="flex-1 overflow-y-auto no-scrollbar px-6 pt-6 pb-48">
          <div className="flex items-center justify-between mb-8 px-1">
            <div className="flex flex-col items-start">
              <div className="px-3 py-1 border border-gray-300 rounded-full mb-1">
                <span className="text-[10px] font-black text-gray-400 tracking-widest leading-none">Day {selectedDayIndex + 1}</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-2xl font-black text-pubo-navy">{currentDay?.date}</span>
                <span className="text-2xl font-black text-pubo-navy">{currentDay?.weekday}</span>
              </div>
            </div>
            <button className="flex items-center gap-1.5 px-4 py-2 bg-pubo-red border-2 border-pubo-red rounded-full shadow-[2.5px_2.5px_0px_0px_#000] active:translate-y-0.5 transition-all group">
              <ListOrdered size={16} className="text-white" strokeWidth={3} />
              <span className="text-[11px] font-black text-white">一鍵排序</span>
            </button>
          </div>
          <div className="space-y-8 relative">
            <div className="absolute left-6 top-4 bottom-32 w-0.5 border-l-2 border-dotted border-gray-300" />
            {currentDay?.spots.map((spot, idx) => (
              <div key={spot.id} className="relative z-10 flex flex-col pl-[2px]">
                <div className="flex items-center">
                  <div className="w-[100px] h-[112px] border-2 border-black rounded-2xl overflow-hidden bg-pubo-white shrink-0 relative z-20"><img src={spot.image} className="w-full h-full object-cover" /></div>
                  <div className="bg-pubo-white border-2 border-l-0 border-black rounded-r-2xl h-[100px] w-[210px] p-4 pl-5 flex flex-col justify-center relative shadow-retro">
                    <button onClick={() => handleEditSpot(selectedDayIndex, idx, spot)} className="absolute top-2 right-2 w-7 h-7 bg-white border border-gray-100 rounded-full flex items-center justify-center text-black/30 shadow-sm active:scale-95 transition-all"><Edit3 size={12} /></button>
                    <div className="mb-1">
                      <span className="inline-block px-2 py-0.5 border border-pubo-red bg-pubo-red/10 text-pubo-red text-[7.5px] font-black rounded-full uppercase tracking-tighter">
                        {spot.time.split(' - ')[0] || "11:00"} 營業
                      </span>
                    </div>
                    <h4 className="text-[1.3rem] font-black text-pubo-navy leading-tight uppercase pr-6 truncate">{spot.name}</h4>
                    <div className="flex items-center gap-1 mt-0.5"><Clock size={12} className="text-gray-400" /><span className="text-[10px] font-black text-gray-400 uppercase">停留{spot.subLabel || '10分鐘'}</span></div>
                  </div>
                </div>

                {/* 直接顯示備忘錄內容 - 改為顯示時間標籤 */}
                {spot.notes && spot.notes.length > 0 && (
                  <div className="mt-2 ml-[42px] mr-2 bg-[#FFF9E1] border-l-[3px] border-pubo-yellow rounded-r-xl p-3 shadow-sm animate-in fade-in slide-in-from-top-1 duration-300">
                    <div className="flex items-center gap-1.5 mb-1 opacity-40">
                      <Clock size={10} className="text-pubo-navy" />
                      <span className="text-[8px] font-black text-pubo-navy uppercase tracking-widest">{spot.time}</span>
                    </div>
                    <p className="text-[11px] font-bold text-pubo-navy/70 leading-relaxed">
                      {spot.notes.join('、')}
                    </p>
                  </div>
                )}

                {idx < currentDay.spots.length - 1 && (
                  <div className="ml-0 my-4 pl-[42px] flex items-center gap-4 text-[10px] font-black text-gray-300 uppercase">
                    <div className="flex items-center gap-2">
                      <TransportIcon type={spot.travelToNext?.type || 'train'} />
                      <span>{spot.travelToNext?.time || '10分鐘'} {spot.travelToNext?.distance || '2.4公里'}</span>
                    </div>
                  </div>
                )}
              </div>
            ))}
            <div className="pl-6"><AddItineraryButton /></div>
          </div>
        </div>
      </div>
      <div className="fixed bottom-10 right-6 z-50 flex flex-col items-center">
        <div className="w-[44px] h-[92px] bg-[#9BB8D9] border border-white/40 rounded-full flex flex-col p-1 gap-1 shadow-2xl">
          <button onClick={() => setViewMode('map')} className={`flex-1 w-full rounded-full flex items-center justify-center transition-all duration-300 ${viewMode === 'map' ? 'bg-pubo-white shadow-md' : ''}`}><MapLucide size={18} className={viewMode === 'map' ? 'text-pubo-navy' : 'text-[#FDF1CA]'} strokeWidth={3} /></button>
          <button onClick={() => setViewMode('list')} className={`flex-1 w-full rounded-full flex items-center justify-center transition-all duration-300 ${viewMode === 'list' ? 'bg-pubo-navy shadow-md' : ''}`}><ListOrdered size={18} className={viewMode === 'list' ? 'text-white' : 'text-pubo-navy'} strokeWidth={3} /></button>
        </div>
      </div>
      {renderEditModal()}
      <ShareModal isOpen={isShareModalOpen} onClose={() => setIsShareModalOpen(false)} onGenerateLongImage={() => setIsLongImageOpen(true)} />
      {isLongImageOpen && selectedTrip && (
        <LongImagePreview trip={selectedTrip} itineraryDays={itineraryDays} onClose={() => setIsLongImageOpen(false)} />
      )}
      <PlusModal isOpen={isPlusModalOpen} onClose={() => setIsPlusModalOpen(false)} onAdd={() => { }} currentTrip={selectedTrip || undefined} />
    </div>
  );

  const renderEditModal = () => editingSpot && (
    <div className="fixed inset-0 z-[120] bg-black/40 backdrop-blur-sm flex items-center justify-center p-6">
      <div className="w-full max-w-[320px] bg-pubo-white border-[3px] border-black rounded-[2.5rem] p-7 shadow-2xl animate-in zoom-in-95">
        <h3 className="text-2xl font-black mb-6 text-pubo-navy uppercase">編輯行程</h3>
        <div className="space-y-6">
          <div className={`rounded-[2rem] p-6 border-2 border-black/5 relative transition-colors duration-300 ${isMemoEditable ? 'bg-gray-100' : 'bg-[#FFF9E1]'}`}>
            <textarea rows={4} readOnly={!isMemoEditable} value={editingSpot.spot.notes?.join('\n')} onChange={e => setEditingSpot({ ...editingSpot, spot: { ...editingSpot.spot, notes: e.target.value.split('\n') } })} className="w-full bg-transparent text-pubo-navy font-bold text-base focus:outline-none no-scrollbar resize-none" placeholder="請輸入行程筆記..." />
            <button onClick={() => setIsMemoEditable(!isMemoEditable)} className={`absolute top-4 right-4 p-1.5 rounded-full ${isMemoEditable ? 'bg-pubo-navy text-white' : 'text-gray-400'}`}><Edit3 size={14} /></button>
          </div>
          <div className="flex items-center gap-3">
            <div className="flex-1 relative h-14 bg-pubo-white border-2 border-black/10 rounded-2xl px-4 flex items-center gap-2 overflow-hidden">
              <Clock size={16} className="text-pubo-navy" /><span className="text-[11px] font-black">{formatDisplayTime(editingSpot.startTime)}</span>
              <input type="time" value={editingSpot.startTime} onChange={e => setEditingSpot({ ...editingSpot, startTime: e.target.value })} className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-20" />
            </div>
            <div className="flex-1 relative h-14 bg-pubo-white border-2 border-black/10 rounded-2xl px-4 flex items-center gap-2 overflow-hidden">
              <Clock size={16} className="text-pubo-navy" /><span className="text-[11px] font-black">{formatDisplayTime(editingSpot.endTime)}</span>
              <input type="time" value={editingSpot.endTime} onChange={e => setEditingSpot({ ...editingSpot, endTime: e.target.value })} className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-20" />
            </div>
          </div>
          <button onClick={handleSaveEdit} className="w-full h-15 bg-pubo-navy text-pubo-white rounded-[1.5rem] font-black text-lg shadow-retro uppercase">儲存變更</button>
        </div>
      </div>
    </div>
  );

  const renderMapView = () => (
    <div className="h-screen w-full relative font-sans overflow-hidden bg-pubo-white">
      {/* Map Layer */}
      <div className="absolute inset-0 z-0 bg-gray-50"><img src="https://lh3.googleusercontent.com/d/1cKI5B7O59vYFhtftmMjCz3bjnaWp-4E3" className="w-full h-full object-cover grayscale opacity-50" /></div>

      {/* Top Floating Controls */}
      <div className="absolute top-12 left-6 right-6 z-40 flex items-center justify-between">
        <button onClick={() => setViewMode('list')} className="w-10 h-10 bg-pubo-white border-2 border-black rounded-full flex items-center justify-center shadow-retro-sm active:translate-y-0.5"><ArrowLeft size={22} className="text-black" /></button>
        <div className="flex gap-3">
          <button onClick={() => setIsShareModalOpen(true)} className="w-10 h-10 bg-pubo-white border-2 border-black rounded-full flex items-center justify-center shadow-retro-sm"><Share2 size={18} /></button>
          <button className="w-10 h-10 bg-pubo-white border-2 border-black rounded-full flex items-center justify-center shadow-retro-sm"><Settings size={18} /></button>
        </div>
      </div>

      {/* Bottom Content Card - SHIFTED UP */}
      <div className="absolute inset-x-0 bottom-0 z-20 flex flex-col items-center">
        <div className={`bg-pubo-white w-full border-t-2 border-black transition-all duration-300 ${isConcise ? 'h-[280px]' : 'h-[68vh]'} rounded-t-[3rem] shadow-[0_-10px_40px_rgba(0,0,0,0.1)] overflow-hidden flex flex-col`}>
          {/* Drag Bar */}
          <div className="h-8 w-full flex items-center justify-center shrink-0 cursor-pointer" onClick={() => setIsConcise(!isConcise)}><div className="w-12 h-1 bg-gray-200 rounded-full" /></div>

          {/* Mode/Day Tabs - ALWAYS VISIBLE */}
          <div className="w-full px-8 py-2 flex gap-6 overflow-x-auto no-scrollbar shrink-0 border-b border-gray-50/50">
            <button onClick={() => setMapSubMode('overview')} className={`text-[13px] font-black whitespace-nowrap transition-all py-2 ${mapSubMode === 'overview' ? 'text-pubo-navy border-b-2 border-pubo-navy' : 'text-gray-300'}`}>總覽</button>
            {itineraryDays.map((day, i) => (
              <button key={i} onClick={() => { setMapSubMode('daily'); setSelectedDayIndex(i); }} className={`text-[13px] font-black whitespace-nowrap transition-all py-2 ${mapSubMode === 'daily' && selectedDayIndex === i ? 'text-pubo-navy border-b-2 border-pubo-navy' : 'text-gray-300'}`}>{day.date} {day.weekday}</button>
            ))}
          </div>

          {/* Content Area */}
          <div className="flex-1 overflow-y-auto no-scrollbar">
            {isConcise ? (
              <div className="flex h-full overflow-x-auto snap-x snap-mandatory no-scrollbar">
                {currentDay?.spots.map((spot, i) => (
                  <div key={i} className="min-w-full snap-start flex flex-col px-8 pt-6">
                    {/* Spot Info Header */}
                    <div className="flex items-start gap-4">
                      <div className="w-[84px] h-[84px] rounded-2xl overflow-hidden shrink-0 border border-gray-100"><img src={spot.image} className="w-full h-full object-cover" /></div>
                      <div className="flex-1 flex flex-col pt-1">
                        <span className="text-[11px] font-black text-gray-300 uppercase tracking-widest mb-1">{spot.category === 'food' ? '美食' : '景點'}</span>
                        <h4 className="text-[22px] font-black text-pubo-navy uppercase leading-tight mb-2 pr-4">{i + 1}. {spot.name}</h4>
                        <div className="flex items-center gap-1.5">
                          <Clock size={12} className="text-pubo-navy" fill="#023B7E" />
                          <span className="text-[12px] font-black text-pubo-navy uppercase tracking-tighter">停留{spot.subLabel || '10分鐘'}</span>
                        </div>
                      </div>
                    </div>

                    {/* Footer Info Row - Centered and lifted up - Horizontal Transport Info */}
                    <div className="flex items-center justify-between w-full mt-6 px-1 pb-16">
                      {/* Left Transport */}
                      <div className="flex-1 flex items-center justify-start gap-2 text-gray-300 font-black text-[10px] uppercase">
                        {i > 0 && (
                          <div className="flex items-center gap-1.5">
                            <TransportIcon type="train" />
                            <span>10分鐘 1.2公里</span>
                          </div>
                        )}
                      </div>

                      {/* Center Index Circle */}
                      <div className="w-9 h-9 bg-pubo-navy text-white rounded-full flex items-center justify-center text-[14px] font-black border-2 border-pubo-navy shadow-retro-sm shrink-0 mx-4">
                        {i + 1}
                      </div>

                      {/* Right Transport */}
                      <div className="flex-1 flex items-center justify-end gap-2 text-gray-300 font-black text-[10px] uppercase">
                        {i < currentDay.spots.length - 1 && (
                          <div className="flex items-center gap-1.5 text-right">
                            <span>10分鐘 2.4公里</span>
                            <TransportIcon type="train" />
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : mapSubMode === 'overview' ? (
              <div className="space-y-4 pt-4 px-8 pb-10">
                {/* Itinerary Overview Box */}
                <div className="bg-gray-50 border-2 border-black rounded-[2.5rem] p-6 shadow-retro-sm">
                  <h3 className="text-xs font-black text-gray-400 mb-4 tracking-widest uppercase">行程概要</h3>
                  <div className="space-y-3">
                    {itineraryDays.slice(0, isOverviewExpanded ? undefined : 2).map((day, idx) => (
                      <div key={idx} className="flex gap-3 text-[11px] font-black">
                        <span className="text-pubo-navy shrink-0">{day.date} {day.weekday.slice(1, 2)} {'>'}</span>
                        <span className="text-gray-400 truncate">{day.spots.map(s => s.name).join(' - ') || '尚未安排'}</span>
                      </div>
                    ))}
                  </div>
                  <button onClick={() => setIsOverviewExpanded(!isOverviewExpanded)} className="text-[10px] font-black text-gray-300 uppercase mt-4 flex items-center gap-1">
                    {isOverviewExpanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />} {isOverviewExpanded ? '展開較少' : '展開全部'}
                  </button>
                </div>

                {/* Luggage List Box */}
                <div className="bg-white border-2 border-pubo-navy rounded-[2.5rem] p-6 shadow-retro-sm">
                  <h3 className="text-xs font-black text-pubo-navy mb-4 tracking-widest uppercase flex items-center gap-2">
                    <Briefcase size={14} className="text-pubo-navy" /> 行李清單
                  </h3>
                  <div className="grid grid-cols-2 gap-3">
                    {['護照正本', '日幣現金', '日本網卡', '感冒藥品'].map((item, idx) => (
                      <div key={idx} className="flex items-center gap-2">
                        <div className="w-4 h-4 border-2 border-pubo-navy rounded flex items-center justify-center shrink-0">
                          {idx === 0 && <Plus size={8} strokeWidth={4} className="text-pubo-navy" />}
                        </div>
                        <span className="text-[11px] font-bold text-pubo-navy">{item}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            ) : (
              <div className="pt-4 px-8 pb-10">
                {currentDay?.spots.map((spot, i) => (
                  <div key={i} className="mb-4">
                    <div className="flex items-center justify-between py-2 cursor-pointer" onClick={() => setActiveMemoId(activeMemoId === spot.id ? null : spot.id)}>
                      <div className="flex items-center gap-4">
                        <div className="w-16 h-16 rounded-xl overflow-hidden shrink-0 border border-gray-100"><img src={spot.image} className="w-full h-full object-cover" /></div>
                        <div className="flex flex-col">
                          <span className="text-[9px] font-black text-gray-400 uppercase tracking-widest mb-0.5">景點</span>
                          <h4 className="text-lg font-black text-pubo-navy leading-tight uppercase">{i + 1}. {spot.name}</h4>
                          <div className="flex items-center gap-1.5 mt-1"><Clock size={10} className="text-pubo-navy" fill="#023B7E" /><span className="text-[11px] font-black text-pubo-navy uppercase">停留{spot.subLabel}</span></div>
                        </div>
                      </div>
                      <button className="w-10 h-10 border-2 border-black rounded-xl flex items-center justify-center shadow-retro-sm bg-pubo-white active:translate-y-0.5"><CheckSquare size={18} className="text-black" /></button>
                    </div>
                    {activeMemoId === spot.id && spot.notes && spot.notes.length > 0 && (
                      <div className="ml-20 mt-2 p-3 bg-[#FFF9E1] rounded-xl border border-pubo-yellow/30 animate-in fade-in slide-in-from-top-1 duration-200">
                        <p className="text-[11px] font-bold text-pubo-navy/70 leading-relaxed">{spot.notes.join('、')}</p>
                      </div>
                    )}
                    {i < currentDay.spots.length - 1 && (
                      <div className="ml-8 border-l-2 border-dashed border-gray-200 h-12 flex flex-col justify-center pl-6">
                        <div className="flex items-center gap-2 text-[10px] font-black text-gray-300 uppercase">
                          <TransportIcon type="train" />
                          <span>10分鐘 2.4公里</span>
                        </div>
                      </div>
                    )}
                  </div>
                ))}
                <AddItineraryButton />
              </div>
            )}
          </div>
        </div>
      </div>

      <ShareModal isOpen={isShareModalOpen} onClose={() => setIsShareModalOpen(false)} onGenerateLongImage={() => setIsLongImageOpen(true)} />
      {isLongImageOpen && selectedTrip && (
        <LongImagePreview trip={selectedTrip} itineraryDays={itineraryDays} onClose={() => setIsLongImageOpen(false)} />
      )}
      <PlusModal isOpen={isPlusModalOpen} onClose={() => setIsPlusModalOpen(false)} onAdd={() => { }} currentTrip={selectedTrip || undefined} />
    </div>
  );

  return (
    <div className="h-full w-full">
      {!selectedTrip ? (
        <div className="h-screen w-full flex flex-col bg-pubo-beige font-sans">
          <div className="pt-12 pb-4 px-6 flex items-center justify-between shrink-0">
            <button onClick={onBack} className="w-10 h-10 bg-pubo-white border-2 border-black rounded-full flex items-center justify-center shadow-retro-sm active:translate-y-0.5"><ArrowLeft size={24} className="text-black" /></button>
            <div className="flex items-center gap-3">
              <button onClick={() => setIsCreateTripModalOpen(true)} className="w-10 h-10 bg-pubo-white border-2 border-pubo-navy rounded-full flex items-center justify-center shadow-[2.5px_2.5px_0px_0px_#023B7E] active:translate-y-0.5 transition-all"><Briefcase size={22} className="text-pubo-navy" strokeWidth={2.5} /></button>
              <button className="h-10 px-5 bg-pubo-white border-2 border-pubo-navy rounded-full flex items-center gap-2 text-pubo-navy text-sm font-black shadow-[2.5px_2.5px_0px_0px_#023B7E] active:translate-y-0.5 transition-all uppercase"><Menu size={18} strokeWidth={3} />排序</button>
            </div>
          </div>
          <div className="flex-1 overflow-y-auto no-scrollbar pb-32 px-6">
            <h1 className="text-4xl font-black text-pubo-navy mb-8 tracking-tighter uppercase">我的行程</h1>
            <div className="flex flex-col relative">
              {trips.map((trip, index) => (
                <div key={trip.id} className="relative group" style={{ marginTop: index === 0 ? 0 : '-75px', zIndex: index + 1 }}>
                  <div onClick={() => { setSelectedTrip(trip); onTripSelectionChange?.(true); }} className={`w-full ${['bg-[#FFC849]', 'bg-[#F5A623]', 'bg-[#E84011]', 'bg-[#D0021B]', 'bg-[#023B7E]'][index % 5]} border-2 border-black rounded-[2.5rem] px-8 py-7 shadow-retro-lg cursor-pointer transition-transform hover:-translate-y-1 relative h-[205px] flex flex-col justify-start`}>
                    <h2 className="text-[2.2rem] font-black text-white tracking-tighter mb-1 uppercase">{trip.title}</h2>
                    <p className="text-white/80 font-bold text-[12px] mb-1">{trip.date}</p>
                    <p className="text-white/60 font-black text-[10px] uppercase">{trip.spots} 個景點</p>
                  </div>
                  <button className="absolute top-6 right-6 z-20 w-10 h-10 bg-pubo-white border-2 border-black rounded-full flex items-center justify-center shadow-retro-sm transition-all active:scale-95"><Share2 size={18} className="text-black" /></button>
                </div>
              ))}
            </div>
          </div>
          <CreateTripModal isOpen={isCreateTripModalOpen} onClose={() => setIsCreateTripModalOpen(false)} onCreate={() => { }} />
        </div>
      ) : (
        viewMode === 'list' ? renderListView() : renderMapView()
      )}
    </div>
  );
};

export default ItineraryView;

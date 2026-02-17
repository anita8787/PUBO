
import React, { useState } from 'react';
import { X, MapPin, Calendar, Users, Sparkles } from 'lucide-react';

interface CreateTripModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCreate: (tripData: any) => void;
}

const CreateTripModal: React.FC<CreateTripModalProps> = ({ isOpen, onClose, onCreate }) => {
  const [name, setName] = useState('');
  const [destination, setDestination] = useState('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [isCoEdit, setIsCoEdit] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onCreate({ name, destination, startDate, endDate, isCoEdit });
    onClose();
  };

  return (
    <>
      {/* Backdrop */}
      <div 
        className="fixed inset-0 z-[110] bg-black/40 backdrop-blur-sm transition-opacity duration-300 animate-in fade-in"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="fixed inset-0 z-[120] flex items-center justify-center p-6 pointer-events-none">
        <div className="w-full max-w-sm bg-white border-[3px] border-black rounded-[2.5rem] shadow-retro-lg p-8 pointer-events-auto animate-in zoom-in-95 duration-300">
          <div className="flex justify-between items-center mb-8">
            <div className="flex items-center gap-2">
              <div className="w-10 h-10 bg-pubo-yellow rounded-full border-2 border-black flex items-center justify-center shadow-retro-sm">
                <Sparkles size={20} className="text-black" />
              </div>
              <h3 className="text-2xl font-black text-pubo-navy">開啟新旅程</h3>
            </div>
            <button onClick={onClose} className="p-2 text-gray-400 hover:text-black transition-colors">
              <X size={24} strokeWidth={3} />
            </button>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Trip Name */}
            <div>
              <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mb-2 pl-1">旅程名稱</label>
              <input 
                type="text" 
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="例如：東京 7 日遊"
                className="w-full h-14 bg-gray-50 border-2 border-black rounded-2xl px-5 font-bold text-lg focus:outline-none focus:ring-2 focus:ring-pubo-yellow transition-all"
                required
              />
            </div>

            {/* Destination */}
            <div>
              <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mb-2 pl-1">目的地</label>
              <div className="relative">
                <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 text-pubo-blue" size={20} />
                <input 
                  type="text" 
                  value={destination}
                  onChange={(e) => setDestination(e.target.value)}
                  placeholder="輸入國家或城市"
                  className="w-full h-14 bg-gray-50 border-2 border-black rounded-2xl pl-12 pr-5 font-bold text-lg focus:outline-none focus:ring-2 focus:ring-pubo-yellow transition-all"
                  required
                />
              </div>
            </div>

            {/* Date Range */}
            <div>
              <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mb-2 pl-1">旅遊時間</label>
              <div className="flex items-center gap-2">
                <div className="flex-1 relative">
                  <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                  <input 
                    type="date" 
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                    className="w-full h-12 bg-gray-50 border-2 border-black rounded-xl pl-10 pr-2 font-bold text-xs focus:outline-none"
                    required
                  />
                </div>
                <span className="text-gray-300 font-bold">~</span>
                <div className="flex-1 relative">
                  <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                  <input 
                    type="date" 
                    value={endDate}
                    onChange={(e) => setEndDate(e.target.value)}
                    className="w-full h-12 bg-gray-50 border-2 border-black rounded-xl pl-10 pr-2 font-bold text-xs focus:outline-none"
                    required
                  />
                </div>
              </div>
            </div>

            {/* Co-edit Toggle */}
            <div className="flex items-center justify-between p-4 bg-pubo-cardBeige border-2 border-dashed border-gray-300 rounded-2xl">
              <div className="flex items-center gap-3">
                <Users size={20} className="text-pubo-blue" />
                <div>
                  <p className="font-black text-sm text-pubo-navy">邀請好友共同編輯</p>
                  <p className="text-[10px] font-bold text-gray-400">與旅伴一起規劃行程</p>
                </div>
              </div>
              <button 
                type="button"
                onClick={() => setIsCoEdit(!isCoEdit)}
                className={`w-12 h-6 rounded-full transition-colors relative flex items-center px-1 ${isCoEdit ? 'bg-pubo-blue' : 'bg-gray-200'}`}
              >
                <div className={`w-4 h-4 bg-white rounded-full transition-transform duration-200 ${isCoEdit ? 'translate-x-6' : 'translate-x-0'}`} />
              </button>
            </div>

            {/* Submit Button */}
            <button 
              type="submit"
              className="w-full h-16 bg-pubo-navy text-white rounded-2xl font-black text-xl shadow-retro active:translate-y-1 active:shadow-none transition-all mt-4"
            >
              出發去！
            </button>
          </form>
        </div>
      </div>
    </>
  );
};

export default CreateTripModal;

import React from 'react';
import { Map, Briefcase, Plus } from 'lucide-react';
import { Tab } from '../types';

interface NavigationProps {
  activeTab: Tab;
  onTabChange: (tab: Tab) => void;
  onPlusClick: () => void;
}

const Navigation: React.FC<NavigationProps> = ({ activeTab, onTabChange, onPlusClick }) => {
  return (
    <div className="fixed bottom-8 left-0 right-0 z-30 flex justify-center pointer-events-none safe-bottom">
      {/* Container - Made shorter (w-[220px]) and retro styled */}
      <div className="bg-white border-2 border-black rounded-full shadow-retro flex items-center justify-between px-6 py-2 pointer-events-auto w-[220px] relative h-16">
        
        {/* Left: Map/Explore */}
        <button 
          onClick={() => onTabChange(Tab.MAP)}
          className={`flex items-center justify-center transition-transform active:scale-95 ${activeTab === Tab.MAP ? 'text-pubo-blue' : 'text-gray-400'}`}
        >
          <Map size={26} strokeWidth={2.5} />
        </button>

        {/* Center: Plus Button - Protrudes half way out (-top-8 aligns center to top edge roughly) */}
        <div className="absolute left-1/2 -translate-x-1/2 -top-8">
          <button 
            onClick={onPlusClick}
            className="w-16 h-16 bg-pubo-yellow rounded-full border-2 border-black shadow-retro flex items-center justify-center transition-transform active:translate-y-1 active:shadow-none"
          >
            <Plus size={36} strokeWidth={3} className="text-black" />
          </button>
        </div>

        {/* Right: Itinerary/Suitcase */}
        <button 
          onClick={() => onTabChange(Tab.ITINERARY)}
          className={`flex items-center justify-center transition-transform active:scale-95 ${activeTab === Tab.ITINERARY ? 'text-pubo-orange' : 'text-gray-400'}`}
        >
          <Briefcase size={26} strokeWidth={2.5} />
        </button>

      </div>
    </div>
  );
};

export default Navigation;
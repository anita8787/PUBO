import React, { useState, useEffect } from 'react';
import { Activity, Trash2, X, Timer, Zap, History } from 'lucide-react';
import { getPerformanceLogs, clearPerformanceLogs, PerformanceLog } from '../services/performanceTracker';

const PerformanceMonitor: React.FC = () => {
  const [isOpen, setIsOpen] = useState(false);
  const [logs, setLogs] = useState<PerformanceLog[]>([]);

  useEffect(() => {
    const handleUpdate = () => {
      setLogs(getPerformanceLogs());
    };

    const handleOpen = () => {
      setIsOpen(true);
    };

    handleUpdate(); // Initial load
    window.addEventListener('pubo_performance_updated', handleUpdate);
    window.addEventListener('pubo_open_performance', handleOpen);
    return () => {
      window.removeEventListener('pubo_performance_updated', handleUpdate);
      window.removeEventListener('pubo_open_performance', handleOpen);
    };
  }, []);

  const handleClear = () => {
    if (window.confirm('確定要清除所有計時器記錄嗎？')) {
      clearPerformanceLogs();
    }
  };

  const activeLogs = logs.filter(l => l.status === 'success');
  const avgDuration = activeLogs.length > 0 
    ? (activeLogs.reduce((sum, log) => sum + log.duration, 0) / activeLogs.length).toFixed(2)
    : '0.00';

  const minDuration = activeLogs.length > 0
    ? Math.min(...activeLogs.map(l => l.duration)).toFixed(2)
    : '0.00';

  if (!isOpen) {
    return (
      <button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-24 right-6 z-[90] w-12 h-12 bg-pubo-cardYellow hover:bg-yellow-400 border-[2.5px] border-pubo-navy rounded-full flex items-center justify-center text-pubo-navy shadow-[2px_2px_0px_0px_#203B93] active:translate-y-0.5 active:shadow-none transition-all"
        title="效能計時器"
      >
        <Timer size={22} className="animate-pulse" />
      </button>
    );
  }

  return (
    <>
      <div 
        className="fixed inset-0 z-[140] bg-black/40 backdrop-blur-sm transition-opacity duration-300"
        onClick={() => setIsOpen(false)}
      />
      <div className="fixed inset-x-6 top-1/2 -translate-y-1/2 z-[150] max-w-md mx-auto bg-white border-[3px] border-pubo-navy rounded-[1.8rem] shadow-[6px_6px_0px_0px_#203B93] overflow-hidden animate-in zoom-in-95 duration-200">
        
        {/* Header */}
        <div className="bg-pubo-navy text-white px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Activity className="text-pubo-cardYellow animate-pulse" size={20} />
            <span className="font-black text-lg tracking-tight uppercase">PUBO 分析計時與優化器</span>
          </div>
          <button 
            onClick={() => setIsOpen(false)}
            className="w-7 h-7 rounded-full bg-white/10 flex items-center justify-center hover:bg-white/20 active:scale-90 transition-all"
          >
            <X size={16} />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-5">
          {/* Stats Grid */}
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-blue-50 border-[2.5px] border-pubo-blue rounded-2xl p-4 flex flex-col items-center justify-center">
              <Zap size={24} className="text-pubo-blue mb-1" />
              <span className="text-xs font-bold text-black/50">平均分析時間</span>
              <span className="text-2xl font-black text-pubo-blue mt-1">{avgDuration}s</span>
            </div>
            <div className="bg-green-50 border-[2.5px] border-green-600 rounded-2xl p-4 flex flex-col items-center justify-center">
              <Timer size={24} className="text-green-600 mb-1" />
              <span className="text-xs font-bold text-black/50">最快分析時間</span>
              <span className="text-2xl font-black text-green-600 mt-1">{minDuration}s</span>
            </div>
          </div>

          {/* Title */}
          <div className="flex items-center justify-between border-b-2 border-dashed border-pubo-navy/20 pb-2">
            <div className="flex items-center gap-1.5 font-black text-pubo-navy">
              <History size={18} />
              <span>最近的分析紀錄 ({logs.length})</span>
            </div>
            {logs.length > 0 && (
              <button 
                onClick={handleClear}
                className="text-red-500 hover:text-red-700 flex items-center gap-1 text-xs font-bold transition-colors"
              >
                <Trash2 size={14} />
                <span>清除記錄</span>
              </button>
            )}
          </div>

          {/* History List */}
          <div className="max-h-[220px] overflow-y-auto space-y-2.5 pr-1 no-scrollbar">
            {logs.length === 0 ? (
              <div className="text-center py-8 text-sm font-bold text-black/30">
                尚未有分析紀錄。<br />
                請點擊首頁「智能導入」進行分析！
              </div>
            ) : (
              logs.map((log) => (
                <div 
                  key={log.id} 
                  className={`flex justify-between items-center px-4 py-3 border-[2px] rounded-xl transition-all ${
                    log.status === 'success' 
                      ? 'border-pubo-navy bg-white hover:bg-pubo-navy/5' 
                      : 'border-pubo-red bg-red-50'
                  }`}
                >
                  <div className="flex flex-col">
                    <span className="text-xs font-black text-pubo-navy">{log.timestamp}</span>
                    <span className="text-[10px] font-bold text-black/40 mt-0.5">
                      輸入長度: {log.inputLength} 字
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`text-[10px] font-black uppercase px-2 py-0.5 rounded-md border ${
                      log.status === 'success' 
                        ? 'border-pubo-blue text-pubo-blue bg-blue-50' 
                        : 'border-pubo-red text-pubo-red bg-red-100'
                    }`}>
                      {log.status}
                    </span>
                    <span className="text-md font-black text-pubo-navy">
                      {log.duration.toFixed(2)}s
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="bg-pubo-bg border-t-2 border-pubo-navy px-6 py-3 text-center">
          <span className="text-[10px] font-bold text-black/40">
            提示：您可以使用此面板監控優化效果，隨時掌握載入效能！
          </span>
        </div>
      </div>
    </>
  );
};

export default PerformanceMonitor;

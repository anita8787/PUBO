export interface PerformanceLog {
  id: string;
  timestamp: string;
  duration: number; // in seconds
  status: 'success' | 'failure';
  inputLength: number;
}

const STORAGE_KEY = 'pubo_analysis_performance_logs';

export const savePerformanceLog = (duration: number, status: 'success' | 'failure', inputLength: number): PerformanceLog => {
  const logs = getPerformanceLogs();
  const newLog: PerformanceLog = {
    id: Math.random().toString(36).substring(2, 9),
    timestamp: new Date().toLocaleTimeString(),
    duration,
    status,
    inputLength,
  };
  
  logs.unshift(newLog);
  // Keep only the last 20 logs
  if (logs.length > 20) {
    logs.pop();
  }
  
  localStorage.setItem(STORAGE_KEY, JSON.stringify(logs));
  
  // Custom event to notify UI components of the new log
  window.dispatchEvent(new CustomEvent('pubo_performance_updated'));
  
  return newLog;
};

export const getPerformanceLogs = (): PerformanceLog[] => {
  try {
    const data = localStorage.getItem(STORAGE_KEY);
    return data ? JSON.parse(data) : [];
  } catch (e) {
    return [];
  }
};

export const clearPerformanceLogs = () => {
  localStorage.removeItem(STORAGE_KEY);
  window.dispatchEvent(new CustomEvent('pubo_performance_updated'));
};

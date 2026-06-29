import { GoogleGenAI, Type } from "@google/genai";
import { savePerformanceLog } from "./performanceTracker";

// Helper function to extract travel content using Gemini 3 Flash
export const parseTravelContent = async (text: string) => {
  const startTime = performance.now();
  console.log("[Gemini Analysis] Starting analysis...");
  try {
    // Re-initialize GoogleGenAI right before the API call to ensure use of the most current API key
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: "gemini-3-flash-preview",
      contents: `Extract travel locations, shop names, or points of interest from the following text. 
      Return a JSON object with a list of locations.
      
      Text: "${text}"`,
      config: {
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            locations: {
              type: Type.ARRAY,
              items: {
                type: Type.OBJECT,
                properties: {
                  name: { type: Type.STRING, description: "Name of the place" },
                  type: { type: Type.STRING, description: "Type of place (e.g., Restaurant, Park, Museum)" },
                  description: { type: Type.STRING, description: "Brief description based on context" },
                },
                required: ["name", "type"]
              }
            }
          }
        }
      }
    });
    
    const endTime = performance.now();
    const duration = parseFloat(((endTime - startTime) / 1000).toFixed(2));
    console.log(`[Gemini Analysis] Analysis completed in ${duration} seconds.`);
    savePerformanceLog(duration, 'success', text.length);
    
    // Access the .text property directly to get the generated content
    return {
      ...JSON.parse(response.text || '{"locations": []}'),
      analysisDuration: duration
    };
  } catch (error) {
    const endTime = performance.now();
    const duration = parseFloat(((endTime - startTime) / 1000).toFixed(2));
    console.error(`[Gemini Analysis] Error parsing travel content after ${duration} seconds:`, error);
    savePerformanceLog(duration, 'failure', text.length);
    return { locations: [], analysisDuration: duration };
  }
};
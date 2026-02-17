import { GoogleGenAI, Type } from "@google/genai";

// Helper function to extract travel content using Gemini 3 Flash
export const parseTravelContent = async (text: string) => {
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
    
    // Access the .text property directly to get the generated content
    return JSON.parse(response.text || '{"locations": []}');
  } catch (error) {
    console.error("Error parsing travel content:", error);
    return { locations: [] };
  }
};
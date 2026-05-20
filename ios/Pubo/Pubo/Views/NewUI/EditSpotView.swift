//
//  EditSpotView.swift
//  Pubo
//
//  Created by Anita on 2026/2/13.
//

import SwiftUI

struct EditSpotView: View {
    @Environment(\.dismiss) var dismiss
    
    @State var spot: ItinerarySpot
    var onSave: (ItinerarySpot) -> Void
    var onDelete: (() -> Void)?
    
    // Time State
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    
    // Memo text as a single string for proper multi-line editing
    @State private var memoText: String = ""
    @FocusState private var isMemoFocused: Bool
    @State private var isEditingMemo: Bool = false
    
    // Teal color used in the design
    let tealColor = Color(hex: "00A5A5")
    let lightTealColor = Color(hex: "D0EBEB")
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            VStack(spacing: 0) {
                // Header (Orange/Red)
                HStack {
                    Spacer()
                    Text("編輯備忘錄")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .overlay(
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                )
                .padding()
                .background(PuboColors.red) // Use standard red/orange from PuboColors
                
                // Body Content (White)
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Memo Pad Area
                    ZStack(alignment: .bottomTrailing) {
                        ZStack(alignment: .topLeading) {
                            if memoText.isEmpty {
                                Text("在這裡輸入備忘錄...")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(16)
                            }
                            
                            TextEditor(text: $memoText)
                                .focused($isMemoFocused)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 180)
                                .padding(12)
                                .disabled(!isEditingMemo)
                        }
                        
                        // Pen Icon at bottom right
                        Button(action: {
                            isEditingMemo = true
                            isMemoFocused = true
                        }) {
                            Image(systemName: "pencil") // Use standard pencil, no rotation needed
                                .foregroundColor(isEditingMemo ? PuboColors.red : .gray.opacity(0.6))
                                .font(.system(size: 20))
                                .padding(12)
                        }
                    }
                    .background(Color(hex: "FFF9E1"))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(PuboColors.cardYellow, lineWidth: 1.5))
                    
                    // How long to stay section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("要待多久")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(PuboColors.navy)
                        
                        // Time Pickers
                        HStack(spacing: 12) {
                            // Start Time
                            VStack(spacing: 4) {
                                Text("開始")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(tealColor)
                                
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(tealColor, lineWidth: 2))
                            }
                            
                            // Divider line
                            Rectangle()
                                .fill(tealColor)
                                .frame(width: 20, height: 2)
                                .padding(.top, 20)
                            
                            // End Time
                            VStack(spacing: 4) {
                                Text("結束")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(tealColor)
                                
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(tealColor, lineWidth: 2))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Calculated Duration Pill
                        HStack {
                            Image(systemName: "hourglass")
                            Text("停留\(calculateDuration())")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PuboColors.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(lightTealColor)
                        .cornerRadius(12)
                    }
                    
                    Spacer().frame(height: 10)
                    
                    // Save Button
                    Button(action: {
                        spot.time = formatTime(startTime)
                        spot.stayDuration = calculateDuration()
                        // Convert memoText back to notes array
                        let lines = memoText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        spot.notes = lines.isEmpty ? nil : lines
                        
                        onSave(spot)
                        dismiss()
                    }) {
                        Text("儲存變更")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PuboColors.navy)
                            .cornerRadius(24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(24)
                .background(Color.white)
            }
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(PuboColors.red, lineWidth: 2)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 60)
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        }
        .onAppear {
            memoText = spot.notes?.joined(separator: "\n") ?? ""
            // We could optionally parse existing start time from spot.time if it's not nil
            // For now, it stays with current functionality where it defaults to now
        }
        .onChange(of: isMemoFocused) { oldValue, newValue in
            if !newValue {
                isEditingMemo = false
            }
        }
    }
    
    func calculateDuration() -> String {
        let diff = endTime.timeIntervalSince(startTime)
        if diff < 0 { return "0分鐘" }
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小時\(minutes > 0 ? " \(minutes)分鐘" : "")"
        } else {
            return "\(minutes)分鐘"
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

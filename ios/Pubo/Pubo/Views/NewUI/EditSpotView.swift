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
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("編輯行程")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(PuboColors.navy)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(PuboColors.navy)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Memo Area
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("要逛的店/備忘錄")
                                    .font(.headline)
                                    .foregroundColor(PuboColors.navy)
                                Spacer()
                                Button(action: {
                                    isMemoFocused = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            ZStack(alignment: .topLeading) {
                                if memoText.isEmpty {
                                    Text("拍照打卡\n買伴手禮...")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(16)
                                }
                                
                                TextEditor(text: $memoText)
                                    .focused($isMemoFocused)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 120)
                                    .padding(12)
                            }
                            .background(Color(hex: "FFF9E1"))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(PuboColors.cardYellow, lineWidth: 2))
                        }
                        
                        Divider()
                        
                        // Time Range Pickers
                        HStack(spacing: 12) {
                            VStack(spacing: 4) {
                                Text("開始")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .paddingHorizontal()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            }
                            
                            Text("-")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .padding(.top, 16)
                            
                            VStack(spacing: 4) {
                                Text("結束")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .paddingHorizontal()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Calculated Duration
                        HStack {
                            Image(systemName: "hourglass")
                            Text("停留 \(calculateDuration())")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PuboColors.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(PuboColors.navy.opacity(0.1))
                        .cornerRadius(8)

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
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(PuboColors.navy)
                                .cornerRadius(30)
                                .shadow(color: PuboColors.navy.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        
                        if let onDelete = onDelete {
                            Button(action: {
                                onDelete()
                                dismiss()
                            }) {
                                Text("刪除此行程")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(24)
                }
            }
            .background(Color.white)
            .cornerRadius(24)
            .padding(.horizontal, 24)
            .padding(.vertical, 60)
            .shadow(color: .black.opacity(0.2), radius: 20)
        }
        .onAppear {
            // Initialize memo text from notes array
            memoText = spot.notes?.joined(separator: "\n") ?? ""
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

extension View {
    func paddingHorizontal() -> some View {
        self.padding(.horizontal, 12).padding(.vertical, 8)
    }
}

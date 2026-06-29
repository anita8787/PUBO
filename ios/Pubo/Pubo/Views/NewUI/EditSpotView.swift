//
//  EditSpotView.swift
//  Pubo
//
//  Created by Anita on 2026/2/13.
//

import SwiftUI
import PhotosUI

struct EditSpotView: View {
    var onDismiss: () -> Void
    
    @State var spot: ItinerarySpot
    var onSave: (ItinerarySpot) -> Void
    var onDelete: (() -> Void)?
    
    // Time State
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    
    // Memo text as a single string for proper multi-line editing
    @State private var memoText: String = ""
    @State private var spotNameText: String = ""
    @FocusState private var isMemoFocused: Bool
    @FocusState private var isNameFocused: Bool
    @State private var isEditingMemo: Bool = false
    
    // Photo Picker State
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    struct CroppableImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    @State private var cropperImage: CroppableImage? = nil
    @State private var isUploadingPhoto = false
    @State private var photoUploadError: String? = nil
    
    // Teal color used in the design
    let tealColor = Color(hex: "00A5A5")
    let lightTealColor = Color(hex: "D0EBEB")
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture {
                    if isMemoFocused || isEditingMemo || isNameFocused {
                        isMemoFocused = false
                        isNameFocused = false
                        isEditingMemo = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } else {
                        onDismiss()
                    }
                }
            
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
                        Button(action: { onDismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                )
                .padding()
                .background(PuboColors.red) // Use standard red/orange from PuboColors
                
                // Scrollable Body Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Spot Name Edit Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("景點名稱")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(PuboColors.navy.opacity(0.7))
                            
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(PuboColors.red)
                                    .font(.system(size: 16))
                                TextField("輸入景點名稱", text: $spotNameText)
                                    .font(.system(size: 16, weight: .bold))
                                    .focused($isNameFocused)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isNameFocused ? PuboColors.red : Color.gray.opacity(0.25), lineWidth: isNameFocused ? 2 : 1.5))
                        }
                        
                        // Memo Pad Area
                        ZStack(alignment: .topLeading) {
                            if memoText.isEmpty {
                                Text("在這裡輸入備忘錄...")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(16)
                            }
                            
                            TextEditor(text: $memoText)
                                .focused($isMemoFocused)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 200)
                                .padding(12)
                        }
                        .background(PuboColors.beige)
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
                        
                        // 景點照片 section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("景點照片")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(PuboColors.navy)
                            
                            HStack(spacing: 16) {
                                if let imageUrl = spot.imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3)))
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 24))
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                                        HStack {
                                            if isUploadingPhoto {
                                                ProgressView().tint(.white)
                                            } else {
                                                Image(systemName: "square.and.arrow.up")
                                                    .font(.system(size: 14, weight: .bold))
                                            }
                                            Text(isUploadingPhoto ? "正在上傳..." : "上傳自訂照片")
                                                .font(.system(size: 13, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(isUploadingPhoto ? Color.gray : tealColor)
                                        .cornerRadius(20)
                                    }
                                    .disabled(isUploadingPhoto)
                                    .onChange(of: selectedPhotoItem) { _, newItem in
                                        if let newItem = newItem {
                                            handlePhotoSelection(item: newItem)
                                        }
                                    }
                                    
                                    if let err = photoUploadError {
                                        Text(err)
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                            .lineLimit(2)
                                    } else {
                                        Text("您可以上傳此景點的專屬照片，覆蓋預設的社群封面圖。")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
                .background(Color.white)
                .onTapGesture {
                    isMemoFocused = false
                    isNameFocused = false
                    isEditingMemo = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                
                // Fixed Bottom Save Button
                VStack(spacing: 0) {
                    Divider()
                    Button(action: {
                        // Update name if changed
                        let trimmedName = spotNameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedName.isEmpty {
                            spot.name = trimmedName
                        }
                        spot.time = formatTime(startTime)
                        spot.stayDuration = calculateDuration()
                        // Convert memoText back to notes array
                        let lines = memoText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        spot.notes = lines.isEmpty ? nil : lines
                        
                        onSave(spot)
                        onDismiss()
                    }) {
                        Text("儲存變更")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PuboColors.navy)
                            .cornerRadius(24)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
                .background(Color.white)
            }
            .background(Color.white)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(PuboColors.red, lineWidth: 2)
            )
            .frame(height: 590) // Taller modal to fit name field + duration
            .padding(.horizontal, 36) // Narrower width
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            memoText = spot.notes?.joined(separator: "\n") ?? ""
            spotNameText = spot.name
            
            // Parse existing start time from spot.startTime or spot.time if available
            var start = Date()
            let timeToParse = spot.startTime ?? spot.time
            if !timeToParse.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                if let parsedDate = formatter.date(from: timeToParse) {
                    let calendar = Calendar.current
                    var components = calendar.dateComponents([.year, .month, .day], from: start)
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedDate)
                    components.hour = timeComponents.hour
                    components.minute = timeComponents.minute
                    if let finalDate = calendar.date(from: components) {
                        start = finalDate
                    }
                }
            }
            self.startTime = start
            
            // Parse existing stay duration from spot.stayDuration if available
            var durationSeconds: TimeInterval = 3600 // Default to 1 hour
            if let durationStr = spot.stayDuration, !durationStr.isEmpty {
                var totalMinutes = 0
                if let hourRange = durationStr.range(of: "小時") {
                    let hourPart = durationStr[..<hourRange.lowerBound].trimmingCharacters(in: .whitespaces)
                    if let hours = Int(hourPart) {
                        totalMinutes += hours * 60
                    }
                    let restPart = durationStr[hourRange.upperBound...]
                    if let minuteRange = restPart.range(of: "分鐘") {
                        let minutePart = restPart[..<minuteRange.lowerBound].trimmingCharacters(in: .whitespaces)
                        if let minutes = Int(minutePart) {
                            totalMinutes += minutes
                        }
                    }
                } else if let minuteRange = durationStr.range(of: "分鐘") {
                    let minutePart = durationStr[..<minuteRange.lowerBound].trimmingCharacters(in: .whitespaces)
                    if let minutes = Int(minutePart) {
                        totalMinutes += minutes
                    }
                }
                
                if totalMinutes > 0 {
                    durationSeconds = TimeInterval(totalMinutes * 60)
                }
            }
            self.endTime = start.addingTimeInterval(durationSeconds)
        }
        .onChange(of: isMemoFocused) { oldValue, newValue in
            if !newValue {
                isEditingMemo = false
            }
        }
        .onChange(of: isNameFocused) { _, _ in }
        .fullScreenCover(item: $cropperImage) { item in
            ImageCropperView(
                image: item.image,
                onCrop: { cropped in
                    cropperImage = nil
                    handleCroppedPhotoUpload(image: cropped)
                },
                onCancel: {
                    cropperImage = nil
                    selectedPhotoItem = nil
                }
            )
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
    
    private func handlePhotoSelection(item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                await MainActor.run {
                    // Add delay so PhotosPicker can fully dismiss before presenting fullScreenCover
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.cropperImage = CroppableImage(image: image)
                    }
                }
            } else {
                await MainActor.run {
                    self.photoUploadError = "無法讀取照片"
                    self.selectedPhotoItem = nil
                }
            }
        }
    }

    private func handleCroppedPhotoUpload(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            self.photoUploadError = "圖片處理失敗"
            return
        }
        
        isUploadingPhoto = true
        photoUploadError = nil
        
        Task {
            do {
                // Call our new API endpoint via DataService
                let uploadedUrl = try await DataService.shared.uploadImage(imageData: data)
                
                await MainActor.run {
                    self.spot.imageUrl = uploadedUrl // Update locally!
                    self.isUploadingPhoto = false
                    self.selectedPhotoItem = nil
                    print("✅ Spot photo uploaded successfully: \(uploadedUrl)")
                }
            } catch {
                await MainActor.run {
                    self.photoUploadError = "上傳失敗: \(error.localizedDescription)"
                    self.isUploadingPhoto = false
                    self.selectedPhotoItem = nil
                }
            }
        }
    }
}

import SwiftUI

struct TripSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tripManager: TripManager
    
    let tripId: String
    
    // Local State for editing
    @State private var title: String = ""
    @State private var destination: String = ""
    @State private var transportMode: String = ""
    @State private var showDeleteAlert = false
    
    var trip: Trip? {
        tripManager.trips.first(where: { $0.id == tripId })
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea() // System Grouped Background
                
                if let trip = trip {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // 1. Cover Image Section
                            ZStack(alignment: .bottomTrailing) {
                                AsyncImage(url: URL(string: trip.coverImage)) { image in
                                    image.resizable()
                                         .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                
                                // Change Cover Button overlay
                                Button(action: {
                                    // Todo: Image Picker
                                }) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                .padding(12)
                            }
                            
                            // 2. Settings Form
                            VStack(spacing: 0) {
                                // Name
                                SettingRow(title: "名稱") {
                                    TextField("行程名稱", text: $title)
                                        .multilineTextAlignment(.leading) // Left align
                                }
                                Divider()
                                
                                // Permissions (Mock)
                                SettingRow(title: "權限設置") {
                                    HStack {
                                        Image(systemName: "lock.fill").font(.caption).foregroundColor(.gray)
                                        Text("受邀者可見").foregroundColor(.gray)
                                        Spacer()
                                        Button("修改") {
                                            // Action
                                        }.font(.caption).foregroundColor(.blue)
                                    }
                                }
                                Divider()
                                
                                // Date (Read Only or Jump to Calendar)
                                SettingRow(title: "週期") {
                                    HStack {
                                        Text(trip.date)
                                            .font(.system(size: 16, weight: .bold))
                                        Spacer()
                                        Button("修改") {
                                            // Action
                                        }.font(.caption).foregroundColor(.blue)
                                    }
                                }
                                Divider()
                                
                                // Destination
                                SettingRow(title: "起點展示/目的地") {
                                    TextField("輸入目的地", text: $destination)
                                        .multilineTextAlignment(.leading) // Left align
                                }
                                Divider()
                                
                                // Transport
                                SettingRow(title: "交通偏好") {
                                    TextField("例如：駕車 + 步行", text: $transportMode)
                                        .multilineTextAlignment(.leading) // Left align
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            
                            // 3. Members Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("成員管理")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 16)
                                
                                VStack(spacing: 0) {
                                    ForEach(trip.members ?? []) { member in
                                        HStack(spacing: 12) {
                                            // Avatar
                                            AsyncImage(url: URL(string: member.avatar)) { img in
                                                img.resizable().aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Color.gray
                                            }
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                            
                                            Text(member.name)
                                                .font(.body)
                                            
                                            Spacer()
                                            
                                            if member.isOwner {
                                                Text("擁有者")
                                                    .font(.caption)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.gray.opacity(0.1))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .padding(16)
                                        
                                        if member.id != (trip.members?.last?.id ?? "") {
                                            Divider().padding(.leading, 68)
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Add Member Button
                                    Button(action: {}) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(PuboColors.navy)
                                            Text("邀請成員")
                                                .foregroundColor(PuboColors.navy)
                                            Spacer()
                                        }
                                        .padding(16)
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }
                            
                            // 4. Delete Section
                            Button(action: { showDeleteAlert = true }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("刪除旅行")
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 40)
                        }
                    } // End ScrollView
                }
            }
            .navigationTitle("行程設置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(PuboColors.navy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(PuboColors.navy.opacity(0.1))
                    .cornerRadius(16)
                }
            }
            .onAppear {
                if let t = trip {
                    self.title = t.title
                    self.destination = t.destination ?? ""
                    self.transportMode = t.transportMode ?? ""
                }
            }
            .alert("確定要刪除行程嗎？", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("刪除", role: .destructive) {
                    // Call delete logic
                    tripManager.deleteTrip(id: tripId)
                    dismiss()
                }
            } message: {
                Text("此操作無法復原。")
            }
        }
    }
    
    private func saveChanges() {
        // Update Trip Manager
        tripManager.updateTripSettings(
            tripId: tripId,
            title: title,
            destination: destination,
            transportMode: transportMode
        )
    }
}

// Helper View for reusable rows
struct SettingRow<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            content
                .frame(maxWidth: .infinity, alignment: .leading) // Ensure content aligns left
        }
        .padding(16)
    }
}

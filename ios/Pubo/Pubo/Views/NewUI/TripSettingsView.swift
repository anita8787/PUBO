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
    
    // External states for Modals
    @State private var showCalendarModal = false
    @State private var showPermissionDialog = false
    @State private var selectedPermission: String = "僅受邀者可見"
    @State private var isShareSheetPresented = false
    
    var trip: Trip? {
        tripManager.trips.first(where: { $0.id == tripId })
    }
    
    var body: some View {
        ZStack {
            Color(hex: "FDFAEE").ignoresSafeArea() // Brand Beige background
            
            if let trip = trip {
                VStack(spacing: 0) {
                    // Custom Header Bar with Red Bottom Line
                    settingsHeader
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // 2. Settings Form Card
                            settingsFormCard(trip: trip)
                                .padding(.top, 36)
                            
                            // 3. Members Section
                            membersSection(trip: trip)
                            
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
                    }
                }
                
                // Calendar Overlay
                if showCalendarModal {
                    Color.black.opacity(0.3).ignoresSafeArea()
                        .onTapGesture { showCalendarModal = false }
                    
                    CalendarView(
                        isPresented: $showCalendarModal,
                        initialStartDate: parseStartDate(trip.date),
                        initialEndDate: parseEndDate(trip.date),
                        onConfirm: { start, end in
                            tripManager.updateTripDates(tripId: tripId, newStartDate: start, newEndDate: end)
                            withAnimation { showCalendarModal = false }
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        // Wrap the entire view with a red border on top/sides
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(PuboColors.red, lineWidth: 3)
                .padding(1.5) // Prevents the stroke from being clipped at the edges
        )
        .ignoresSafeArea(.all, edges: .bottom)
        .presentationBackground(.clear)
        .presentationDetents([.fraction(0.85)]) // Height increased from 0.65
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
                tripManager.deleteTrip(id: tripId)
                dismiss()
            }
        } message: {
            Text("此操作無法復原。")
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let trip = trip {
                InviteMemberSheet(trip: trip)
            }
        }
    }
    
    // MARK: - Invite Member Sheet
    struct InviteMemberSheet: View {
        let trip: Trip
        @Environment(\.dismiss) var dismiss
        @State private var showCopyToast = false

        var body: some View {
            ZStack {
                VStack(spacing: 24) {
                    // Header
                HStack {
                    Text("邀請成員")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(PuboColors.navy)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.5))
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 24)

                // Illustration or Icon
                ZStack {
                    Circle()
                        .fill(PuboColors.yellow.opacity(0.2))
                        .frame(width: 100, height: 100)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40))
                        .foregroundColor(PuboColors.navy)
                }

                // Invite Code Section
                VStack(spacing: 12) {
                    Text("您的行程邀請碼")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)

                    if let inviteCode = trip.inviteCode {
                        HStack(spacing: 16) {
                            Text(inviteCode)
                                .font(.system(size: 32, weight: .black, design: .monospaced))
                                .foregroundColor(PuboColors.navy)
                                .tracking(4)

                            Button(action: {
                                copyInviteCode(inviteCode)
                            }) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(PuboColors.navy)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                    } else {
                        Text("尚未生成邀請碼")
                            .foregroundColor(.gray)
                    }
                }

                Text("您可以分享此邀請碼給朋友，讓他們加入行程並共同編輯。")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Share Button
                Button(action: {
                    shareCode()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享邀請碼")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(PuboColors.navy)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .retroShadow(color: .black.opacity(0.2), offset: 3)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            
            // Toast Overlay at the very top of ZStack
            if showCopyToast {
                VStack {
                    Spacer()
                    Text("已複製邀請碼")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                        .padding(.bottom, 120)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(100)
            }
        }
        .background(Color.white)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.white)
    }

        private func copyInviteCode(_ code: String) {
            UIPasteboard.general.string = code
            withAnimation { showCopyToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showCopyToast = false }
            }
        }

        private func shareCode() {
            guard let inviteCode = trip.inviteCode else { return }
            let text = "快來和我一起在 Pubo 規劃「\(trip.title)」！\n使用 Pubo App 輸入邀請碼加入：\(inviteCode)"
            let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(av, animated: true)
            }
        }
    }
    
    // MARK: - Custom Header Bar (White with Red Bottom Border)
    private var settingsHeader: some View {
        VStack(spacing: 0) {
            ZStack {
                // Centered Title
                Text("行程設定")
                    .font(.system(size: 19, weight: .bold)) // Font size increased by 2
                    .foregroundColor(PuboColors.navy)
                    
                HStack {
                    // X Close Button
                    Button(action: { dismiss() }) {
                        Image("x")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                    }
                    .buttonStyle(CloseButtonStyle())
                    
                    Spacer()
                    
                    // 保存 Button
                    Button(action: {
                        saveChanges()
                        dismiss()
                    }) {
                        Text("保存")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(PuboColors.navy)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(PuboColors.navy, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            
            // Red divider line
            Rectangle()
                .fill(PuboColors.red)
                .frame(height: 2)
        }
    }
    
    // MARK: - Cover Image
    private func coverImageSection(trip: Trip) -> some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: URL(string: trip.coverImage)) { image in
                image.resizable()
                     .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.15)
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(16)
            
            // Camera Button
            Button(action: {
                // Todo: Image Picker
            }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(PuboColors.navy)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
            .padding(12)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Settings Form Card
    private func settingsFormCard(trip: Trip) -> some View {
        VStack(spacing: 0) {
            // Name
            SettingRow(title: "名稱") {
                TextField("行程名稱", text: $title)
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.leading)
            }
            Divider().padding(.horizontal, 16)
            
            // Permissions
            SettingRow(title: "權限設置") {
                HStack {
                    Text(selectedPermission)
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button("修改") {
                        showPermissionDialog = true
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "2AA5A0")) // Teal
                }
                .confirmationDialog("更改權限設置", isPresented: $showPermissionDialog, titleVisibility: .visible) {
                    Button("僅受邀者可見") { selectedPermission = "僅受邀者可見" }
                    Button("公開") { selectedPermission = "公開" }
                    Button("取消", role: .cancel) {}
                }
            }
            Divider().padding(.horizontal, 16)
            
            // Date
            SettingRow(title: "週期") {
                HStack {
                    Text(trip.date)
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button("修改") {
                        showCalendarModal = true
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "2AA5A0")) // Teal
                }
            }
            Divider().padding(.horizontal, 16)
            
            // Destination
            SettingRow(title: "目的地") {
                TextField("輸入目的地", text: $destination)
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.leading)
            }
            Divider().padding(.horizontal, 16)
            
            // Transport
            SettingRow(title: "交通偏好") {
                TextField("例如：步行", text: $transportMode)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(PuboColors.red, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Members
    private func membersSection(trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("成員管理")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(PuboColors.navy)
                .padding(.leading, 16)
            
            VStack(spacing: 0) {
                ForEach(trip.members ?? []) { member in
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: member.avatar)) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
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
                Button(action: {
                    isShareSheetPresented = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(PuboColors.red)
                        Text("邀請成員")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(PuboColors.red, lineWidth: 1) // Red border as requested
            )
            .padding(.horizontal, 16)
        }
    }
    
    private func saveChanges() {
        tripManager.updateTripSettings(
            tripId: tripId,
            title: title,
            destination: destination,
            transportMode: transportMode
        )
    }

    // MARK: - Date Helpers
    private func parseStartDate(_ dateStr: String) -> Date? {
        let parts = dateStr.split(separator: "-").map(String.init)
        guard let startStr = parts.first else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.date(from: startStr)
    }

    private func parseEndDate(_ dateStr: String) -> Date? {
        let parts = dateStr.split(separator: "-").map(String.init)
        guard parts.count > 1, let start = parseStartDate(dateStr) else {
            return parseStartDate(dateStr)
        }
        let endStr = parts[1] // "MM/dd"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: start)
        if let endCandidate = formatter.date(from: "\(startYear)/\(endStr)") {
            if endCandidate < start {
                 return calendar.date(byAdding: .year, value: 1, to: endCandidate)
            }
            return endCandidate
        }
        return nil
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
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}

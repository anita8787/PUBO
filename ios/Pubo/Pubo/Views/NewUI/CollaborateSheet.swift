import SwiftUI
import SwiftData

// MARK: - CollaborateSheet

struct CollaborateSheet: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var tripManager: TripManager
    @Binding var isPresented: Bool
    let trip: SDTrip?

    @StateObject private var syncManager = TripSyncManager.shared
    @State private var inputCode: String = ""
    @State private var isGenerating = false
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var showJoinSuccess = false
    @State private var joinedTripTitle = ""
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F8F7F4").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {

                        if let trip = trip {
                            // ── 有指定行程：顯示產生或分享邀請碼 ──────────────────
                            if let code = trip.inviteCode {
                                activeCollabSection(trip: trip, code: code)
                            } else {
                                inactiveSection
                            }

                            Divider()
                                .padding(.horizontal, 24)
                        } else {
                            // ── 從首頁進入：僅顯示純加入介面 ───────────────────────
                            VStack(spacing: 8) {
                                Image(systemName: "person.2.badge.plus")
                                    .font(.system(size: 36))
                                    .foregroundColor(PuboColors.navy.opacity(0.5))
                                Text("加入好友的行程")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundColor(PuboColors.navy)
                                    .padding(.bottom, 8)
                            }
                        }

                        // ── 輸入好友邀請碼加入 ────────────────────────
                        joinSection
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle("共同編輯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { isPresented = false }
                }
            }
            .alert("成功加入行程！", isPresented: $showJoinSuccess) {
                Button("好的") { isPresented = false }
            } message: {
                Text("已加入「\(joinedTripTitle)」，可在行程列表查看。")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
        }
    }

    // MARK: - 已啟用協作區塊

    private func activeCollabSection(trip: SDTrip, code: String) -> some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 32))
                    .foregroundColor(PuboColors.navy)
                Text("協作已啟用")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(PuboColors.navy)
                Text("分享邀請碼給旅遊夥伴，輸入後即可共同編輯此行程")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // 邀請碼顯示
            VStack(spacing: 12) {
                Text("邀請碼")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(2)

                Text(code)
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundColor(PuboColors.navy)
                    .tracking(8)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(PuboColors.navy.opacity(0.2), lineWidth: 1.5)
                    )
            }

            // 操作按鈕
            HStack(spacing: 12) {
                // 複製邀請碼
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("複製邀請碼", systemImage: "doc.on.doc")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(PuboColors.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PuboColors.navy, lineWidth: 1.5))
                }

                // 分享連結
                Button {
                    let link = "pubo://join?code=\(code)"
                    let message = "加入我的行程「\(trip.title)」！\n輸入邀請碼：\(code)\n或點擊連結：\(link)"
                    shareItems = [message]
                    showShareSheet = true
                } label: {
                    Label("分享連結", systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PuboColors.navy)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 24)

            // 協作人數
            if !trip.collaborators.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "4CAF50"))
                    Text("\(trip.collaborators.count) 人正在協作此行程")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 尚未啟用協作區塊

    private var inactiveSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 36))
                    .foregroundColor(PuboColors.navy.opacity(0.5))
                Text("邀請夥伴共同編輯")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(PuboColors.navy)
                Text("生成邀請碼後，分享給旅遊夥伴，他們輸入後即可共同編輯此行程")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                generateCode()
            } label: {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGenerating ? "生成中..." : "生成邀請碼")
                        .font(.system(size: 17, weight: .black))
                }
                .foregroundColor(PuboColors.navy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PuboColors.yellow)
                .cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(PuboColors.navy, lineWidth: 2))
                .shadow(color: PuboColors.navy.opacity(0.2), radius: 0, x: 3, y: 3)
            }
            .disabled(isGenerating)
            .padding(.horizontal, 24)

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - 加入好友行程區塊

    private var joinSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("輸入邀請碼加入行程")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(PuboColors.navy)
                Text("輸入好友的六位數邀請碼")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            // 六格數字輸入框（單一隱藏 TextField + 六個顯示框）
            ZStack {
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { i in
                        let char = getChar(at: i)
                        let isCurrentFocus = isInputFocused && (inputCode.count == i || (inputCode.count == 6 && i == 5))
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .frame(width: 44, height: 56)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isCurrentFocus ? PuboColors.navy : Color.gray.opacity(0.2), lineWidth: isCurrentFocus ? 2 : 1)
                                )
                                .shadow(color: isCurrentFocus ? PuboColors.navy.opacity(0.15) : .clear, radius: 4)

                            Text(char)
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundColor(PuboColors.navy)
                        }
                    }
                }
                .onTapGesture {
                    isInputFocused = true
                }
                
                TextField("", text: $inputCode)
                    .keyboardType(.numberPad)
                    .focused($isInputFocused)
                    .opacity(0.001)
                    .onChange(of: inputCode) { _, newValue in
                        // 過濾非數字並限制 6 碼
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count > 6 {
                            inputCode = String(filtered.prefix(6))
                        } else if newValue != filtered {
                            inputCode = filtered
                        }
                    }
            }
            .padding(.horizontal, 24)
            .onAppear { isInputFocused = true }

            Button {
                joinTrip()
            } label: {
                HStack(spacing: 8) {
                    if isJoining {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    Text(isJoining ? "加入中..." : "加入行程")
                        .font(.system(size: 16, weight: .black))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(inputCode.count == 6 ? PuboColors.navy : Color.gray.opacity(0.3))
                .cornerRadius(16)
            }
            .disabled(inputCode.count < 6 || isJoining)
            .padding(.horizontal, 24)
        }
    }
    
    private func getChar(at index: Int) -> String {
        guard index < inputCode.count else { return " " }
        let charIndex = inputCode.index(inputCode.startIndex, offsetBy: index)
        return String(inputCode[charIndex])
    }

    // MARK: - Actions

    private func generateCode() {
        guard let trip = trip else { return }
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let code = try await FirestoreService.shared.generateUniqueInviteCode()
                // 儲存到 SDTrip
                trip.inviteCode = code
                let uid = AuthManager.shared.currentUID
                if !trip.collaborators.contains(uid) {
                    trip.collaborators.append(uid)
                }
                trip.lastUpdated = Date()
                try? context.save()
                // 上傳到 Firestore
                try await FirestoreService.shared.pushTrip(trip, ownerUID: uid)
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func joinTrip() {
        let code = inputCode
        guard code.count == 6 else { return }
        isJoining = true
        errorMessage = nil
        Task {
            do {
                let fsTrip = try await FirestoreService.shared.joinTrip(inviteCode: code)
                let newSDTrip = fsTrip.toSDTrip(inviteCode: code)
                context.insert(newSDTrip)
                // 把自己加進協作者名單
                let uid = AuthManager.shared.currentUID
                if !newSDTrip.collaborators.contains(uid) {
                    newSDTrip.collaborators.append(uid)
                    try await FirestoreService.shared.addCollaborator(inviteCode: code, uid: uid)
                }
                try? context.save()
                
                // Update TripManager state so UI reflects it immediately
                await MainActor.run {
                    tripManager.trips.append(newSDTrip.toTrip())
                }
                
                joinedTripTitle = fsTrip.title
                showJoinSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isJoining = false
        }
    }
}


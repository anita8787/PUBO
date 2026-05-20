import SwiftUI

struct ProfileView: View {
    var onBack: () -> Void
    var onGoToCollection: (() -> Void)? = nil

    @EnvironmentObject var tripManager: TripManager
    @AppStorage("userGender") private var userGender: String = "girl"
    @AppStorage("userName") private var userName: String = "Nita"

    @State private var showingSpinner = false
    @State private var showingPostManagement = false
    @State private var showingFeedback = false
    @State private var showingTripTrash = false
    @State private var showingGeneralSettings = false
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false

    /// 不重複的目的地數量 = 徽章數
    var badgeCount: Int {
        let dests = tripManager.trips.compactMap { $0.destination }.filter { !$0.isEmpty }
        return Set(dests).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PuboColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 60)

                        // MARK: Avatar + Name
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 68, height: 68)
                                    .overlay(Circle().stroke(PuboColors.navy, lineWidth: 2.5))
                                    .retroShadow(color: .black.opacity(0.08), offset: 3)
                                Image(userGender)
                                    .resizable().scaledToFit()
                                    .frame(width: 58, height: 58)
                                    .clipShape(Circle())
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userName)
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundColor(PuboColors.navy)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        // MARK: Stats Card
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(PuboColors.yellow)
                                .offset(x: 3, y: 3)
                            HStack(spacing: 0) {
                                VStack(spacing: 4) {
                                    Text("\(badgeCount)")
                                        .font(.system(size: 24, weight: .black))
                                        .foregroundColor(PuboColors.navy)
                                    Text("個徽章")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                Divider().frame(height: 32)
                                VStack(spacing: 4) {
                                    Text("\(tripManager.trips.count)")
                                        .font(.system(size: 24, weight: .black))
                                        .foregroundColor(PuboColors.navy)
                                    Text("個行程")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(PuboColors.yellow, lineWidth: 2))
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 40)

                        // MARK: Quick Actions
                        HStack(spacing: 0) {
                            quickAction(icon: "dice", label: "旅行命運") { showingSpinner = true }
                            quickAction(icon: "flag", label: "貼文管理") { showingPostManagement = true }
                            quickAction(icon: "bookmark", label: "收藏地點") { onGoToCollection?() }
                        }
                        .padding(.horizontal, 24)

                        // MARK: Settings Block 1
                        VStack(spacing: 0) {
                            settingsRow(icon: "bubble.left", label: "意見回饋") { showingFeedback = true }
                            Divider().padding(.horizontal, 16)
                            settingsRow(icon: "trash", label: "行程回收站") { showingTripTrash = true }
                            Divider().padding(.horizontal, 16)
                            NavigationLink(destination: GeneralSettingsView()) {
                                settingsRowContent(icon: "gearshape", label: "一般設定")
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.white)
                        .cornerRadius(20)
                        .padding(.horizontal, 24)

                        // MARK: Settings Block 2 — Terms
                        VStack(alignment: .leading, spacing: 0) {
                            Text("條款與隱私")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 6)
                            VStack(spacing: 0) {
                                settingsRow(icon: "doc.text", label: "服務條款") { }
                                Divider().padding(.horizontal, 16)
                                settingsRow(icon: "lock.shield", label: "隱私政策") { }
                            }
                            .background(Color.white)
                            .cornerRadius(20)
                        }
                        .padding(.horizontal, 24)

                        // MARK: Logout / Delete Account
                        VStack(spacing: 14) {
                            Button {
                                showLogoutAlert = true
                            } label: {
                                Text("登出")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(PuboColors.navy)
                                    .frame(maxWidth: .infinity).frame(height: 50)
                                    .background(Color.white)
                                    .cornerRadius(25)
                                    .overlay(Capsule().stroke(PuboColors.navy, lineWidth: 1.5))
                            }

                            Button {
                                showDeleteAlert = true
                            } label: {
                                Text("刪除帳號")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 40)

                        Spacer().frame(height: 120)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay(
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .bold)).foregroundColor(PuboColors.navy)
                        .frame(width: 40, height: 40).background(Color.white)
                        .clipShape(Circle()).overlay(Circle().stroke(PuboColors.navy, lineWidth: 1.5))
                }
                .padding(.leading, 24).padding(.top, 8),
                alignment: .topLeading
            )
            .sheet(isPresented: $showingSpinner) { SpinnerWheelView() }
            .sheet(isPresented: $showingPostManagement) { PostManagementView() }
            .sheet(isPresented: $showingFeedback) { FeedbackView() }
            .sheet(isPresented: $showingTripTrash) {
                TripTrashView().environmentObject(tripManager)
            }
            .alert("登出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("確認登出", role: .destructive) { /* TODO: auth logout */ }
            } message: {
                Text("確定要登出您的帳號嗎？")
            }
            .alert("刪除帳號", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("確認刪除", role: .destructive) { /* TODO: delete account */ }
            } message: {
                Text("刪除後所有資料將無法復原，請謹慎操作。")
            }
        }
    }

    // MARK: - Helper Views

    func quickAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22)).foregroundColor(PuboColors.navy)
                    .frame(width: 52, height: 52).background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PuboColors.yellow, lineWidth: 2))
                    .shadow(color: PuboColors.yellow.opacity(0.4), radius: 0, x: 2, y: 2)
                Text(label)
                    .font(.system(size: 11, weight: .bold)).foregroundColor(PuboColors.navy)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    func settingsRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            settingsRowContent(icon: icon, label: label)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func settingsRowContent(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(.gray)
            Text(label).font(.system(size: 15, weight: .medium)).foregroundColor(.black)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gray)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

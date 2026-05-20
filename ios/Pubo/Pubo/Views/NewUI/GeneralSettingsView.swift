import SwiftUI

struct GeneralSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("userGender") private var userGender: String = "girl"
    @AppStorage("userName") private var userName: String = "Nita"
    @AppStorage("userEmail") private var userEmail: String = ""
    @AppStorage("notifyAll") private var notifyAll: Bool = true
    @AppStorage("notifyAnalysis") private var notifyAnalysis: Bool = true
    @State private var isEditingName = false
    @State private var editedName = ""

    var body: some View {
        ZStack {
            PuboColors.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 56)

                    // MARK: - 通知設定
                    sectionCard(title: "通知設定") {
                        toggleRow(icon: "bell.fill", label: "所有通知", binding: $notifyAll)
                        Divider().padding(.horizontal, 16)
                        toggleRow(icon: "sparkles", label: "內容分析完成", binding: $notifyAnalysis)
                    }

                    // MARK: - 帳號資料
                    sectionCard(title: "帳號資料") {
                        // Avatar (read-only display synced from home)
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 16)).foregroundColor(.gray)
                            Text("大頭貼")
                                .font(.system(size: 15, weight: .medium)).foregroundColor(.black)
                            Spacer()
                            ZStack {
                                Circle().fill(Color.white)
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(PuboColors.navy, lineWidth: 1.5))
                                Image(userGender)
                                    .resizable().scaledToFit()
                                    .frame(width: 30, height: 30).clipShape(Circle())
                            }
                            Text("首頁可更換")
                                .font(.system(size: 11)).foregroundColor(.gray)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)

                        Divider().padding(.horizontal, 16)

                        // Name (editable)
                        HStack(spacing: 14) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16)).foregroundColor(.gray)
                            if isEditingName {
                                TextField("顯示名稱", text: $editedName)
                                    .font(.system(size: 15)).foregroundColor(.black)
                                Spacer()
                                Button("儲存") {
                                    userName = editedName.trimmingCharacters(in: .whitespaces).isEmpty ? userName : editedName
                                    isEditingName = false
                                }
                                .font(.system(size: 14, weight: .bold)).foregroundColor(PuboColors.navy)
                            } else {
                                Text("顯示名稱")
                                    .font(.system(size: 15, weight: .medium)).foregroundColor(.black)
                                Spacer()
                                Text(userName)
                                    .font(.system(size: 14)).foregroundColor(.gray)
                                Button { editedName = userName; isEditingName = true } label: {
                                    Image(systemName: "pencil").font(.system(size: 13)).foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)

                        if !userEmail.isEmpty {
                            Divider().padding(.horizontal, 16)
                            HStack(spacing: 14) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16)).foregroundColor(.gray)
                                Text("電子郵件")
                                    .font(.system(size: 15, weight: .medium)).foregroundColor(.black)
                                Spacer()
                                Text(userEmail)
                                    .font(.system(size: 13)).foregroundColor(.gray).lineLimit(1)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                    }

                    Spacer().frame(height: 80)
                }
            }
        }
        .navigationBarHidden(true)
        .overlay(
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .bold)).foregroundColor(PuboColors.navy)
                    .frame(width: 40, height: 40).background(Color.white)
                    .clipShape(Circle()).overlay(Circle().stroke(PuboColors.navy, lineWidth: 1.5))
            }
            .padding(.leading, 24).padding(.top, 8),
            alignment: .topLeading
        )
    }

    @ViewBuilder
    func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                .padding(.horizontal, 24).padding(.bottom, 6)
            VStack(spacing: 0) { content() }
                .background(Color.white).cornerRadius(16)
                .padding(.horizontal, 24)
        }
    }

    func toggleRow(icon: String, label: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16)).foregroundColor(.gray)
            Text(label)
                .font(.system(size: 15, weight: .medium)).foregroundColor(.black)
            Spacer()
            Toggle("", isOn: binding).labelsHidden()
                .tint(PuboColors.navy)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

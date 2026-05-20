import SwiftUI

/// 同步狀態指示器 — 只在行程有協作者（inviteCode != nil）時顯示
struct SyncStatusBadge: View {
    let status: SyncStatus

    @State private var isRotating = false

    var body: some View {
        Group {
            switch status {
            case .idle:
                EmptyView()

            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PuboColors.navy.opacity(0.7))
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(
                        .linear(duration: 0.9).repeatForever(autoreverses: false),
                        value: isRotating
                    )
                    .onAppear { isRotating = true }
                    .onDisappear { isRotating = false }

            case .synced:
                ZStack {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "4CAF50"))
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white)
                        .offset(y: 1)
                }

            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "FF9800"))

            case .offline:
                Image(systemName: "wifi.slash")
                    .font(.system(size: 15))
                    .foregroundColor(Color.gray.opacity(0.7))
            }
        }
        .frame(width: 28, height: 28)
    }
}

import SwiftUI

struct TripTrashView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tripManager: TripManager
    @StateObject private var trashManager = TripTrashManager.shared
    @State private var restoringId: String? = nil
    @State private var showConfirmDelete: TripTrashManager.DeletedTripEntry? = nil

    let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Text("行程回收站").font(.system(size: 18, weight: .black)).foregroundColor(PuboColors.navy)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                            .frame(width: 32, height: 32).background(Color.gray.opacity(0.1)).clipShape(Circle())
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(Color.white)
            .overlay(Divider(), alignment: .bottom)

            if trashManager.entries.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "trash.slash").font(.system(size: 48)).foregroundColor(.gray.opacity(0.35))
                    Text("回收站是空的").font(.system(size: 18, weight: .black)).foregroundColor(PuboColors.navy)
                    Text("刪除的行程會在此保留 20 天\n讓您隨時可以復原").font(.system(size: 14)).foregroundColor(.gray).multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity).background(PuboColors.background)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Text("回收站保留最近 20 天內刪除的行程")
                            .font(.system(size: 12)).foregroundColor(.gray)
                            .padding(.vertical, 12)

                        VStack(spacing: 12) {
                            ForEach(trashManager.entries) { entry in
                                HStack(spacing: 14) {
                                    // Icon
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(PuboColors.navy.opacity(0.08))
                                        .frame(width: 48, height: 48)
                                        .overlay(Image(systemName: "suitcase").foregroundColor(PuboColors.navy).font(.system(size: 20)))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.title).font(.system(size: 15, weight: .bold)).foregroundColor(.black).lineLimit(1)
                                        if let dest = entry.destination {
                                            Text(dest).font(.system(size: 12)).foregroundColor(.gray)
                                        }
                                        Text("刪除於 \(dateFormatter.string(from: entry.deletedAt)) · 剩 \(entry.daysRemaining) 天")
                                            .font(.system(size: 11)).foregroundColor(.orange)
                                    }
                                    Spacer()

                                    Button {
                                        restoreTrip(entry)
                                    } label: {
                                        Text(restoringId == entry.id ? "復原中" : "復原")
                                            .font(.system(size: 13, weight: .bold)).foregroundColor(PuboColors.navy)
                                            .padding(.horizontal, 14).padding(.vertical, 7)
                                            .background(PuboColors.navy.opacity(0.1))
                                            .cornerRadius(20)
                                    }
                                    .disabled(restoringId != nil)
                                }
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                            }
                        }
                        .padding(.horizontal, 20)
                        Spacer().frame(height: 80)
                    }
                }
                .background(PuboColors.background)
            }
        }
        .background(PuboColors.background)
    }

    private func restoreTrip(_ entry: TripTrashManager.DeletedTripEntry) {
        restoringId = entry.id
        tripManager.addTrip(
            title: entry.title,
            destination: entry.destination ?? "",
            startDate: entry.startDate ?? Date(),
            endDate: entry.endDate ?? Date()
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            trashManager.remove(entry)
            restoringId = nil
        }
    }
}

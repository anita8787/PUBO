import SwiftUI

struct AllCuratedPostsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataService: DataService
    @Binding var selectedCuratedPost: CuratedPost?

    // MARK: - Filter State
    @State private var selectedCountry: String? = nil
    @State private var selectedCategory: String? = nil
    @State private var isCountryMenuExpanded: Bool = false

    // Category display info
    let categories: [(key: String, emoji: String, label: String)] = [
        ("shopping",    "🛍️", "逛街"),
        ("meal",        "🍜", "正餐"),
        ("dessert",     "🧁", "甜點"),
        ("sightseeing", "🏯", "景點"),
    ]

    // MARK: - Computed filtered posts
    var filteredPosts: [CuratedPost] {
        dataService.curatedPosts.filter { post in
            let countryMatch = selectedCountry == nil || post.country == selectedCountry
            let categoryMatch = selectedCategory == nil || (post.tripCategory ?? "mixed") == selectedCategory
            return countryMatch && categoryMatch
        }
    }

    var availableCountries: [String] {
        let countries = dataService.curatedPosts.compactMap { $0.country }.filter { !$0.isEmpty }
        return Array(Set(countries)).sorted()
    }

    // Waterfall columns
    var leftColumnPosts: [CuratedPost] {
        stride(from: 0, to: filteredPosts.count, by: 2).map { filteredPosts[$0] }
    }
    var rightColumnPosts: [CuratedPost] {
        stride(from: 1, to: filteredPosts.count, by: 2).map { filteredPosts[$0] }
    }

    var body: some View {
        ZStack {
            PuboColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.8))
                            .retroShadow(color: .black.opacity(0.15), offset: 2.0)
                    }

                    Spacer()

                    Text("推薦行程")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(PuboColors.navy)

                    Spacer()

                    // Badge: total count
                    Text("\(filteredPosts.count) 篇")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(PuboColors.navy)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(PuboColors.yellow)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(PuboColors.navy, lineWidth: 1.5))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // MARK: - Country Filter Row
                if !availableCountries.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button(action: { withAnimation(.spring(response: 0.3)) { isCountryMenuExpanded.toggle() } }) {
                                ZStack {
                                    Circle().fill(selectedCountry != nil ? PuboColors.navy : Color.white)
                                    Text(selectedCountry == nil ? "🌍" : countryFlag(selectedCountry!))
                                        .font(.system(size: 16))
                                }
                                .frame(width: 36, height: 36)
                                .overlay(Circle().strokeBorder(PuboColors.navy, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                            
                            if isCountryMenuExpanded {
                                ForEach(availableCountries, id: \.self) { country in
                                    filterChip(label: countryFlag(country) + " " + country, isSelected: selectedCountry == country) {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedCountry = (selectedCountry == country) ? nil : country
                                            isCountryMenuExpanded = false
                                        }
                                    }
                                }
                            } else if let sc = selectedCountry {
                                Text(sc)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(PuboColors.navy)
                                    .padding(.leading, 4)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                    }
                    .padding(.bottom, 8)
                }

                // MARK: - Category Filter Row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(label: "全部", isSelected: selectedCategory == nil, style: .category) {
                            withAnimation(.spring(response: 0.3)) { selectedCategory = nil }
                        }
                        ForEach(categories, id: \.key) { cat in
                            filterChip(label: "\(cat.emoji) \(cat.label)", isSelected: selectedCategory == cat.key, style: .category) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = (selectedCategory == cat.key) ? nil : cat.key
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4) // extra vertical padding for stroke bounds
                }
                .padding(.bottom, 12)

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.08))
                    .frame(height: 1)

                // MARK: - Waterfall Content
                if filteredPosts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("🔍")
                            .font(.system(size: 48))
                        Text("找不到符合的行程")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                        Text("試試選擇不同的篩選條件")
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        HStack(alignment: .top, spacing: 8) {
                            // Left Column
                            VStack(spacing: 12) {
                                ForEach(leftColumnPosts) { post in
                                    RecommendationCard(post: post, isFullWidth: true)
                                        .onTapGesture {
                                            selectedCuratedPost = post
                                            dismiss()
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity)

                            // Right Column
                            VStack(spacing: 12) {
                                ForEach(rightColumnPosts) { post in
                                    RecommendationCard(post: post, isFullWidth: true)
                                        .onTapGesture {
                                            selectedCuratedPost = post
                                            dismiss()
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
    }

    // MARK: - Filter Chip
    enum ChipStyle { case country, category }

    @ViewBuilder
    func filterChip(label: String, isSelected: Bool, style: ChipStyle = .country, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .white : PuboColors.navy)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? PuboColors.navy : Color.white)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(PuboColors.navy, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Country Flag Helper
    func countryFlag(_ country: String) -> String {
        let flagMap: [String: String] = [
            "日本": "🇯🇵", "韓國": "🇰🇷", "泰國": "🇹🇭", "台灣": "🇹🇼",
            "美國": "🇺🇸", "法國": "🇫🇷", "義大利": "🇮🇹", "英國": "🇬🇧",
            "德國": "🇩🇪", "西班牙": "🇪🇸", "澳洲": "🇦🇺", "新加坡": "🇸🇬",
            "香港": "🇭🇰", "中國": "🇨🇳", "越南": "🇻🇳", "印尼": "🇮🇩",
            "馬來西亞": "🇲🇾", "菲律賓": "🇵🇭", "印度": "🇮🇳",
        ]
        return flagMap[country] ?? "🌍"
    }
}

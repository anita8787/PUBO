import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @State private var feedbackText = ""
    @State private var submitted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Text("意見回饋").font(.system(size: 18, weight: .black)).foregroundColor(PuboColors.navy)
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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if submitted {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 56)).foregroundColor(.green)
                            Text("感謝您的回饋！").font(.system(size: 20, weight: .black)).foregroundColor(PuboColors.navy)
                            Text("我們會認真閱讀每一則意見，努力讓 Pubo 變得更好 🙏")
                                .font(.system(size: 14)).foregroundColor(.gray).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        Text("您的問題或建議").font(.system(size: 14, weight: .bold)).foregroundColor(PuboColors.navy)

                        TextEditor(text: $feedbackText)
                            .font(.system(size: 14))
                            .frame(minHeight: 160)
                            .padding(12)
                            .background(Color.gray.opacity(0.07))
                            .cornerRadius(12)
                            .overlay(
                                Group {
                                    if feedbackText.isEmpty {
                                        Text("請描述您遇到的問題或對 App 的建議...")
                                            .font(.system(size: 14)).foregroundColor(.gray)
                                            .padding(.horizontal, 16).padding(.vertical, 20)
                                            .allowsHitTesting(false)
                                    }
                                }, alignment: .topLeading
                            )

                        Button {
                            guard !feedbackText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            submitted = true
                        } label: {
                            Text("送出回饋")
                                .font(.system(size: 16, weight: .black)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(feedbackText.isEmpty ? Color.gray : PuboColors.navy)
                                .cornerRadius(26)
                        }
                        .disabled(feedbackText.isEmpty)
                    }
                }
                .padding(24)
            }
            .background(PuboColors.background)
        }
        .background(PuboColors.background)
    }
}

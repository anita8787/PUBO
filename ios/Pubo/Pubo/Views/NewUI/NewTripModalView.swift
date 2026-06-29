import SwiftUI

struct NewTripModalView: View {
    @Binding var isPresented: Bool
    var onCreateTrip: ((String, String, Date, Date) -> Void)?
    var onJoinClick: (() -> Void)?
    
    @State private var tripName: String = ""
    @State private var destination: String = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isDateModified = false
    
    enum Field { case name, destination }
    @FocusState private var focusedField: Field?
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if focusedField != nil {
                        focusedField = nil
                    } else {
                        isPresented = false
                    }
                }
            
            // Modal Card
            VStack(spacing: 0) {
                // Header — X at top-right
                ZStack(alignment: .topTrailing) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(PuboColors.yellow)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                            Image(systemName: "sparkles")
                                .foregroundColor(.black)
                                .font(.system(size: 13))
                        }
                        
                        Text("開啟新旅程")
                            .font(.system(size: 17, weight: .black))
                            .foregroundColor(PuboColors.navy)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(4)
                    }
                }
                .padding(.bottom, 16)
                
                // Form Fields
                VStack(alignment: .leading, spacing: 12) {
                    // Trip Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("旅程名稱")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        TextField("例如：東京 7 日遊", text: $tripName)
                            .focused($focusedField, equals: .name)
                            .multilineTextAlignment(.leading)
                            .font(.system(size: 13))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PuboColors.navy, lineWidth: 1.5))
                    }
                    
                    // Destination
                    VStack(alignment: .leading, spacing: 4) {
                        Text("目的地")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 13))
                                .foregroundColor(PuboColors.navy)
                            TextField("輸入國家或城市", text: $destination)
                                .focused($focusedField, equals: .destination)
                                .multilineTextAlignment(.leading)
                                .font(.system(size: 13))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PuboColors.navy, lineWidth: 1.5))
                    }
                    
                    // Dates
                    VStack(alignment: .leading, spacing: 4) {
                        Text("旅遊時間")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        HStack(spacing: 6) {
                            ZStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(isDateModified ? PuboColors.navy : .gray)
                                    Text(formatDate(startDate))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(isDateModified ? PuboColors.navy : .gray)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(Color.white)
                                .allowsHitTesting(false)
                                
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .scaleEffect(2.0) // smaller scale
                                    .colorMultiply(.clear) // transparent
                                    .onChange(of: startDate) { _, _ in
                                        isDateModified = true
                                    }
                            }
                            .clipped()
                            .contentShape(Rectangle()) // STRICTLY limit touch area to this rectangle
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PuboColors.navy, lineWidth: 1.5)) // Draw stroke outside clipped content evenly
                            
                            Text("~")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(PuboColors.navy)
                            
                            ZStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(isDateModified ? PuboColors.navy : .gray)
                                    Text(formatDate(endDate))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(isDateModified ? PuboColors.navy : .gray)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(Color.white)
                                .allowsHitTesting(false)
                                
                                DatePicker("", selection: $endDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .scaleEffect(2.0) // smaller scale
                                    .colorMultiply(.clear) // transparent
                                    .onChange(of: endDate) { _, _ in
                                        isDateModified = true
                                    }
                            }
                            .clipped()
                            .contentShape(Rectangle()) // STRICTLY limit touch area to this rectangle
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PuboColors.navy, lineWidth: 1.5)) // Draw stroke outside clipped content evenly
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Join Friends Trip Container (Button only on the arrow)
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 13))
                            .foregroundColor(PuboColors.navy)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("加入好友的行程")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(PuboColors.navy)
                            Text("點擊右側箭頭輸入邀請碼")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        Button(action: {
                            isPresented = false
                            onJoinClick?()
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(PuboColors.navy)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(10)
                    .background(PuboColors.background)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                }
                .padding(.bottom, 16)
                
                // Submit Button
                Button(action: {
                    onCreateTrip?(tripName, destination, startDate, endDate)
                    isPresented = false
                }) {
                    Text("出發去！")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(PuboColors.navy)
                        .cornerRadius(14)
                        .retroShadow(color: .black)
                }
            } // Close VStack
            .frame(width: 280) // Make dialog slightly wider so content is not cramped
            .padding(24)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .onTapGesture {
                focusedField = nil // Dismiss keyboard when tapping on blank areas of the modal
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

import SwiftUI

struct NewTripModalView: View {
    @Binding var isPresented: Bool
    var onCreateTrip: ((String, String, Date, Date) -> Void)?
    
    @State private var tripName: String = ""
    @State private var destination: String = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isShared: Bool = false
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
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
                                .font(.system(size: 13))
                        }
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
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .scaleEffect(0.75, anchor: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PuboColors.navy, lineWidth: 1.5))
                            
                            Text("~")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                DatePicker("", selection: $endDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .scaleEffect(0.75, anchor: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PuboColors.navy, lineWidth: 1.5))
                        }
                    }
                    
                    // Invite Friends
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 13))
                            .foregroundColor(PuboColors.navy)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("邀請好友共同編輯")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(PuboColors.navy)
                            Text("與旅伴一起規劃行程")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Toggle("", isOn: $isShared)
                            .labelsHidden()
                            .tint(PuboColors.navy)
                            .scaleEffect(0.75)
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
            .padding(20)
            .background(Color.white)
            .cornerRadius(24)
            .padding(.horizontal, 40) // Shrink outer card naturally
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom) // Fix background scaling issue
    }
}

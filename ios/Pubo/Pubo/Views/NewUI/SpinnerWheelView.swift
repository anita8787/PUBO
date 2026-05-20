import SwiftUI

// MARK: - Pie Slice Shape
private struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        p.move(to: c)
        p.addArc(center: c, radius: r, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - SpinnerWheelView
struct SpinnerWheelView: View {
    @Environment(\.dismiss) var dismiss
    @State private var options: [String] = ["選項一", "選項二"]
    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var winner: String? = nil

    private let sliceColors: [Color] = [
        Color(hex: "1B3764"), Color(hex: "F5C542"), Color(hex: "E07B39"),
        Color(hex: "4A90D9"), Color(hex: "7BC67E"), Color(hex: "E8736E"),
        Color(hex: "9B59B6"), Color(hex: "1ABC9C")
    ]

    private var validOptions: [String] {
        options.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Text("旅行命運")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(PuboColors.navy)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(Color.white)
            .overlay(Divider(), alignment: .bottom)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Winner banner
                    if let w = winner {
                        HStack(spacing: 8) {
                            Text("🎉").font(.title2)
                            Text("命運選擇了：\(w)")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(PuboColors.navy)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(PuboColors.yellow.opacity(0.3))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                    }

                    // Wheel
                    wheelView

                    // Spin Button
                    Button(action: spin) {
                        Text(isSpinning ? "旋轉中..." : "🎲  開始轉動")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(validOptions.count >= 2 && !isSpinning ? PuboColors.navy : Color.gray)
                            .cornerRadius(26)
                    }
                    .disabled(validOptions.count < 2 || isSpinning)
                    .padding(.horizontal, 24)

                    // Options Editor
                    optionsEditor

                    Spacer().frame(height: 60)
                }
                .padding(.top, 24)
            }
            .background(PuboColors.background)
        }
        .background(PuboColors.background)
    }

    // MARK: - Wheel
    private var wheelView: some View {
        ZStack {
            if validOptions.count >= 2 {
                let n = validOptions.count
                let slice = 360.0 / Double(n)

                ZStack {
                    ForEach(0..<n, id: \.self) { i in
                        let start = Angle.degrees(slice * Double(i) - 90)
                        let end = Angle.degrees(slice * Double(i + 1) - 90)
                        PieSlice(startAngle: start, endAngle: end)
                            .fill(sliceColors[i % sliceColors.count])
                        PieSlice(startAngle: start, endAngle: end)
                            .stroke(Color.white, lineWidth: 2)
                    }
                    // Center dot
                    Circle().fill(Color.white).frame(width: 32, height: 32)
                }
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(rotation))
                .animation(isSpinning ? .easeOut(duration: 3.5) : .none, value: rotation)

                // Labels
                ForEach(0..<n, id: \.self) { i in
                    let midDeg = (slice * Double(i) + slice / 2 - 90) * .pi / 180
                    Text(validOptions[i])
                        .font(.system(size: max(9, min(11, 80.0 / Double(n))), weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .offset(x: 80 * cos(midDeg), y: 80 * sin(midDeg))
                        .rotationEffect(.degrees(rotation))
                        .animation(isSpinning ? .easeOut(duration: 3.5) : .none, value: rotation)
                }

                // Pointer
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 22))
                    .foregroundColor(PuboColors.navy)
                    .offset(y: -142)

            } else {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 260, height: 260)
                    .overlay(
                        Text("請至少新增 2 個選項")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    )
            }
        }
        .frame(height: 290)
    }

    // MARK: - Options Editor
    private var optionsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("設定選項")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(PuboColors.navy)

            ForEach(options.indices, id: \.self) { i in
                HStack {
                    TextField("選項 \(i + 1)", text: $options[i])
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color.gray.opacity(0.07))
                        .cornerRadius(10)
                    if options.count > 2 {
                        Button { options.remove(at: i) } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            if options.count < 8 {
                Button { options.append("") } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("新增選項")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(PuboColors.navy)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Spin Logic
    private func spin() {
        guard validOptions.count >= 2, !isSpinning else { return }
        winner = nil
        isSpinning = true
        let spins = Double.random(in: 720...1440)
        rotation += spins
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.7) {
            isSpinning = false
            let n = validOptions.count
            let sliceAngle = 360.0 / Double(n)
            // Normalize total rotation to [0°, 360°)
            let normalised = rotation.truncatingRemainder(dividingBy: 360)
            // Slices start at -90° (top). The slice index under the pointer (top) =
            // how many slices fit in (-rotation) starting from 0, normalized to [0,360)
            let fromStart = ((-normalised) + 360 * 100).truncatingRemainder(dividingBy: 360)
            let idx = Int(fromStart / sliceAngle) % n
            winner = validOptions[idx]
        }
    }
}

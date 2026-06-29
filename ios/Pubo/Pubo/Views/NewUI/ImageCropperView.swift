import SwiftUI

@available(iOS 16.0, *)
struct ImageCropperView: View {
    let image: UIImage
    var onCrop: (UIImage) -> Void
    var onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Custom Top Bar
                HStack {
                    Button("取消", action: onCancel)
                        .foregroundColor(.white)
                        .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                let cropSize: CGFloat = UIScreen.main.bounds.width - 40
                
                // The exact view we want to capture
                let capturedView = Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cropSize, height: cropSize)
                    .scaleEffect(scale)
                    .offset(offset)
                    .clipped()
                
                ZStack {
                    capturedView
                        .border(Color.white.opacity(0.5), width: 2)
                        .contentShape(Rectangle()) // ensure gesture covers entire square
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { val in
                                        scale = max(1.0, lastScale * val)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    },
                                DragGesture()
                                    .onChanged { val in
                                        offset = CGSize(width: lastOffset.width + val.translation.width,
                                                        height: lastOffset.height + val.translation.height)
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                }
                .frame(width: cropSize, height: cropSize)
                
                Spacer()
                
                Text("拖曳或縮放來調整圖片預覽位置")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 14))
                    .padding(.bottom, 24)
                    
                Button("確定上傳") {
                    let cropSize: CGFloat = UIScreen.main.bounds.width - 40
                    let capturedView = Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropSize, height: cropSize)
                        .scaleEffect(scale)
                        .offset(offset)
                        .clipped()
                        
                    let renderer = ImageRenderer(content: capturedView)
                    renderer.scale = UIScreen.main.scale
                    if let uiImage = renderer.uiImage {
                        onCrop(uiImage)
                    } else {
                        onCancel()
                    }
                }
                .bold()
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.1, green: 0.2, blue: 0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

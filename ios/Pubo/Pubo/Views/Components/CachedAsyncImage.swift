import SwiftUI
import CryptoKit

/// 高效能的圖片快取元件
/// 自動將網路下載過的圖片保存在記憶體與磁碟中，大幅提升二次載入的速度並減少網路請求。
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var loadedImage: UIImage?
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        
        // 1. 同步檢查記憶體快取：如果在快取中，直接作為初始狀態，完全避免閃爍
        if let url = url, let cached = ImageCache.shared.memoryCache.object(forKey: url.absoluteString as NSString) {
            self._loadedImage = State(initialValue: cached)
        } else {
            self._loadedImage = State(initialValue: nil)
        }
    }
    
    var body: some View {
        if let loadedImage = loadedImage {
            content(Image(uiImage: loadedImage))
        } else {
            placeholder()
                .onAppear {
                    loadImage()
                }
        }
    }
    
    private func loadImage() {
        guard let url = url, loadedImage == nil else { return }
        
        let urlString = url.absoluteString
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 2. 檢查磁碟快取
            if let cached = ImageCache.shared.imageFromDisk(for: urlString) {
                DispatchQueue.main.async {
                    self.loadedImage = cached
                }
                return
            }
            
            // 3. 網路下載
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let _ = error {
                    // Fail silently but prevent infinite loading
                    DispatchQueue.main.async {
                        self.loadedImage = UIImage() // Empty image to stop spinner
                    }
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    DispatchQueue.main.async {
                        self.loadedImage = UIImage() // Empty image to stop spinner
                    }
                    return
                }
                
                if let data = data, let image = UIImage(data: data) {
                    // 寫入快取 (記憶體 + 磁碟)
                    ImageCache.shared.set(image, for: urlString)
                    
                    // 更新畫面
                    DispatchQueue.main.async {
                        self.loadedImage = image
                    }
                } else {
                    print("❌ [CachedAsyncImage] Invalid image data for: \(url.absoluteString)")
                }
            }.resume()
        }
    }
}

/// 支援記憶體與磁碟的快取管理器
class ImageCache {
    static let shared = ImageCache()
    
    let memoryCache: NSCache<NSString, UIImage>
    private let fileManager = FileManager.default
    private var diskCacheURL: URL?
    
    private init() {
        memoryCache = NSCache<NSString, UIImage>()
        memoryCache.countLimit = 200 // 增加記憶體快取量
        memoryCache.totalCostLimit = 200 * 1024 * 1024 // 200 MB
        
        if let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            diskCacheURL = cacheDirectory.appendingPathComponent("PuboImageDiskCache")
            if !fileManager.fileExists(atPath: diskCacheURL!.path) {
                try? fileManager.createDirectory(at: diskCacheURL!, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }
    
    private func filename(for urlString: String) -> String {
        let data = Data(urlString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func imageFromDisk(for urlString: String) -> UIImage? {
        guard let diskURL = diskCacheURL?.appendingPathComponent(filename(for: urlString)),
              fileManager.fileExists(atPath: diskURL.path),
              let data = try? Data(contentsOf: diskURL),
              let image = UIImage(data: data) else {
            return nil
        }
        // 讀取後順便放進記憶體，下次就能同步顯示
        memoryCache.setObject(image, forKey: urlString as NSString)
        return image
    }
    
    func set(_ image: UIImage, for urlString: String) {
        // 寫入記憶體
        memoryCache.setObject(image, forKey: urlString as NSString)
        
        // 寫入磁碟
        guard let diskURL = diskCacheURL?.appendingPathComponent(filename(for: urlString)) else { return }
        // 使用 JPEG 壓縮以節省空間與提升讀取速度
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: diskURL)
        }
    }
}

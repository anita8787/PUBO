    // define App Group ID (Must match Xcode Capabilities)
    let appGroupId = "group.com.anita.Pubo" 

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = extensionItem.attachments?.first else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
            attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (url, error) in
                if let shareURL = url as? URL {
                    self.processShareURL(shareURL)
                }
            }
        }
    }
    
    private func processShareURL(_ url: URL) {
        // 1. Send to Backend
        sendURLToPuboBackend(url: url) { [weak self] taskId in
            guard let self = self else { return }
            
            // 2. Save Task ID locally (Guest Mode support)
            self.saveTaskLocally(taskId: taskId)
            
            // 3. Show Alert on Main Thread
            DispatchQueue.main.async {
                self.presentActionAlert(taskId: taskId)
            }
        }
    }

    private func presentActionAlert(taskId: String) {
         // Create a custom alert or use standard UIAlertController
         // Note: SLComposeServiceViewController might dismiss automatically if we don't control it carefully.
         // Actually, we should probably show this alert instead of auto-dismissing.
         
         let alert = UIAlertController(title: "已收藏！", message: "正在為您解析地點...", preferredStyle: .alert)
         
         let viewNowAction = UIAlertAction(title: "立即查看", style: .default) { _ in
             self.openMainApp(taskId: taskId)
             self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
         }
         
         let laterAction = UIAlertAction(title: "稍後", style: .cancel) { _ in
             self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
         }
         
         alert.addAction(viewNowAction)
         alert.addAction(laterAction)
         
         self.present(alert, animated: true, completion: nil)
    }

    private func openMainApp(taskId: String) {
        // URL Scheme to open main app
        let url = URL(string: "pubo://task/\(taskId)")! 
        
        // NSExtensionContext openURL is widely supported
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = responder?.next
        }
        // Fallback or specific extension API
        self.extensionContext?.open(url, completionHandler: nil)
    }

    private func saveTaskLocally(taskId: String) {
        if let userDefaults = UserDefaults(suiteName: appGroupId) {
            var tasks = userDefaults.stringArray(forKey: "pending_tasks") ?? []
            tasks.append(taskId)
            userDefaults.set(tasks, forKey: "pending_tasks")
            userDefaults.synchronize()
        }
    }
    
    // 將 URL 傳送到實作好的 FastAPI 後端
    private func sendURLToPuboBackend(url: URL, completion: @escaping (String) -> Void) {
        // Replace with actual Prod URL later
        guard let backendURL = URL(string: "http://localhost:8000/api/v1/share") else { return }
        
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["url": url.absoluteString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let taskId = json["task_id"] as? String {
                completion(taskId)
            } else {
                // Fallback: Generate a temp ID or handle error
                completion(UUID().uuidString) 
            }
        }.resume()
    }

    override func configurationItems() -> [Any]! {
        return []
    }
}

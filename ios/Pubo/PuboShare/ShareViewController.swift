//
//  ShareViewController.swift
//  PuboShare
//
//  Created by Pubo Team on 2026/2/8.
//

import UIKit
import Social
import MobileCoreServices

class ShareViewController: UIViewController {
    
    // define App Group ID
    let appGroupId = "group.com.anita.Pubo"
    
    // UI Elements
    private let backgroundView = UIView()
    private let cardView = UIView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    
    // Success UI Elements
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let viewNowButton = UIButton(type: .system)
    private let laterButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    
     private var cardBottomConstraint: NSLayoutConstraint?

     override func viewDidLoad() {
         super.viewDidLoad()
         setupLayout()
     }

     override func viewDidAppear(_ animated: Bool) {
         super.viewDidAppear(animated)
         showCardAnimation()
         // 動畫完成後再開始提取
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
             self.showLoadingState()
             self.extractURLAndProcess()
         }
     }
 
     private func setupLayout() {
         // 1. Background (Semi-transparent)
         backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.0) // 初始透明
         backgroundView.translatesAutoresizingMaskIntoConstraints = false
         view.addSubview(backgroundView)
         
         // 2. Card Container
         cardView.backgroundColor = .white
         cardView.layer.cornerRadius = 20
         cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner] // 只有上面圓角
         cardView.layer.masksToBounds = true
         cardView.translatesAutoresizingMaskIntoConstraints = false
         view.addSubview(cardView)
         
         // Constraints
         let bottomConstraint = cardView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 300) // 初始位置在螢幕外
         self.cardBottomConstraint = bottomConstraint
         
         NSLayoutConstraint.activate([
             backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
             backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
             backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
             backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
             
             cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
             cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
             bottomConstraint,
             // Height will be dynamic
             cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 250)
         ])
         
         setupLoadingUI()
         setupSuccessUI()
     }
    
    private func showCardAnimation() {
        self.view.layoutIfNeeded()
        self.cardBottomConstraint?.constant = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
            self.view.layoutIfNeeded()
        }
    }
    
    private func hideCardAnimation(completion: @escaping () -> Void) {
        self.cardBottomConstraint?.constant = 300
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
            self.view.layoutIfNeeded()
        } completion: { _ in
            completion()
        }
    }
    
    private func setupLoadingUI() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .darkGray
        cardView.addSubview(activityIndicator)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "正在儲存到 Pubo..."
        statusLabel.textColor = .darkGray
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cardView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: cardView.centerYAnchor, constant: -10),
            
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor)
        ])
    }
    
    private func setupSuccessUI() {
        // Initally hidden
        titleLabel.alpha = 0
        messageLabel.alpha = 0
        viewNowButton.alpha = 0
        laterButton.alpha = 0
        closeButton.alpha = 0
        
        // Title (Logo Style)
        titleLabel.text = "Pubo!"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.8, alpha: 1.0) // Deep Blueish
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        // Message
        messageLabel.text = "已分享！你可以在應用程式中\n查看已識別的地點"
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.textColor = .gray
        messageLabel.font = UIFont.systemFont(ofSize: 15)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(messageLabel)
        
        // View Now Button (Primary)
        viewNowButton.setTitle("現在查看", for: .normal)
        viewNowButton.setTitleColor(.white, for: .normal)
        viewNowButton.backgroundColor = .black
        viewNowButton.layer.cornerRadius = 22
        viewNowButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        viewNowButton.addTarget(self, action: #selector(handleViewNow), for: .touchUpInside)
        viewNowButton.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(viewNowButton)
        
        // Later Button (Secondary)
        laterButton.setTitle("稍後查看", for: .normal)
        laterButton.setTitleColor(.gray, for: .normal)
        laterButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        laterButton.addTarget(self, action: #selector(handleLater), for: .touchUpInside)
        laterButton.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(laterButton)
        
        // Close Button (X)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .lightGray
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            viewNowButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 25),
            viewNowButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            viewNowButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -40),
            viewNowButton.heightAnchor.constraint(equalToConstant: 44),
            
            laterButton.topAnchor.constraint(equalTo: viewNowButton.bottomAnchor, constant: 10),
            laterButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            laterButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
        ])
    }
    
    private func showLoadingState() {
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
        statusLabel.isHidden = false
        
        titleLabel.isHidden = true
        messageLabel.isHidden = true
        viewNowButton.isHidden = true
        laterButton.isHidden = true
        closeButton.isHidden = true
    }
    
    private func showSuccessState(taskId: String) {
        // Animate transition
        UIView.animate(withDuration: 0.3) {
            self.activityIndicator.alpha = 0
            self.statusLabel.alpha = 0
        } completion: { _ in
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
            self.statusLabel.isHidden = true
            
            self.titleLabel.isHidden = false
            self.messageLabel.isHidden = false
            self.viewNowButton.isHidden = false
            self.laterButton.isHidden = false
            self.closeButton.isHidden = false
            
            // Store taskId in button tag or property if needed, but we can capture it in closure
            // Re-assign target to capture taskId
            self.viewNowButton.removeTarget(nil, action: nil, for: .allEvents)
            self.viewNowButton.addAction(UIAction { [weak self] _ in
                self?.openMainApp(taskId: taskId)
                self?.closeExtension()
            }, for: .touchUpInside)
            
            UIView.animate(withDuration: 0.3) {
                self.titleLabel.alpha = 1
                self.messageLabel.alpha = 1
                self.viewNowButton.alpha = 1
                self.laterButton.alpha = 1
                self.closeButton.alpha = 1
            }
        }
    }
    
    @objc private func handleViewNow() {
        // Placeholder, action replaced in showSuccessState
    }
    
    @objc private func handleLater() {
        closeExtension()
    }
    
    @objc private func handleClose() {
        closeExtension()
    }
 
     private func extractURLAndProcess() {
         guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
               let attachment = extensionItem.attachments?.first else {
             self.closeExtension()
             return
         }
         
         // Helper to safely process valid URL
         func handleValidURL(_ url: URL) {
             self.processShareURL(url)
         }
 
         if attachment.hasItemConformingToTypeIdentifier("public.url") {
             attachment.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (data, error) in
                 guard let self = self else { return }
                 if let url = data as? URL {
                     handleValidURL(url)
                 } else if let urlString = data as? String, let url = URL(string: urlString) {
                     handleValidURL(url)
                 } else {
                     self.closeExtension()
                 }
             }
         } else if attachment.hasItemConformingToTypeIdentifier("public.plain-text") {
             attachment.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (data, error) in
                 guard let self = self else { return }
                 if let text = data as? String, let url = URL(string: text), text.hasPrefix("http") {
                      handleValidURL(url)
                 } else {
                      self.closeExtension()
                 }
             }
         } else {
             self.closeExtension()
         }
     }
    
    private func processShareURL(_ url: URL) {
        print("🔗 [ShareExt] Processing URL: \(url)")
        
        // 模擬一點延遲讓使用者看到 Loading 動畫 (UX 優化)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendURLToPuboBackend(url: url) { [weak self] taskId in
                guard let self = self else { return }
                self.saveTaskLocally(taskId: taskId)
                
                DispatchQueue.main.async {
                    self.showSuccessState(taskId: taskId)
                }
            }
        }
    }

    private func openMainApp(taskId: String) {
        let url = URL(string: "pubo://task/\(taskId)")!
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = responder?.next
        }
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
    
    // Backend API Logic
    private func sendURLToPuboBackend(url: URL, completion: @escaping (String) -> Void) {
        // 使用 127.0.0.1 確保 IPv4 Loopback
        guard let backendURL = URL(string: "http://127.0.0.1:8000/api/v1/share") else { return }
        
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
                completion(UUID().uuidString)
            }
        }.resume()
    }
    
    private func closeExtension() {
        DispatchQueue.main.async {
            self.hideCardAnimation {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }
}

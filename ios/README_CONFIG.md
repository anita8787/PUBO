你有看到底下的 console 端嗎？它顯示錯誤，沒有辦法讀取該連結的訊息。 # Xcode Configuration Guide for Pubo

由於 Xcode 的專案檔 (`.xcodeproj`) 結構複雜，無法直接透過程式碼修改，請按照以下步驟手動設定。這只需設定一次。

## 1. 設定 App Groups (讓 App 與 Extension 共享資料)

這步是為了讓 **Share Extension** (分享選單) 能把資料傳給 **主 App**。

1.  打開 Xcode，點擊左側專案導航列最上方的 **Pubo** (藍色 icon)。
2.  在右側選擇 **TARGETS** 列表中的 **Pubo** (主程式)。
3.  點擊上方的 **Signing & Capabilities** 頁籤。
4.  點擊左上角的 **+ Capability**。
5.  搜尋並雙擊 **App Groups**。
6.  在 App Groups 區塊中，點擊 **+** 號。
7.  輸入 Group ID：`group.com.anita.Pubo` (請確保與程式碼中的 `appGroupId` 一致)。
8.  **勾選** 剛剛新增的 Group ID（會變成藍色）。
    > 若顯示紅色錯誤，請確認你的 Apple Developer Account 有權限，或更換一個獨一無二的 ID (例如加入你的英文名)。若更換 ID，記得回到 `ShareViewController.swift` 修改程式碼。

**接下來，對 Share Extension 做一樣的事：**

1.  在 **TARGETS** 列表中選擇 **PuboShare**。
2.  點擊 **Signing & Capabilities** -> **+ Capability** -> **App Groups**。
3.  這裡應該會直接看到剛剛建立的 `group.com.anita.Pubo`。
4.  **直接勾選** 它即可。

---

## 2. 設定 URL Scheme (讓 Extension 能喚醒 App)

這步是為了讓 **「立即查看」** 按鈕能自動打開 Pubo App。

1.  回到 **TARGETS** -> **Pubo** (主程式)。
2.  點擊上方的 **Info** 頁籤。
3.  展開最下方的 **URL Types** (若沒看到，點擊該區塊右下角的 + 號)。
4.  在 **URL Schemes** 欄位輸入：`pubo`。
5.  **Identifier** 可以填：`com.anita.Pubo`。
6.  (Role 保持 Editor 即可)。

---

## 3. 允許 Localhost 連線 (僅限開發測試)

如果你要在模擬器連線到電腦上的 Backend (http://localhost:8000)，必須做這個設定，否則 Apple 會擋掉非 HTTPS 的連線。

1.  在左側檔案列表中，找到 **Pubo** 資料夾下的 `Info.plist` 檔案。
2.  右鍵點擊空白處 -> **Add Row**。
3.  選擇 **App Transport Security Settings**。
4.  展開這個新項目 (點擊左邊的小箭頭)。
5.  在裡面 Add Row -> **Allow Arbitrary Loads**。
6.  將其值設為 **YES**。

*(注意：正式上線前，請改回 NO 並配置 HTTPS 憑證)*

---

## 4. 驗證

完成後，按 `Cmd + R` 執行 App。
1.  打開 Safari，隨便找個網頁。
2.  點擊分享按鈕 (Share Sheet)。
3.  找到 **Pubo** Icon (可能在 "更多..." 裡)。
4.  點擊後，應該會看到我們做的「立即查看」選項。
5.  點擊「立即查看」-> 應該會自動跳轉回 Pubo App。

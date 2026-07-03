//
//  GeraniumApp.swift
//  Andromeda
//
//  Developed by son3ra1n.
//  完整移植 hide-my-tab 全部功能：远程停用 + 激活码验证 + 免责声明
//

import SwiftUI
import UIKit

// MARK: - 全局配置（与原版插件完全一致）
private let kActivateCodes: [String] = [
    "xiannvbenxian",
    "fengzheng",
    "wushaoshe"
]

private let kRemoteStatusURL = "https://gitee.com/huang-xuxuxuxu/hide-my-tab-control/raw/master/status.json"
private let kCheckInterval: TimeInterval = 60 // 每分钟检测一次
private let kNetworkTimeout: TimeInterval = 5 // 网络超时5秒
private let kActivateValidDays: TimeInterval = 30 * 24 * 3600 // 激活有效期30天

// MARK: - 全局状态
private var gIsRemoteDisabled = false
private var gHasCheckedRemoteStatus = false
private var gTimer: Timer?

@main
struct GeraniumApp: App {
    @StateObject private var appSettings = AppSettings()
    @State private var showContent = false
    @State private var window: UIWindow?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showContent {
                    ContentView()
                } else {
                    Color.black
                        .ignoresSafeArea()
                }
            }
            .onAppear {
                setupWindow()
                startLaunchFlow()
            }
        }
    }
    
    private func setupWindow() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        self.window = windowScene.windows.first(where: { $0.isKeyWindow })
    }
    
    // MARK: - 启动流程（完全对齐原版插件顺序）
    private func startLaunchFlow() {
        // 第一步：检查远程状态
        checkRemoteStatus { enabled in
            gHasCheckedRemoteStatus = true
            
            if !enabled {
                gIsRemoteDisabled = true
                showDisabledAlert()
                return
            }
            
            // 第二步：启动定时轮询
            startPeriodicCheck()
            
            // 第三步：弹出免责声明
            showDisclaimerAlert()
        }
    }
    
    // MARK: - 远程状态检查
    private func checkRemoteStatus(completion: @escaping (Bool) -> Void) {
        let timestamp = Date().timeIntervalSince1970
        guard let url = URL(string: "\(kRemoteStatusURL)?t=\(Int(timestamp))") else {
            completion(true)
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: kNetworkTimeout)
        request.httpShouldHandleCookies = false
        
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            var enabled = true // 网络错误默认不影响使用
            
            if let data = data, error == nil {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let enabledNum = json["enabled"] as? NSNumber {
                    enabled = enabledNum.boolValue
                } else if let num = try? JSONSerialization.jsonObject(with: data) as? NSNumber {
                    enabled = num.boolValue
                }
            }
            
            DispatchQueue.main.async {
                completion(enabled)
            }
        }
        task.resume()
    }
    
    // MARK: - 定时循环检测
    private func startPeriodicCheck() {
        gTimer?.invalidate()
        gTimer = Timer.scheduledTimer(withTimeInterval: kCheckInterval, repeats: true) { _ in
            if gIsRemoteDisabled {
                gTimer?.invalidate()
                return
            }
            checkRemoteStatus { enabled in
                if !enabled {
                    DispatchQueue.main.async {
                        gIsRemoteDisabled = true
                        showDisabledAlert()
                    }
                }
            }
        }
    }
    
    // MARK: - 远程停用弹窗
    private func showDisabledAlert() {
        let alert = UIAlertController(title: "⚠️ 已停用", message: "该软件已被停用，请联系乌梢蛇处理。", preferredStyle: .alert)
        let exitAction = UIAlertAction(title: "退出", style: .destructive) { _ in
            safeExit()
        }
        alert.addAction(exitAction)
        
        guard let rootVC = window?.rootViewController else {
            safeExit()
            return
        }
        
        rootVC.dismiss(animated: false)
        rootVC.present(alert, animated: true)
        
        // 5秒后强制安全退出
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            safeExit()
        }
    }
    
    // MARK: - 安全退出（跳转到系统设置）
    private func safeExit() {
        guard let url = URL(string: "prefs:root=General") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    // MARK: - 免责声明弹窗
    private func showDisclaimerAlert() {
        let alert = UIAlertController(title: "声明", message: "", preferredStyle: .alert)
        
        let messageText = """
        该软件仅用于内部使用，切勿传播，勿用于非法用途，违者后果自负。

        软件有问题联系【乌梢蛇】处理，其他问题一概不知。
        """
        let attrMessage = NSMutableAttributedString(
            string: messageText,
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 17),
                .foregroundColor: UIColor.black
            ]
        )
        alert.setValue(attrMessage, forKey: "attributedMessage")
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { _ in
            safeExit()
        }
        
        let agreeAction = UIAlertAction(title: "我已知晓", style: .default) { _ in
            // 检查激活状态
            showRemainingDaysAlert {
                if needActivate() {
                    showActivateAlert()
                } else {
                    // 验证通过，进入主界面
                    withAnimation {
                        showContent = true
                    }
                }
            }
        }
        agreeAction.setValue(UIColor.red, forKey: "titleTextColor")
        
        alert.addAction(cancelAction)
        alert.addAction(agreeAction)
        
        window?.rootViewController?.present(alert, animated: true)
    }
    
    // MARK: - 剩余天数检查
    private func getRemainingDays() -> Int {
        let ud = UserDefaults.standard
        guard let lastTime = ud.object(forKey: "hmt_last_activate_time") as? Double else {
            return 0
        }
        let now = Date().timeIntervalSince1970
        let elapsed = now - lastTime
        if elapsed >= kActivateValidDays {
            return 0
        } else {
            return Int(ceil((kActivateValidDays - elapsed) / 86400))
        }
    }
    
    private func needActivate() -> Bool {
        return getRemainingDays() == 0
    }
    
    private func saveActivateTime() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "hmt_last_activate_time")
        UserDefaults.standard.synchronize()
    }
    
    private func showRemainingDaysAlert(completion: @escaping () -> Void) {
        let days = getRemainingDays()
        let message = days == 0 ? "您的激活已过期，请重新激活" : "剩余激活天数：\(days)天"
        
        let alert = UIAlertController(title: "激活状态", message: message, preferredStyle: .alert)
        window?.rootViewController?.present(alert, animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                alert.dismiss(animated: true) {
                    completion()
                }
            }
        }
    }
    
    // MARK: - 激活码弹窗
    private func showActivateAlert() {
        let alert = UIAlertController(title: "激活验证", message: "请输入激活码", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "请输入激活码"
            tf.isSecureTextEntry = true
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { _ in
            safeExit()
        }
        
        let confirmAction = UIAlertAction(title: "确认激活", style: .default) { _ in
            let input = alert.textFields?.first?.text ?? ""
            let isValid = kActivateCodes.contains(input)
            
            if isValid {
                saveActivateTime()
                showToast("✅ 激活成功，有效期30天", color: UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1))
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        showContent = true
                    }
                }
            } else {
                showToast("❌ 验证码错误，请重试", color: UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showActivateAlert()
                }
            }
        }
        
        alert.addAction(cancelAction)
        alert.addAction(confirmAction)
        window?.rootViewController?.present(alert, animated: true)
    }
    
    // MARK: - Toast提示
    private func showToast(_ message: String, color: UIColor) {
        guard let window = window else { return }
        
        window.subviews.forEach { if $0.tag == 9999 { $0.removeFromSuperview() } }
        
        let label = UILabel()
        label.tag = 9999
        label.text = message
        label.textColor = .white
        label.backgroundColor = color
        label.textAlignment = .center
        label.font = .boldSystemFont(ofSize: 16)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        
        let size = message.boundingRect(
            with: CGSize(width: 280, height: 999),
            options: .usesLineFragmentOrigin,
            attributes: [.font: label.font],
            context: nil
        ).size
        
        label.frame = CGRect(x: 0, y: 0, width: size.width + 32, height: size.height + 16)
        label.center = CGPoint(x: window.center.x, y: window.center.y - 60)
        window.addSubview(label)
        
        UIView.animate(withDuration: 0.3, delay: 2, options: .curveEaseIn) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }
    }
}

// MARK: - 配置类（保留原版必要项）
class AppSettings: ObservableObject {
    @AppStorage("TSBypass") var tsBypass: Bool = false
    @AppStorage("UPDBypass") var updBypass: Bool = false
    @AppStorage("LocSimAttempts") var locSimAttemptNB: Int = 1
    @AppStorage("locSimMultipleAttempts") var locSimMultipleAttempts: Bool = false
    @AppStorage("usrUUID") var usrUUID: String = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    @AppStorage("languageCode") var languageCode: String = ""
}

var langaugee: String = {
    if AppSettings().languageCode.isEmpty {
        return "\(Locale.current.languageCode ?? "zh-CN")"
    }
    else {
        return "\(Locale.current.languageCode ?? "zh")-\(AppSettings().languageCode)"
    }
}()

// 沙盒检测（保留原版权限验证）
func checkSandbox() -> Bool {
    let fileManager = FileManager.default
    let testPath = "/var/mobile/Documents/test_sandbox.tmp"
    do {
        try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
        try fileManager.removeItem(atPath: testPath)
        return false
    } catch {
        return true
    }
}

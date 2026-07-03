//
//  GeraniumApp.swift
//  Andromeda
//
//  Developed by son3ra1n.
//  Modified: 仅保留位置模拟核心启动逻辑
//

import SwiftUI

@main
struct GeraniumApp: App {
    @StateObject private var appSettings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 保留原有的TrollStore安装验证逻辑
                    if checkSandbox(), !appSettings.tsBypass {
                        UIApplication.shared.alert(
                            title:"Andromeda wasn't installed with TrollStore",
                            body:"Unable to create test file. The app cannot work without the correct entitlements. Please use TrollStore to install it.",
                            withButton:true
                        )
                    }
                    // 保留底层核心服务初始化
                    _ = RootHelper.loadMCM()
                }
        }
    }
}

// 保留原配置类，仅保留位置模拟相关的配置项
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
        return "\(Locale.current.languageCode ?? "en-US")"
    }
    else {
        return "\(Locale.current.languageCode ?? "en")-\(AppSettings().languageCode)"
    }
}()

// 沙盒检测函数（保留原验证逻辑）
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

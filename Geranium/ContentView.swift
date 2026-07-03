//
//  ContentView.swift
//  Andromeda
//
//  Developed by son3ra1n.
//  Modified: 仅保留位置模拟核心功能
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // 直接加载位置模拟页面，彻底移除底部Tab栏
        LocSimView()
            .ignoresSafeArea(.all, edges: .bottom)
            .onAppear {
                // 启动时自动初始化位置模拟核心服务
                LocSimManager.shared.preloadService()
            }
    }
}

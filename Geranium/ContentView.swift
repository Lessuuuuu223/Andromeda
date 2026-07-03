//
//  ContentView.swift
//  Andromeda
//
//  Developed by son3ra1n.
//  移植 hide-my-tab Tab隐藏能力，仅保留位置模拟单页面
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        LocSimView()
            .ignoresSafeArea(.all, edges: .all)
            .gesture(DragGesture().onChanged { _ in }) // 禁用侧滑返回
            .onAppear {
                LocSimManager.shared.preloadService()
            }
    }
}

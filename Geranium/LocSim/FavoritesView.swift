//
//  FavoritesView.swift
//  Andromeda
//
//  Developed by son3ra1n.
//

import SwiftUI
import MapKit
import AlertKit

struct FavoritesView: View {
    @Binding var isPresented: Bool
    var currentLat: Double
    var currentLong: Double
    var onSelect: (Double, Double, String) -> Void
    
    @State private var bookmarks: [[String: Any]] = []
    @State private var showAddSheet = false
    @State private var newName = ""
    
    let categoryIcons: [String: String] = [
        "Home": "house.fill",
        "Work": "briefcase.fill",
        "Gym": "figure.run",
        "School": "graduationcap.fill"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [Color.indigo.opacity(0.08), Color.black.opacity(0.03)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                if bookmarks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("还没有收藏")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("点右上角 + 保存当前位置")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                } else {
                    List {
                        ForEach(Array(bookmarks.enumerated()), id: \.offset) { index, bookmark in
                            let name = bookmark["name"] as? String ?? "Unknown"
                            let lat = bookmark["lat"] as? Double ?? 0
                            let long = bookmark["long"] as? Double ?? 0
                            
                            Button(action: {
                                onSelect(lat, long, name)
                                isPresented = false
                            }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(categoryColor(for: name).opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: categoryIcons[name] ?? "mappin.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(categoryColor(for: name))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(name)
                                            .font(.system(size: 15, weight: .semibold))
                                        Text("\(String(format: "%.4f", lat)), \(String(format: "%.4f", long))")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.indigo)
                                        .padding(8)
                                        .background(Color.indigo.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteBookmark)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.indigo)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addFavoriteSheet()
            }
            .onAppear {
                bookmarks = BookMarkRetrieve()
            }
        }
    }
    
    @ViewBuilder
    private func addFavoriteSheet() -> some View {
        NavigationView {
            Form {
                Section(header: Text("位置名称")) {
                    TextField("例如：家、公司、公园...", text: $newName)
                }
                Section(header: Text("当前位置"), footer: Text("将自动保存你当前模拟的坐标。")) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.indigo)
                        Text("\(String(format: "%.6f", currentLat)), \(String(format: "%.6f", currentLong))")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                Section {
                    Button(action: saveFavorite) {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("保存当前位置")
                        }
                        .foregroundColor(.indigo)
                    }
                    .disabled(newName.isEmpty)
                }
            }
            .navigationTitle("添加收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { showAddSheet = false }
                }
            }
        }
    }
    
    private func saveFavorite() {
        let _ = BookMarkSave(lat: currentLat, long: currentLong, name: newName)
        bookmarks = BookMarkRetrieve()
        newName = ""
        showAddSheet = false
        AlertKitAPI.present(title: "已保存！", icon: .done, style: .iOS17AppleMusic, haptic: .success)
    }
    
    private func deleteBookmark(at offsets: IndexSet) {
        var allBookmarks = BookMarkRetrieve()
        allBookmarks.remove(atOffsets: offsets)
        let sharedUserDefaults = UserDefaults(suiteName: sharedUserDefaultsSuiteName)
        sharedUserDefaults?.set(allBookmarks, forKey: "bookmarks")
        bookmarks = allBookmarks
    }
    
    private func categoryColor(for name: String) -> Color {
        switch name.lowercased() {
        case let n where n.contains("home"): return .green
        case let n where n.contains("work"): return .blue
        case let n where n.contains("gym"): return .orange
        case let n where n.contains("school"): return .purple
        default: return .indigo
        }
    }
}

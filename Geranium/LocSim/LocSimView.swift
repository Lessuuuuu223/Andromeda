//
//  LocSimView.swift
//  Andromeda
//
//  Developed by son3ra1n.
//  完整汉化 + 集成 hide-my-tab 双击全屏隐藏功能
//

import SwiftUI
import CoreLocation
import MapKit
import AlertKit

struct LocSimView: View {
    @StateObject private var appSettings = AppSettings()
    @StateObject private var routeSimulator = RouteSimulator()
    
    @State private var locationManager = CLLocationManager()
    @State private var lat: Double = 0.0
    @State private var long: Double = 0.0
    @State private var altitude: String = "0.0"
    @State private var tappedCoordinate: EquatableCoordinate? = nil
    @State private var bookmarkSheetToggle: Bool = false
    @State private var showRouteSheet: Bool = false
    @State private var showSearchBar: Bool = false
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching: Bool = false
    @State private var mapRegion: MKCoordinateRegion? = nil
    
    // 摇杆功能
    @State private var joystickActive: Bool = false
    @State private var joystickCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
    
    // 收藏夹
    @State private var showFavorites: Bool = false
    
    // 应用独立配置
    @State private var showAppProfiles: Bool = false
    
    // 定时停止
    @State private var showTimerPicker: Bool = false
    @State private var timerRemaining: Int = 0
    @State private var timerActive: Bool = false
    @State private var simTimer: Timer? = nil
    
    // hide-my-tab 双击全屏隐藏功能
    @State private var isFullScreenMode = false
    
    var body: some View {
        LocSimMainView()
    }
    
    @ViewBuilder
    private func LocSimMainView() -> some View {
        ZStack(alignment: .topTrailing) {
            // MARK: - 主地图视图
            CustomMapView(tappedCoordinate: $tappedCoordinate, moveToRegion: $mapRegion, routePolyline: routeSimulator.routePolyline, allRoutePolylines: routeSimulator.allRoutePolylines, selectedRouteIndex: routeSimulator.selectedRouteIndex, movingPosition: routeSimulator.currentPosition)
                .onAppear {
                    CLLocationManager().requestAlwaysAuthorization()
                }
                .onChange(of: tappedCoordinate) { newCoord in
                    guard let coord = newCoord else { return }
                    let altitudeValue = Double(altitude) ?? 0.0
                    startSimulation(at: coord.coordinate, altitude: altitudeValue)
                }
                .ignoresSafeArea(.all, edges: [.top, .leading, .trailing])
                // 双击切换全屏隐藏
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isFullScreenMode.toggle()
                    }
                }
            
            // MARK: - 顶部搜索栏
            if showSearchBar {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("搜索地址...", text: $searchText, onCommit: {
                            searchAddress()
                        })
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button(action: {
                            withAnimation {
                                showSearchBar = false
                                searchText = ""
                                searchResults = []
                            }
                        }) {
                            Text("取消")
                                .font(.subheadline)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    // 搜索结果列表
                    if !searchResults.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(searchResults, id: \.self) { item in
                                    Button(action: {
                                        selectSearchResult(item)
                                    }) {
                                        HStack {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.title3)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name ?? "未知地点")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                if let address = item.placemark.title {
                                                    Text(address)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                    Divider()
                                        .padding(.leading, 44)
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
                .opacity(isFullScreenMode ? 0 : 1)
            }
            
            // MARK: - 右侧功能按钮
            VStack(spacing: 12) {
                Button(action: { showSearchBar.toggle() }) {
                    controlIcon(systemName: "magnifyingglass", color: .purple)
                }
                
                Button(action: { showFavorites.toggle() }) {
                    controlIcon(systemName: "star.fill", color: .orange)
                }
                
                Button(action: { showAppProfiles.toggle() }) {
                    controlIcon(systemName: "app.fill", color: .blue)
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        joystickActive.toggle()
                        if joystickActive {
                            joystickCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                        }
                    }
                }) {
                    controlIcon(systemName: "gamecontroller.fill", color: .green)
                }
                
                Button(action: { showRouteSheet.toggle() }) {
                    controlIcon(systemName: "car.fill", color: .blue)
                }
                
                Button(action: {
                    UIApplication.shared.TextFieldAlert(
                        title: "设置海拔",
                        message: "请输入海拔高度（单位：米）",
                        textFieldPlaceHolder: "海拔高度"
                    ) { altitudeText, _ in
                        if let altText = altitudeText, !altText.isEmpty {
                            self.altitude = altText
                            AlertKitAPI.present(title: "海拔已设置", icon: .done, style: .iOS17AppleMusic, haptic: .success)
                        }
                    }
                }) {
                    controlIcon(systemName: "mountain.2.fill", color: .purple)
                }
                
                Button(action: { showTimerPicker = true }) {
                    controlIcon(systemName: "timer", color: .orange)
                }
                
                Button(action: { stopSimulation() }) {
                    controlIcon(systemName: "stop.fill", color: .red)
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 60)
            .opacity(isFullScreenMode ? 0 : 1)
            
            // MARK: - 摇杆悬浮面板
            if joystickActive {
                JoystickView(
                    isActive: $joystickActive,
                    onMove: { newCoord in
                        joystickCoordinate = newCoord
                        let location = CLLocation(coordinate: newCoord, altitude: Double(altitude) ?? 0, horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: Date())
                        LocSimManager.startLocSim(location: location)
                        lat = newCoord.latitude
                        long = newCoord.longitude
                    },
                    currentCoordinate: $joystickCoordinate
                )
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .opacity(isFullScreenMode ? 0 : 1)
            }
            
            // MARK: - 定时倒计时显示
            if timerActive {
                VStack {
                    Spacer()
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "timer")
                                .foregroundColor(.orange)
                            Text(timerString())
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                            Button(action: { cancelTimer() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.15), radius: 8)
                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 20)
                }
                .opacity(isFullScreenMode ? 0 : 1)
            }
        }
        .statusBar(hidden: isFullScreenMode)
        .sheet(isPresented: $bookmarkSheetToggle) {
            BookMarkSlider(lat: $lat, long: $long)
        }
        .sheet(isPresented: $showRouteSheet) {
            RouteSimSheet(routeSimulator: routeSimulator, mapRegion: $mapRegion, isPresented: $showRouteSheet)
        }
        .sheet(isPresented: $showFavorites) {
            FavoritesView(isPresented: $showFavorites, currentLat: lat, currentLong: long) { favLat, favLong, name in
                let coord = CLLocationCoordinate2D(latitude: favLat, longitude: favLong)
                let region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                mapRegion = region
                startSimulation(at: coord, altitude: Double(altitude) ?? 0.0)
                AlertKitAPI.present(title: "📍 \(name)", icon: .done, style: .iOS17AppleMusic, haptic: .success)
            }
        }
        .actionSheet(isPresented: $showTimerPicker) {
            ActionSheet(title: Text("自动停止计时"), message: Text("定位模拟将在设定时间后自动关闭"), buttons: [
                .default(Text("15 分钟")) { startTimer(minutes: 15) },
                .default(Text("30 分钟")) { startTimer(minutes: 30) },
                .default(Text("1 小时")) { startTimer(minutes: 60) },
                .default(Text("2 小时")) { startTimer(minutes: 120) },
                .cancel(Text("取消"))
            ])
        }
        .sheet(isPresented: $showAppProfiles) {
            AppProfilesView(isPresented: $showAppProfiles, currentLat: lat, currentLong: long) { profLat, profLong, name in
                let coord = CLLocationCoordinate2D(latitude: profLat, longitude: profLong)
                let region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                mapRegion = region
                startSimulation(at: coord, altitude: Double(altitude) ?? 0.0)
                AlertKitAPI.present(title: name, icon: .done, style: .iOS17AppleMusic, haptic: .success)
            }
        }
    }
    
    private func startSimulation(at gcjCoordinate: CLLocationCoordinate2D, altitude: Double) {
        let wgsCoordinate = CoordTransform.gcj02ToWgs84(gcjCoordinate)
        
        self.lat = wgsCoordinate.latitude
        self.long = wgsCoordinate.longitude
        
        let location = CLLocation(coordinate: wgsCoordinate, altitude: altitude, horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: Date())
        LocSimManager.startLocSim(location: location)
        
        joystickCoordinate = wgsCoordinate
        
        AlertKitAPI.present(
            title: "定位模拟已启动",
            icon: .done,
            style: .iOS17AppleMusic,
            haptic: .success
        )
    }
    
    // MARK: - 地址搜索
    private func searchAddress() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        searchResults = []
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                if let response = response {
                    searchResults = response.mapItems
                } else {
                    UIApplication.shared.alert(body: "未找到 '\(searchText)' 相关结果")
                }
            }
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        let altitudeValue = Double(altitude) ?? 0.0
        
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapRegion = region
        
        startSimulation(at: coordinate, altitude: altitudeValue)
        
        showSearchBar = false
        searchText = ""
        searchResults = []
    }
    
    // MARK: - 定时功能
    private func startTimer(minutes: Int) {
        timerRemaining = minutes * 60
        timerActive = true
        simTimer?.invalidate()
        simTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timerRemaining > 0 {
                timerRemaining -= 1
            } else {
                stopSimulation()
                cancelTimer()
            }
        }
        AlertKitAPI.present(title: "计时已启动：\(minutes) 分钟", icon: .done, style: .iOS17AppleMusic, haptic: .success)
    }
    
    private func cancelTimer() {
        simTimer?.invalidate()
        simTimer = nil
        timerActive = false
        timerRemaining = 0
    }
    
    private func timerString() -> String {
        let h = timerRemaining / 3600
        let m = (timerRemaining % 3600) / 60
        let s = timerRemaining % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
    
    private func stopSimulation() {
        LocSimManager.stopLocSim()
        joystickActive = false
        cancelTimer()
        AlertKitAPI.present(title: "定位模拟已停止", icon: .done, style: .iOS17AppleMusic, haptic: .success)
    }
    
    // MARK: - 按钮样式
    private func controlIcon(systemName: String, color: Color = .indigo) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(color.opacity(0.9))
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

//
//  ContentView.swift
//  Andromeda
//
import SwiftUI
import CryptoKit
import Foundation

// MARK: - 卡密验证配置
enum KamiConfig {
    // 远程卡密列表地址（Gitee 仓库里的 kami.txt 原始文件）
    static let remoteURL = "https://gitee.com/huang-xuxuxuxu/hide-my-tab-control/raw/master/kami.txt"
    // 远程公告地址（Gitee 仓库里的 notice.txt 原始文件）
    static let noticeURL = "https://gitee.com/huang-xuxuxuxu/hide-my-tab-control/raw/master/notice.txt"
    // 网络请求最长等待时间（秒）
    static let timeout: TimeInterval = 60
    // 公告请求等待时间（秒），失败不影响启动
    static let noticeTimeout: TimeInterval = 10
}

// 远程公告：开关 + 标题 + 正文
struct KamiNotice {
    var on: Bool = false
    var title: String = ""
    var body: String = ""
}

// 远程配置：总开关 + 卡密哈希表（值为到期截止时间，nil = 永久）
struct KamiRemoteConfig {
    var switchOn: Bool = true
    var cards: [String: Date?] = [:]
}

enum KamiAuth {
    // 输入卡密 → 规范化（去空格、转大写）→ SHA256 十六进制
    static func sha256(_ s: String) -> String {
        let normalized = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // 拉取并解析远程 kami.txt
    static func fetchConfig() async throws -> KamiRemoteConfig {
        guard var comps = URLComponents(string: KamiConfig.remoteURL) else { throw URLError(.badURL) }
        comps.queryItems = [URLQueryItem(name: "t", value: "\(Int(Date().timeIntervalSince1970))")]
        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = KamiConfig.timeout
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let rawText = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        let text = rawText.replacingOccurrences(of: "\u{FEFF}", with: "")

        var cfg = KamiRemoteConfig()
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        df.dateFormat = "yyyy-MM-dd"

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.uppercased().hasPrefix("SWITCH") {
                cfg.switchOn = line.uppercased().contains("TRUE")
                continue
            }
            let parts = line.components(separatedBy: "|")
            let hash = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            guard hash.count == 64 else { continue }
            var deadline: Date? = nil
            if parts.count > 1 {
                let dateStr = parts[1].trimmingCharacters(in: .whitespaces)
                if let d = df.date(from: dateStr) {
                    // 到期日当天仍可用：截止时间为次日零点
                    deadline = Calendar.current.date(byAdding: .day, value: 1, to: d)
                }
            }
            cfg.cards[hash] = deadline
        }
        return cfg
    }

    // 拉取并解析远程 notice.txt
    // 格式：第1行 ON=true/false；第2行 标题；其余行 正文
    // 拉取失败 / 开关关闭 / 正文为空 → 返回 nil（不弹窗，也不影响启动）
    static func fetchNotice() async -> KamiNotice? {
        guard var comps = URLComponents(string: KamiConfig.noticeURL) else { return nil }
        comps.queryItems = [URLQueryItem(name: "t", value: "\(Int(Date().timeIntervalSince1970))")]
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = KamiConfig.noticeTimeout

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let rawText = String(data: data, encoding: .utf8) else { return nil }

        let text = rawText.replacingOccurrences(of: "\u{FEFF}", with: "")
        let lines = text.components(separatedBy: .newlines)
        guard let head = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              head.uppercased().hasPrefix("ON") else { return nil }

        var notice = KamiNotice()
        notice.on = head.uppercased().contains("TRUE")
        guard notice.on else { return nil }

        let rest = lines.dropFirst()
        let title = rest.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        notice.title = title.isEmpty ? "公告" : title
        notice.body = rest.dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return notice.body.isEmpty ? nil : notice
    }

    // 校验卡密：返回 nil 表示有效，否则为错误提示文案
    static func validate(code: String, in cfg: KamiRemoteConfig) -> String? {
        let h = sha256(code)
        guard let deadline = cfg.cards[h] else { return "卡密无效或不存在" }
        if let d = deadline, Date() >= d { return "卡密已过期" }
        return nil
    }
}

struct ContentView: View {
    @AppStorage("kamiActivated") private var kamiActivated = false
    @AppStorage("kamiCode") private var kamiCode = ""
    @State private var remoteDisabled = false
    @State private var networkFailed = false
    @State private var checked = false
    @State private var disclaimerAccepted = false   // 每次启动都需重新确认
    @State private var notice: KamiNotice? = nil     // 远程公告（为空则不弹）
    @State private var noticeDismissed = false

    var body: some View {
        Group {
            if remoteDisabled {
                DisabledView()
            } else if networkFailed {
                NetworkErrorView()
            } else if !checked {
                VerifyingView()
            } else if !disclaimerAccepted {
                DisclaimerView(onAgree: { disclaimerAccepted = true })
            } else if let n = notice, !noticeDismissed {
                NoticeView(notice: n) { noticeDismissed = true }
            } else if kamiActivated {
                LocSimView()
            } else {
                KeyAuthView()
            }
        }
        .task { await startupCheck() }
    }

    // 启动检查：必须先联网拉取远程配置
    // 成功：检查总开关 + 已激活卡密静默复查（卡被删/过期则踢回激活页）
    // 失败：提示检查网络并退出App
    private func startupCheck() async {
        async let noticeTask = KamiAuth.fetchNotice()
        do {
            let cfg = try await KamiAuth.fetchConfig()
            let fetchedNotice = await noticeTask
            await MainActor.run {
                if !cfg.switchOn {
                    remoteDisabled = true
                    return
                }
                if kamiActivated, KamiAuth.validate(code: kamiCode, in: cfg) != nil {
                    kamiActivated = false
                }
                notice = fetchedNotice
                checked = true
            }
        } catch {
            await MainActor.run {
                networkFailed = true
            }
        }
    }
}

// MARK: - 启动验证中的加载页
struct VerifyingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
            Text("正在验证，请稍候…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 网络异常页（提示后自动退出App）
struct NetworkErrorView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                    .padding(.top, 26)

                Text("网络连接失败")
                    .font(.title3)
                    .bold()
                    .padding(.top, 12)

                Text("请检查网络连接后重新打开APP")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                Divider()
                    .padding(.top, 22)

                Button(action: { exit(0) }) {
                    Text("确定")
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 52)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 44)
        }
        .onAppear {
            // 3 秒后自动退出，期间点「确定」立即退出
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                exit(0)
            }
        }
    }
}

// MARK: - 启动公告弹窗（每次启动弹出，已知=进入，取消=退出App）
struct DisclaimerView: View {
    var onAgree: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                    .padding(.top, 26)

                Text("使用须知")
                    .font(.title3)
                    .bold()
                    .padding(.top, 12)

                (
                    Text("该应用仅供内部群测试使用，严禁流传。\n如虚拟定位有问题，请联系你上级处理，其他问题一概不知！by:")
                        .foregroundColor(.secondary)
                    + Text("冰美式")
                        .foregroundColor(.red)
                        .bold()
                )
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                Divider()
                    .padding(.top, 22)

                HStack(spacing: 0) {
                    Button(action: { exit(0) }) {
                        Text("取消")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    Divider()
                    Button(action: onAgree) {
                        Text("已知")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 52)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 44)
        }
    }
}

// MARK: - 远程公告弹窗（内容来自 Gitee 的 notice.txt）
struct NoticeView: View {
    let notice: KamiNotice
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.indigo)
                    .padding(.top, 26)

                Text(notice.title)
                    .font(.title3)
                    .bold()
                    .padding(.top, 12)

                ScrollView {
                    Text(notice.body)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                }
                .frame(maxHeight: 260)

                Divider()

                Button(action: onClose) {
                    Text("知道了")
                        .font(.headline)
                        .foregroundColor(.indigo)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 52)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 44)
        }
    }
}

// MARK: - 卡密激活页
struct KeyAuthView: View {
    @AppStorage("kamiActivated") private var kamiActivated = false
    @AppStorage("kamiCode") private var kamiCode = ""
    @State private var input = ""
    @State private var loading = false
    @State private var errorMsg = ""

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 46))
                .foregroundColor(.indigo)
            Text("卡密激活")
                .font(.title)
                .bold()
            Text("请输入卡密后点击激活")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("KAMI-XXXX-XXXX-XXXX", text: $input)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .padding(.horizontal, 40)
            if !errorMsg.isEmpty {
                Text(errorMsg)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
            Button(action: activate) {
                Group {
                    if loading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("激  活")
                            .bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.indigo))
                .foregroundColor(.white)
            }
            .disabled(loading || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 40)
            Spacer()
        }
        .padding()
    }

    private func activate() {
        errorMsg = ""
        loading = true
        Task {
            do {
                let cfg = try await KamiAuth.fetchConfig()
                await MainActor.run {
                    loading = false
                    if !cfg.switchOn {
                        errorMsg = "服务已停用，请联系提供方"
                        return
                    }
                    if let err = KamiAuth.validate(code: input, in: cfg) {
                        errorMsg = err
                        return
                    }
                    kamiCode = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    kamiActivated = true
                }
            } catch {
                await MainActor.run {
                    loading = false
                    errorMsg = "网络错误，请检查网络后重试"
                }
            }
        }
    }
}

// MARK: - 全员停用页（弹窗提示后自动退出App）
struct DisabledView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                    .padding(.top, 26)

                Text("已停用")
                    .font(.title3)
                    .bold()
                    .padding(.top, 12)

                Text("该应用已停止使用。\n如有疑问，请联系你上级。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                Divider()
                    .padding(.top, 22)

                Button(action: { exit(0) }) {
                    Text("确定")
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 52)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 44)
        }
        .onAppear {
            // 3 秒后自动退出，期间点「确定」立即退出
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                exit(0)
            }
        }
    }
}

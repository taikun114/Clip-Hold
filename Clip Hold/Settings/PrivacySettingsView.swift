import SwiftUI
import AppKit
import UniformTypeIdentifiers
import UserNotifications

struct PrivacySettingsView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    @ObservedObject private var accessibilityChecker = AccessibilityPermissionChecker.shared
    
    @AppStorage("isClipboardMonitoringPaused") var isClipboardMonitoringPaused: Bool = false {
        // isClipboardMonitoringPausedが変更されたときに監視状態を更新
        didSet {
            if isClipboardMonitoringPaused {
                clipboardManager.stopMonitoringPasteboard()
            } else {
                clipboardManager.startMonitoringPasteboard()
            }
            
            // 監視状態変更時の通知を送信
            NotificationManager.shared.sendMonitoringStatusNotification(isPaused: isClipboardMonitoringPaused)
            print("PrivacySettingsView didSet: Clipboard monitoring state changed to \(isClipboardMonitoringPaused ? "paused" : "resumed").")
        }
    }
    
    @AppStorage("excludedAppIdentifiersData") var excludedAppIdentifiersData: Data = Data()
    @State private var excludedAppIdentifiers: [String] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(excludedAppIdentifiers) {
                excludedAppIdentifiersData = encoded
            }
            clipboardManager.updateExcludedAppIdentifiers(excludedAppIdentifiers)
        }
    }
    
    @State private var isShowingAddAppPopover: Bool = false
    @State private var showAllRunningApps: Bool = false
    @State private var selectedExcludedAppId: String? = nil
    @State private var runningApplications: [NSRunningApplication] = []
    @State private var showingFinderPanel = false
    @State private var showingInvalidAppAlert = false
    
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    
    @State private var showingClearAllExcludedAppsConfirmation = false
    
    @State private var timer: Timer? = nil
    
    // MARK: - ヘルパー関数
    private func addAppToExclusionList(bundleIdentifier: String) {
        if !excludedAppIdentifiers.contains(bundleIdentifier) {
            excludedAppIdentifiers.append(bundleIdentifier)
            print("Excluded app added: \(bundleIdentifier)")
        } else {
            print("App already in exclusion list: \(bundleIdentifier)")
        }
    }
    
    private func removeAppFromExclusionList(bundleIdentifier: String) {
        excludedAppIdentifiers.removeAll { $0 == bundleIdentifier }
        print("Excluded app removed: \(bundleIdentifier)")
    }
    private func updateNotificationAuthorizationStatus() {
        NotificationManager.shared.getNotificationAuthorizationStatus { status in
            self.notificationAuthorizationStatus = status
        }
    }
    
    private func filterRunningApplications(applications: [NSRunningApplication]) -> [NSRunningApplication] {
        var filteredApps = applications.filter { app in
            // activationPolicy == .regular のアプリのみを表示するフィルタリングを追加
            let isRegularApp = app.activationPolicy == .regular
            
            if !showAllRunningApps {
                return isRegularApp
            }
            
            // showAllRunningApps が true の場合は、すべてのアプリを表示
            return true
        }
        
        // excludedAppIdentifiers に含まれるアプリを除外
        // これは showAllRunningApps の状態に関係なく行う
        filteredApps.removeAll { app in
            guard let bundleIdentifier = app.bundleIdentifier else { return false }
            return excludedAppIdentifiers.contains(bundleIdentifier)
        }
        
        return filteredApps
    }
    
    var body: some View {
        Form {
            Section(header: Text("クリップボード").font(.headline)) {
                HStack {
                    if differentiateWithoutColor {
                        Image(systemName: isClipboardMonitoringPaused ? "pause.fill" : "play.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundStyle(isClipboardMonitoringPaused ? .gray : .green)
                            .fontWeight(.bold)
                    } else {
                        Circle()
                            .fill(isClipboardMonitoringPaused ? Color.gray : Color.green)
                            .frame(width: 10, height: 10)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("クリップボード監視")
                        Text(isClipboardMonitoringPaused ? "一時停止中" : "動作中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        isClipboardMonitoringPaused.toggle()
                    }) {
                        HStack {
                            Image(systemName: isClipboardMonitoringPaused ? "play.fill" : "pause.fill")
                            Text(isClipboardMonitoringPaused ? "再開" : "一時停止")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help(isClipboardMonitoringPaused ? "クリップボード監視を再開します。" : "クリップボード監視を一時停止します。")
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            
            Section(header:
                        VStack(alignment: .leading, spacing: 4) {
                Text("権限")
                    .font(.headline)
                Text("一部の機能には、システムの許可が必要です。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ) {
                HStack {
                    if differentiateWithoutColor {
                        Image(systemName: notificationAuthorizationStatus == .authorized ? "checkmark" : "xmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundStyle(notificationAuthorizationStatus == .authorized ? .green : .red)
                            .fontWeight(.bold)
                    } else {
                        Circle()
                            .fill(notificationAuthorizationStatus == .authorized ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("通知")
                        Text("通知機能を使用する場合は許可を与える必要があります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    Button(action: {
                        if notificationAuthorizationStatus == .authorized {
                            NotificationManager.shared.sendTestNotification()
                        } else {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }) {
                        HStack {
                            if notificationAuthorizationStatus == .authorized {
                                Image(systemName: "bell.fill")
                            } else {
                                Image(systemName: "gearshape.fill")
                            }
                            Text(notificationAuthorizationStatus == .authorized ? "通知をテスト" : "設定を開く")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help(notificationAuthorizationStatus == .authorized ? "テスト通知を送信します。" : "システム設定の通知設定を開きます。")
                }
                .onChange(of: notificationAuthorizationStatus) { oldValue, newValue in
                    print("Notification permission status changed: \(newValue.rawValue)")
                }
                HStack {
                    if differentiateWithoutColor {
                        Image(systemName: accessibilityChecker.hasAccessibilityPermission ? "checkmark" : "xmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundStyle(accessibilityChecker.hasAccessibilityPermission ? .green : .red)
                            .fontWeight(.bold)
                    } else {
                        Circle()
                            .fill(accessibilityChecker.hasAccessibilityPermission ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("アクセシビリティ")
                        Text("クイックペースト機能を使用する場合は許可を与える必要があります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        accessibilityChecker.openSystemPreferences()
                    }) {
                        HStack {
                            Image(systemName: accessibilityChecker.hasAccessibilityPermission ? "checkmark" : "gearshape.fill")
                            Text(accessibilityChecker.hasAccessibilityPermission ? "許可済み" : "設定を開く")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(accessibilityChecker.hasAccessibilityPermission)
                    .help(accessibilityChecker.hasAccessibilityPermission ? "アクセシビリティ許可が付与されています。" : "システム設定のアクセシビリティ許可設定を開きます。")
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            
            // MARK: - 除外するアプリ セクション
            Section {
                List(selection: $selectedExcludedAppId) {
                    ForEach(excludedAppIdentifiers.sorted { id1, id2 in
                        let name1 = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id1)
                            .flatMap { Bundle(url: $0) }
                            .flatMap { $0.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? $0.localizedInfoDictionary?["CFBundleName"] as? String ?? $0.infoDictionary?["CFBundleName"] as? String }
                        
                        let name2 = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id2)
                            .flatMap { Bundle(url: $0) }
                            .flatMap { $0.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? $0.localizedInfoDictionary?["CFBundleName"] as? String ?? $0.infoDictionary?["CFBundleName"] as? String }
                        
                        switch (name1, name2) {
                        case let (.some(n1), .some(n2)):
                            return n1.localizedCaseInsensitiveCompare(n2) == .orderedAscending
                        case (.some, nil):
                            return true
                        case (nil, .some):
                            return false
                        case (nil, nil):
                            return id1.localizedCaseInsensitiveCompare(id2) == .orderedAscending
                        }
                    }, id: \.self) { bundleIdentifier in
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
                           let appBundle = Bundle(url: appURL),
                           let appName = appBundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? appBundle.localizedInfoDictionary?["CFBundleName"] as? String ?? appBundle.infoDictionary?["CFBundleName"] as? String {
                            
                            let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                            
                            HStack {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                Text(appName)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    removeAppFromExclusionList(bundleIdentifier: bundleIdentifier)
                                    selectedExcludedAppId = nil
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                            .tag(bundleIdentifier)
                        } else {
                            Text(bundleIdentifier)
                                .foregroundStyle(.secondary)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        removeAppFromExclusionList(bundleIdentifier: bundleIdentifier)
                                        selectedExcludedAppId = nil
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                                .tag(bundleIdentifier)
                        }
                    }
                    .onDelete { indexSet in
                        let idsToDelete = indexSet.map { excludedAppIdentifiers[$0] }
                        for id in idsToDelete {
                            removeAppFromExclusionList(bundleIdentifier: id)
                        }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    let group = DispatchGroup()
                    var invalidItemsCount = 0
                    let lock = NSLock()
                    
                    for provider in providers {
                        group.enter()
                        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                            defer { group.leave() }
                            
                            guard let urlData = urlData as? Data,
                                  let url = URL(dataRepresentation: urlData, relativeTo: nil) else {
                                lock.lock()
                                invalidItemsCount += 1
                                lock.unlock()
                                return
                            }
                            
                            if url.pathExtension == "app" || FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path) {
                                guard let bundle = Bundle(url: url),
                                      let bundleIdentifier = bundle.bundleIdentifier else {
                                    lock.lock()
                                    invalidItemsCount += 1
                                    lock.unlock()
                                    return
                                }
                                
                                DispatchQueue.main.async {
                                    if !excludedAppIdentifiers.contains(bundleIdentifier) {
                                        excludedAppIdentifiers.append(bundleIdentifier)
                                        print("Excluded app added via drag and drop: \(bundleIdentifier)")
                                    } else {
                                        print("App already in exclusion list: \(bundleIdentifier)")
                                    }
                                }
                            } else {
                                lock.lock()
                                invalidItemsCount += 1
                                lock.unlock()
                            }
                        }
                    }
                    
                    group.notify(queue: .main) {
                        if invalidItemsCount > 0 {
                            showingInvalidAppAlert = true
                            print("Dropped items include \(invalidItemsCount) non-application item(s).")
                        }
                    }
                    
                    return true
                }
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(.bottom, 24)
                .accessibilityLabel("除外するアプリリスト")
                .alert("アプリではありません", isPresented: $showingInvalidAppAlert) {
                    Button("OK") { }
                } message: {
                    Text("除外するアプリにはアプリのみ追加することができます。")
                }
                .overlay(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                        HStack(spacing: 0) {
                            Button(action: {
                                isShowingAddAppPopover = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(x: 2.0, y: -1.0)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .help("除外するアプリを追加します。")
                            .popover(isPresented: $isShowingAddAppPopover, arrowEdge: .leading) {
                                ExcludeAppPickerPopover(
                                    showAllRunningApps: $showAllRunningApps,
                                    runningApplications: runningApplications,
                                    existingBundleIdentifiers: Set(excludedAppIdentifiers),
                                    onSelectRunningApplication: { identifier in
                                        addAppToExclusionList(bundleIdentifier: identifier)
                                        isShowingAddAppPopover = false
                                    },
                                    onSelectFromFinder: {
                                        showingFinderPanel = true
                                        isShowingAddAppPopover = false
                                    }
                                )
                            }
                            
                            Divider()
                                .frame(width: 1, height: 16)
                                .background(Color.gray.opacity(0.1))
                                .padding(.horizontal, 4)
                            
                            Button(action: {
                                print("Remove App button tapped. Selected: \(selectedExcludedAppId ?? "None")")
                                if let selectedId = selectedExcludedAppId {
                                    removeAppFromExclusionList(bundleIdentifier: selectedId)
                                    selectedExcludedAppId = nil
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(y: -0.5)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedExcludedAppId == nil)
                            .help("選択したアプリをリストから削除します。")
                            
                            Spacer()
                            Button(action: {
                                showingClearAllExcludedAppsConfirmation = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(x: -2.0, y: -2.0)
                                    .contentShape(Rectangle())
                                    .if(!excludedAppIdentifiers.isEmpty) { view in
                                        view.foregroundStyle(.red)
                                    }
                            }
                            .buttonStyle(.borderless)
                            .disabled(excludedAppIdentifiers.isEmpty)
                            .help("すべての除外するアプリをリストから削除します。")
                        }
                        .background(Rectangle().opacity(0.04))
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("除外するアプリ")
                        .font(.headline)
                    
                    Text("ここに追加したアプリが最前面にあるときはコピー履歴に追加されません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 4)
            }
            .alert("すべての除外するアプリを削除", isPresented: $showingClearAllExcludedAppsConfirmation) {
                Button("削除", role: .destructive) {
                    clipboardManager.updateExcludedAppIdentifiers([])
                    excludedAppIdentifiers = []
                    selectedExcludedAppId = nil
                }
                Button("キャンセル", role: .cancel) {
                    // 何もしない
                }
            } message: {
                Text("除外するアプリのリストを空にしてもよろしいですか？この操作は元に戻せません。")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            accessibilityChecker.checkPermission()
            updateNotificationAuthorizationStatus()
            if let decoded = try? JSONDecoder().decode([String].self, from: excludedAppIdentifiersData) {
                self.excludedAppIdentifiers = decoded
            }
            runningApplications = NSWorkspace.shared.runningApplications
            clipboardManager.updateExcludedAppIdentifiers(excludedAppIdentifiers)
            
            // アプリ起動時（onAppear）にClipboardManagerの初期状態をUserDefaultsと同期する
            let isPaused = UserDefaults.standard.bool(forKey: "isClipboardMonitoringPaused")
            if isPaused {
                clipboardManager.stopMonitoringPasteboard()
            } else {
                clipboardManager.startMonitoringPasteboard()
            }
            
            // 定期的に権限の状態を更新するためのタイマーを開始
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                accessibilityChecker.checkPermission()
                updateNotificationAuthorizationStatus()
            }
        }
        .onDisappear {
            // ビューが非表示になったときにタイマーを無効化
            timer?.invalidate()
            timer = nil
        }
        .background(
            AppSelectionImporterView(
                isPresented: $showingFinderPanel,
                onAppSelected: { bundleIdentifier in
                    addAppToExclusionList(bundleIdentifier: bundleIdentifier)
                },
                onSelectionCancelled: {
                    print("DEBUG: App selection cancelled.")
                }
            )
            .frame(width: 0, height: 0)
            .clipped()
        )
    }
}

private struct ExcludeAppPickerPopover: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var showAllRunningApps: Bool

    let runningApplications: [NSRunningApplication]
    let existingBundleIdentifiers: Set<String>
    let onSelectRunningApplication: (String) -> Void
    let onSelectFromFinder: () -> Void

    @State private var currentRunningApplications: [NSRunningApplication] = []
    @State private var filteredRunningApplications: [NSRunningApplication] = []
    @State private var isLoading = false
    @State private var filterTask: Task<Void, Never>? = nil

    private func displayName(for app: NSRunningApplication) -> String {
        if let localizedName = app.localizedName, !localizedName.isEmpty {
            return localizedName
        }

        if let executableURL = app.executableURL {
            return executableURL.deletingPathExtension().lastPathComponent
        }

        return app.bundleIdentifier ?? "不明なアプリ"
    }

    private func updateFilteredApps() {
        filterTask?.cancel()
        isLoading = true

        filterTask = Task {
            let allApps = currentRunningApplications
            let showAll = showAllRunningApps
            let existingIds = existingBundleIdentifiers

            let filtered = await Task.detached(priority: .userInitiated) {
                let apps = allApps.filter { app in
                    guard !app.isTerminated else { return false }

                    let hasAppIdentity = app.bundleIdentifier != nil || app.localizedName != nil || app.executableURL != nil
                    guard hasAppIdentity else { return false }

                    let isRegularApp = app.activationPolicy == .regular

                    if !showAll {
                        return isRegularApp
                    }

                    return true
                }

                return apps
                    .filter { app in
                        if let bundleIdentifier = app.bundleIdentifier {
                            return !existingIds.contains(bundleIdentifier)
                        } else if let executablePath = app.executableURL?.path {
                            return !existingIds.contains(executablePath)
                        }
                        return true
                    }
                    .sorted { app1, app2 in
                        let name1 = app1.localizedName ?? app1.bundleIdentifier ?? ""
                        let name2 = app2.localizedName ?? app2.bundleIdentifier ?? ""
                        return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
                    }
            }.value

            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.filteredRunningApplications = filtered
                    self.isLoading = false
                }
            }
        }
    }

    private func refreshRunningApplications() {
        currentRunningApplications = NSWorkspace.shared.runningApplications
        #if DEBUG
        print("ExcludeAppPickerPopover refreshed running applications: \(currentRunningApplications.count)")
        #endif
        updateFilteredApps()
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            Text("実行中のアプリから追加")
                .font(.headline)
            Spacer()
            Toggle(isOn: $showAllRunningApps) {
                Text("すべてのプロセスを表示")
            }
            .toggleStyle(.checkbox)
            .font(.subheadline)
        }
        .padding()
    }

    private var finderButton: some View {
        Button {
            onSelectFromFinder()
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                Text("Finderで選択...")
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding()
    }

    private var applicationsScrollView: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // スクロール位置の基準点
                        Color.clear
                            .frame(height: 0)
                            .id("top")

                        VStack(alignment: .leading, spacing: 16) {
                            if filteredRunningApplications.isEmpty {
                                Text("追加できる実行中のアプリが見つかりません。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(filteredRunningApplications, id: \.processIdentifier) { app in
                                    Button {
                                        if let bundleIdentifier = app.bundleIdentifier {
                                            onSelectRunningApplication(bundleIdentifier)
                                        } else if let executablePath = app.executableURL?.path {
                                            onSelectRunningApplication(executablePath)
                                        }
                                    } label: {
                                        HStack {
                                            Image(nsImage: app.icon ?? NSImage())
                                                .resizable()
                                                .frame(width: 16, height: 16)
                                            
                                            let name = displayName(for: app)
                                            let isGenericName = name.lowercased() == "java"
                                            
                                            VStack(alignment: .leading, spacing: 0) {
                                                Text(name)
                                                    .lineLimit(2)
                                                if isGenericName, let path = app.executableURL?.path {
                                                    Text(path)
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                        .truncationMode(.middle)
                                                }
                                            }
                                            
                                            Spacer()
                                            Text(String(describing: app.processIdentifier))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .help(app.bundleIdentifier != nil ? 
                                          String(localized: "PID: \(String(app.processIdentifier)), \(displayName(for: app))", comment: "アプリ追加リストのツールチップ（バンドルIDあり）") : 
                                          String(localized: "PID: \(String(app.processIdentifier)), \(displayName(for: app)) (\(app.executableURL?.path ?? ""))", comment: "アプリ追加リストのツールチップ（バンドルIDなし・パス表示）"))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .opacity(isLoading ? 0 : 1)
                }

                .adaptiveScrollEdgeEffect()
                .onChange(of: showAllRunningApps) { _, _ in
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var contentView: some View {
        if #available(macOS 26.0, *) {
            applicationsScrollView
                .safeAreaBar(edge: .top, spacing: 0) {
                    headerBar
                }
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    finderButton
                }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                headerBar
                applicationsScrollView
                finderButton
            }
        }
    }

    var body: some View {
        contentView
        .frame(minWidth: 280, maxWidth: 400, minHeight: 320)
        .onAppear {
            currentRunningApplications = runningApplications
            refreshRunningApplications()
        }
        .onDisappear {
            filterTask?.cancel()
            filterTask = nil
            currentRunningApplications = []
            filteredRunningApplications = []
        }
        .onChange(of: showAllRunningApps) { _, _ in
            updateFilteredApps()
        }
        .onChange(of: colorScheme) { _, _ in
            refreshRunningApplications()
        }
    }
}

#Preview {
    PrivacySettingsView()
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(ClipboardManager.shared)
}

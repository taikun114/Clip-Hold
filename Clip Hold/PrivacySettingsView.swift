import SwiftUI
import AppKit
import UniformTypeIdentifiers
import UserNotifications

struct PrivacySettingsView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager

    @ObservedObject private var accessibilityChecker = AccessibilityPermissionChecker.shared
    @StateObject private var clipboardImporterExporter = ClipboardHistoryImporterExporter()

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
            print("PrivacySettingsView didSet: クリップボード監視状態が \(isClipboardMonitoringPaused ? "一時停止" : "再開") に変更されました。")
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

    @State private var showingClearHistoryConfirmation = false
    @State private var isShowingExportSheet: Bool = false
    @State private var isShowingImportSheet: Bool = false
    
    @State private var selectedExcludedAppId: String? = nil
    @State private var runningApplications: [NSRunningApplication] = []
    @State private var showingFinderPanel = false

    @State private var isShowingAddAppPopover: Bool = false
    @State private var showAllRunningApps: Bool = false

    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    @State private var showingClearAllExcludedAppsConfirmation = false

    // MARK: - Helper Functions
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
            guard let appPath = app.bundleURL?.path else { return false }
            
            let userApplicationsPath = FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first?.path ?? ""
            let localApplicationsPath = "/Applications"
            let isUserApp = appPath.hasPrefix(userApplicationsPath) || appPath.hasPrefix(localApplicationsPath)

            if !showAllRunningApps {
                return isUserApp
            }
            
            return true
        }
        
        // excludedAppIdentifiers に含まれるアプリを除外
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
                    Circle()
                        .fill(isClipboardMonitoringPaused ? Color.gray : Color.green)
                        .frame(width: 10, height: 10)
                    
                    VStack(alignment: .leading) {
                        Text("クリップボード監視")
                        Text(isClipboardMonitoringPaused ? "一時停止中" : "動作中")
                            .font(.caption)
                            .foregroundColor(.secondary)
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

                HStack {
                    VStack(alignment: .leading) {
                        Text("クリップボード履歴")
                        Text("現在、インポートとエクスポートはテキストのみサポートしています。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        print("DEBUG: Import button tapped. isShowingImportSheet will be true.")
                        self.isShowingImportSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("インポート")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("書き出したクリップボード履歴のJSONファイルを読み込みます。")

                    Button(action: {
                        self.isShowingExportSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("エクスポート")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(clipboardManager.clipboardHistory.isEmpty)
                    .help("すべてのクリップボード履歴をJSONファイルとして書き出します。")
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    Text("\(clipboardManager.clipboardHistory.count)個の履歴")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        showingClearHistoryConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("すべての履歴を削除")
                        }
                        .if(!clipboardManager.clipboardHistory.isEmpty) { view in
                            view.foregroundStyle(.red)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(clipboardManager.clipboardHistory.isEmpty)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }

            Section(header:
                VStack(alignment: .leading, spacing: 4) {
                    Text("権限")
                        .font(.headline)
                    Text("一部の機能には、システムの許可が必要です。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            ) {
                HStack {
                    Circle()
                        .fill(notificationAuthorizationStatus == .authorized ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    
                    VStack(alignment: .leading) {
                        Text("通知")
                        Text("通知機能を使用する場合は許可を与える必要があります。")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                .onAppear(perform: updateNotificationAuthorizationStatus)
                .onChange(of: notificationAuthorizationStatus) { oldValue, newValue in
                    print("通知許可状態が変更されました: \(newValue.rawValue)")
                }
                HStack {
                    Circle()
                        .fill(accessibilityChecker.hasAccessibilityPermission ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    
                    VStack(alignment: .leading) {
                        Text("アクセシビリティ")
                        Text("クイックペースト機能を使用する場合は許可を与える必要があります。")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                                Button("削除", role: .destructive) {
                                    removeAppFromExclusionList(bundleIdentifier: bundleIdentifier)
                                    selectedExcludedAppId = nil
                                }
                            }
                            .tag(bundleIdentifier)
                        } else {
                            Text(bundleIdentifier)
                                .foregroundColor(.secondary)
                                .contextMenu {
                                    Button("削除", role: .destructive) {
                                        removeAppFromExclusionList(bundleIdentifier: bundleIdentifier)
                                        selectedExcludedAppId = nil
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
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(.bottom, 24)
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
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("実行中のアプリから追加")
                                            .font(.headline)
                                        Spacer()
                                        Toggle(isOn: $showAllRunningApps) {
                                            Text("すべてのアプリを表示")
                                        }
                                        .toggleStyle(.checkbox)
                                        .font(.subheadline)
                                    }
                                    .padding(.bottom, 4)

                                    ScrollView {
                                        VStack(alignment: .leading) {
                                            ForEach(filterRunningApplications(applications: runningApplications).sorted(by: { ($0.localizedName ?? "") < ($1.localizedName ?? "") }), id: \.self) { app in
                                                Button(action: {
                                                    if let bundleIdentifier = app.bundleIdentifier {
                                                        addAppToExclusionList(bundleIdentifier: bundleIdentifier)
                                                        isShowingAddAppPopover = false
                                                    }
                                                }) {
                                                    HStack {
                                                        Image(nsImage: app.icon ?? NSImage())
                                                            .resizable()
                                                            .frame(width: 16, height: 16)
                                                        Text(app.localizedName ?? "不明なアプリ")
                                                        Spacer()
                                                        Text(String(describing: app.processIdentifier))
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    .contentShape(Rectangle())
                                                }
                                                .buttonStyle(.plain)
                                                .help("PID: \(String(describing: app.processIdentifier))")
                                                .padding(.vertical, 4)
                                            }
                                        }
                                        .padding(4)
                                    }
                                    .frame(maxHeight: 200)
                                    
                                    Divider()
                                        .padding(.vertical, 4)

                                    Button(action: {
                                        showingFinderPanel = true
                                        isShowingAddAppPopover = false
                                    }) {
                                        HStack {
                                            Image(systemName: "folder.fill")
                                            Text("Finderで選択...")
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 4)
                                }
                                .padding()
                                .frame(minWidth: 280, maxWidth: 400)
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
                                    .offset(y: -2.0)
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
                    
                    Text("ここに追加したアプリはクリップボード監視の対象外となります。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
        }
        .fileExporter(
            isPresented: $isShowingExportSheet,
            document: ClipboardHistoryDocument(clipboardItems: clipboardManager.clipboardHistory),
            contentType: .json,
            defaultFilename: "Clip Hold Clipboard History \(Date().formattedLocalExportFilename()).json"
        ) { result in
                clipboardImporterExporter.handleExportResult(result)
        }
        .fileImporter(
            isPresented: $isShowingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            print("DEBUG: fileImporter closure called for history import.")
            clipboardImporterExporter.handleImportResult(result, into: clipboardManager)
            self.isShowingImportSheet = false
        }
        .alert(item: $clipboardImporterExporter.currentAlert) { alertContent in
            Alert(
                title: alertContent.title,
                message: alertContent.message,
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("すべてのクリップボード履歴を削除", isPresented: $showingClearHistoryConfirmation) {
            Button("削除", role: .destructive) {
                clipboardManager.clearAllHistory()
            }
            Button("キャンセル", role: .cancel) {
                // 何もしない
            }
        } message: {
            Text("すべてのクリップボード履歴を本当に削除しますか？この操作は元に戻せません。")
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

extension Date {
    func formattedLocalExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        formatter.locale = Locale.current
        formatter.timeZone = .current
        return formatter.string(from: self)
    }
}

#Preview {
    PrivacySettingsView()
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(ClipboardManager.shared)
}

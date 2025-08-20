import SwiftUI
import AppKit
import Foundation
import Darwin.sys.sysctl

struct InfoSettingsView: View {
    // 現在のカラースキームを監視
    @Environment(\.colorScheme) var colorScheme

    // アラート表示を制御するState変数
    @State private var showingFeedbackMailAlert = false
    @State private var showingContributorsAlert = false
    @State private var showingBugReportAlert = false
    @State private var showingCommunityAlert = false
    @State private var showingGitHubStarAlert = false
    @State private var showingBuyMeACoffeeAlert = false
    @State private var showingPayPalAlert = false
    
    // ライセンス情報モーダル表示を制御するState変数
    @State private var showingLicenseInfoModal = false


    var body: some View {
        Form { // 全体をFormで囲む
            Section(header: Text("Clip Holdについて").font(.headline)) {
                HStack(alignment: .top, spacing: 20) {
                    if #available(macOS 26, *) {
                        // macOS 26以降の場合、"AppIconLiquidGlass"を使用
                        Image(nsImage: NSImage(named: NSImage.Name("AppIconLiquidGlass")) ?? NSImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 96, height: 96)
                            .padding(.vertical, 10)
                            .padding(.leading, 10)
                            .id(colorScheme)
                    } else {
                        // macOS 15以前の場合、既存の"AppIcon"を使用
                        Image(nsImage: NSImage(named: NSImage.Name("AppIcon")) ?? NSImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 128, height: 128)
                            .padding(.vertical, 0)
                            .padding(.leading, 0)
                            .padding(.trailing, -10)
                    }

                    VStack(alignment: .leading) {
                        Spacer()

                        VStack(alignment: .leading) {
                            Text("Clip Hold")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text("バージョン: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("生成AIと開発")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Copyright ©︎ 2025 今浦大雅")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .frame(maxHeight: 128, alignment: .topLeading)
                }
                
                // ライセンス情報セクション
                HStack(alignment: .center) {
                    Text("Clip Holdはオープンソースアプリケーションです。")
                    Spacer()
                    Button(action: {
                        showingLicenseInfoModal = true
                    }) {
                        HStack {
                            Image(systemName: "doc")
                            Text("ライセンス情報")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("このアプリケーションと使用されているライブラリのライセンス情報を表示します。")
                    .sheet(isPresented: $showingLicenseInfoModal) {
                        LicenseInfoModalView()
                    }
                }

                // 開発に携わった貢献者セクション
                HStack(alignment: .center) {
                    Text("開発に携わった貢献者")
                    Spacer()
                    Button(action: {
                        showingContributorsAlert = true
                    }) {
                        HStack {
                            Image(systemName: "person.2")
                            Text("貢献者")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("GitHubの貢献者ページへのリンクを開きます。")
                    .alert("リンクを開きますか？", isPresented: $showingContributorsAlert) {
                        Button("開く") {
                            if let url = URL(string: "https://github.com/taikun114/Clip-Hold/graphs/contributors"),
                                NSWorkspace.shared.open(url) {
                                // URLを開く処理が成功した場合（何もしない）
                            } else {
                                print("Failed to open URL.")
                            }
                        }
                        Button("キャンセル", role: .cancel) {
                            // アラートを閉じるだけ
                        }
                    } message: {
                        Text("GitHubの貢献者ページを開いてもよろしいですか？")
                    }
                }
            }

            Section(header: Text("サポートとフィードバック").font(.headline)) {
                HStack(alignment: .center) {
                    Text("バグを見つけましたか？")
                    Spacer()
                    Button(action: {
                        showingBugReportAlert = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                            Text("バグを報告")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("既知のバグ一覧と報告ページへのリンクを開きます。")
                    .alert("リンクを開きますか？", isPresented: $showingBugReportAlert) {
                        Button("開く") {
                            if let url = URL(string: "https://github.com/taikun114/Clip-Hold/issues"),
                                NSWorkspace.shared.open(url) {
                                // URLを開く処理が成功した場合（何もしない）
                            } else {
                                print("Failed to open URL.")
                            }
                        }
                        Button("キャンセル", role: .cancel) {
                            // アラートを閉じるだけ
                        }
                    } message: {
                        Text("GitHubのIssueページを開いてもよろしいですか？")
                    }
                }

                HStack(alignment: .center) {
                    Text("アイデアがありますか？")
                    Spacer()
                    Button(action: {
                        showingFeedbackMailAlert = true
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("フィードバックを送信")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("フィードバックのメール送信画面を開きます。")
                }

                HStack(alignment: .center) {
                    Text("質問や意見交換などを行いましょう")
                    Spacer()
                    Button(action: {
                        showingCommunityAlert = true
                    }) {
                        HStack {
                            Image(systemName: "ellipsis.bubble")
                            Text("コミュニティ")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("ディスカッションページへのリンクを開きます.")
                    .alert("リンクを開きますか？", isPresented: $showingCommunityAlert) {
                        Button("開く") {
                            if let url = URL(string: "https://github.com/taikun114/Clip-Hold/discussions"),
                                NSWorkspace.shared.open(url) {
                                // URLを開く処理が成功した場合（何もしない）
                            } else {
                                print("Failed to open URL.")
                            }
                        }
                        Button("キャンセル", role: .cancel) {
                            // アラートを閉じるだけ
                        }
                    } message: {
                        Text("GitHubのDiscussionページを開いてもよろしいですか？")
                    }
                }
            }

            Section(header: Text("開発者をサポート").font(.headline)) {
                // GitHubリポジトリにスターをつける
                HStack(alignment: .center) {
                    VStack(alignment: .leading) {
                        Text("GitHubリポジトリにスターをつける")
                            .font(.body)
                        Text("リポジトリにスターをつけてくれるととてもうれしいです！")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        showingGitHubStarAlert = true
                    }) {
                        HStack {
                            Image(systemName: "star")
                            Text("スターをつける")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("GitHubリポジトリページへのリンクを開きます。")
                    .alert("リンクを開きますか？", isPresented: $showingGitHubStarAlert) {
                        Button("開く") {
                            if let url = URL(string: "https://github.com/taikun114/Clip-Hold"),
                                NSWorkspace.shared.open(url) {
                                // URLを開く処理が成功した場合（何もしない）
                            } else {
                                print("Failed to open URL.")
                            }
                        }
                        Button("キャンセル", role: .cancel) {
                            // アラートを閉じるだけ
                        }
                    } message: {
                        Text("GitHubのリポジトリページを開いてもよろしいですか？")
                    }
                }

                // 緑茶を買ってあげる
                HStack(alignment: .center) {
                    VStack(alignment: .leading) {
                        Text("緑茶を買ってあげる")
                            .font(.body)
                        Text("Buy Me a Coffeeで、緑茶一杯分の金額からサポートしていただけます。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        showingBuyMeACoffeeAlert = true
                    }) {
                        HStack {
                            Image(systemName: "cup.and.saucer")
                            Text("緑茶を奢る")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("Buy Me a Coffeeページへのリンクを開きます。")
                    .alert("リンクを開きますか？", isPresented: $showingBuyMeACoffeeAlert) {
                        Button("開く") {
                            if let url = URL(string: "https://www.buymeacoffee.com/i_am_taikun"),
                                NSWorkspace.shared.open(url) {
                                // URLを開く処理が成功した場合（何もしない）
                            } else {
                                print("Failed to open URL.")
                            }
                        }
                        Button("キャンセル", role: .cancel) {
                            // アラートを閉じるだけ
                        }
                    } message: {
                        Text("Buy Me a Coffeeのページを開いてもよろしいですか？")
                    }
                }

                // PayPalで寄付の項目
                HStack(alignment: .center) {
                    VStack(alignment: .leading) {
                        Text("PayPalで寄付")
                            .font(.body)
                        Text("PayPalで直接寄付していただくこともできます。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        showingPayPalAlert = true
                    }) {
                        HStack {
                            Image(systemName: "creditcard")
                            Text("PayPalで寄付")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("PayPal.Meのリンクを開きます。")
                    .alert("リンクを開きますか？", isPresented: $showingPayPalAlert) {
                        Button("開く") {
                            if let url = URL(string: "https://paypal.me/taikun114"),
                                NSWorkspace.shared.open(url) {
                                // URLを開く処理が成功した場合（何もしない）
                            } else {
                                print("Failed to open URL.")
                            }
                        }
                        Button("キャンセル", role: .cancel) {
                            // アラートを閉じるだけ
                        }
                    } message: {
                        Text("PayPal.Meのページを開いてもよろしいですか？")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .alert("メール送信画面を開きますか？", isPresented: $showingFeedbackMailAlert) {
            Button("開く") {
                if let url = URL(string: "mailto:contact.taikun@gmail.com?subject=\(formattedFeedbackSubject())&body=\(formattedFeedbackBody())"),
                    NSWorkspace.shared.open(url) {
                    // URLを開く処理が成功した場合（何もしない）
                } else {
                    print("Failed to open mailto URL.")
                }
            }
            Button("キャンセル", role: .cancel) {
                // アラートを閉じるだけ
            }
        } message: {
            Text("フィードバックのメール送信画面を開いてもよろしいですか？")
        }
    }

    // メールの件名をURLエンコードして返すヘルパー関数
    private func formattedFeedbackSubject() -> String {
        let appName = "Clip Hold"
        let languageCode = Locale.current.language.languageCode?.identifier

        let subjectPrefix: String
        if languageCode == "ja" {
            subjectPrefix = "\(appName)のフィードバック: "
        } else {
            subjectPrefix = "\(appName) Feedback: "
        }

        return subjectPrefix.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }

    // 機種IDを取得するヘルパー関数
    private func getMachineModelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    // メールの本文をURLエンコードして返すヘルパー関数
    private func formattedFeedbackBody() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
        let appBuildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"

        // macOSのバージョン情報を取得
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        // CPUアーキテクチャの取得
        #if arch(arm64)
        let cpuArchitecture = "Apple Silicon (arm64)"
        #elseif arch(x86_64)
        let cpuArchitecture = "Intel (x86_64)"
        #else
        let cpuArchitecture = "N/A"
        #endif

        // 機種IDを取得
        let machineModelIdentifier = getMachineModelIdentifier()

        let languageCode = Locale.current.language.languageCode?.identifier
        let body: String

        if languageCode == "ja" {
            body = """
            フィードバック内容を具体的に説明してください:


            システム情報:

            ・システム
            　機種ID: \(machineModelIdentifier)
            　アーキテクチャ: \(cpuArchitecture)

            ・macOS
            　\(osVersion)

            ・アプリ
            　バージョン\(appVersion)（ビルド\(appBuildNumber)）
            """
        } else {
            body = """
            Please describe your feedback in detail:


            System Information:

            ・System
            　Model ID: \(machineModelIdentifier)
            　Architecture: \(cpuArchitecture)

            ・macOS
            　\(osVersion)

            ・App
            　Version \(appVersion) (Build \(appBuildNumber))
            """
        }

        return body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }
}

#Preview {
    InfoSettingsView()
}

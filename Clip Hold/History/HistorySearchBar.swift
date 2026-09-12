import SwiftUI

struct HistorySearchBar: View {
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Binding var searchText: String
    @Binding var isLoading: Bool
    @FocusState var isSearchFieldFocused: Bool
    var clipboardHistoryCount: Int
    
    @State private var searchTask: Task<Void, Never>? = nil
    
    @Binding var selectedFilter: ItemFilter
    @Binding var selectedSort: ItemSort
    @Binding var selectedApp: String?
    
    // カラーコードフィルタリング設定のバインディング
    @AppStorage("enableColorCodeFilter") var enableColorCodeFilter: Bool = false
    
    @ViewBuilder
    private var appPickerLabel: some View {
        if let selectedAppPath = selectedApp {
            if selectedAppPath == "auto_filter_mode" {
                Label("アプリ（自動）", systemImage: "app.badge.checkmark")
            } else if let appName = clipboardManager.appUsageHistory[selectedAppPath] {
                if FileManager.default.fileExists(atPath: selectedAppPath) {
                    Label {
                        Text(appName)
                    } icon: {
                        if let icon = clipboardManager.getResizedAppIcon(for: selectedAppPath) {
                            Image(nsImage: icon)
                        } else {
                            Image(systemName: "app")
                        }
                    }
                } else {
                    Label {
                        Text(appName)
                    } icon: {
                        Image(systemName: "questionmark.app")
                    }
                }
            } else {
                Label("アプリ", systemImage: "questionmark.app")
            }
        } else {
            Label("アプリ", systemImage: "app")
        }
    }
    
    var body: some View {
        HStack {
            SharedSearchField(
                placeholder: "履歴を検索",
                searchText: $searchText,
                isSearchFieldFocused: $isSearchFieldFocused
            )
            // フィルターボタン
            Menu {
                Picker("フィルター", selection: $selectedFilter) {
                    // 「すべての項目」を最初に表示
                    Label(ItemFilter.all.displayName, systemImage: "list.clipboard").forceIconOnMacOS27().tag(ItemFilter.all)
                    
                    // テキストピッカーを「すべての項目」の下に配置
                    Picker(selection: $selectedFilter) {
                        Label(ItemFilter.textAll.displayName, systemImage: "textformat").forceIconOnMacOS27().tag(ItemFilter.textAll)
                        Divider()
                        if #available(macOS 15.0, *) {
                            Label(ItemFilter.textPlain.displayName, systemImage: "text.page").forceIconOnMacOS27().tag(ItemFilter.textPlain)
                        } else {
                            Label(ItemFilter.textPlain.displayName, systemImage: "doc.plaintext").forceIconOnMacOS27().tag(ItemFilter.textPlain)
                        }
                        if #available(macOS 15.0, *) {
                            Label(ItemFilter.textRich.displayName, systemImage: "richtext.page").forceIconOnMacOS27().tag(ItemFilter.textRich)
                        } else {
                            Label(ItemFilter.textRich.displayName, systemImage: "doc.richtext").forceIconOnMacOS27().tag(ItemFilter.textRich)
                        }
                        Label(ItemFilter.linkOnly.displayName, systemImage: "paperclip").forceIconOnMacOS27().tag(ItemFilter.linkOnly)
                    } label: {
                        Label("テキストのみ", systemImage: "textformat").forceIconOnMacOS27()
                    }
                    .pickerStyle(.menu)
                    
                    // コードピッカーを「テキストのみ」の下に配置
                    Picker(selection: $selectedFilter) {
                        Label(ItemFilter.codeAll.displayName, systemImage: "chevron.left.forwardslash.chevron.right").forceIconOnMacOS27().tag(ItemFilter.codeAll)
                        Divider()
                        Label(ItemFilter.codeSwift.displayName, systemImage: "swift").forceIconOnMacOS27().tag(ItemFilter.codeSwift)
                        Label(ItemFilter.codeJavaScript.displayName, systemImage: "curlybraces").forceIconOnMacOS27().tag(ItemFilter.codeJavaScript)
                        Label(ItemFilter.codePython.displayName, systemImage: "chevron.left.forwardslash.chevron.right").forceIconOnMacOS27().tag(ItemFilter.codePython)
                        Label(ItemFilter.codeHTML.displayName, systemImage: "chevron.left.forwardslash.chevron.right").forceIconOnMacOS27().tag(ItemFilter.codeHTML)
                        Label(ItemFilter.codeCSS.displayName, systemImage: "paintbrush").forceIconOnMacOS27().tag(ItemFilter.codeCSS)
                        Label(ItemFilter.codeJSON.displayName, systemImage: "curlybraces.square").forceIconOnMacOS27().tag(ItemFilter.codeJSON)
                        Label(ItemFilter.codeYAML.displayName, systemImage: "doc.text").forceIconOnMacOS27().tag(ItemFilter.codeYAML)
                        Label(ItemFilter.codeTOML.displayName, systemImage: "doc.plaintext").forceIconOnMacOS27().tag(ItemFilter.codeTOML)
                        Label(ItemFilter.codeMarkdown.displayName, systemImage: "text.alignleft").forceIconOnMacOS27().tag(ItemFilter.codeMarkdown)
                        Label(ItemFilter.codeGraphQL.displayName, systemImage: "circle.grid.cross").forceIconOnMacOS27().tag(ItemFilter.codeGraphQL)
                        Label(ItemFilter.codeEnv.displayName, systemImage: "slider.horizontal.3").forceIconOnMacOS27().tag(ItemFilter.codeEnv)
                        Label(ItemFilter.codeRust.displayName, systemImage: "gearshape").forceIconOnMacOS27().tag(ItemFilter.codeRust)
                        Label(ItemFilter.codeGo.displayName, systemImage: "shippingbox").forceIconOnMacOS27().tag(ItemFilter.codeGo)
                        Label(ItemFilter.codeCPP.displayName, systemImage: "chevron.left.forwardslash.chevron.right").forceIconOnMacOS27().tag(ItemFilter.codeCPP)
                        Label(ItemFilter.codeJavaKotlin.displayName, systemImage: "cup.and.saucer").forceIconOnMacOS27().tag(ItemFilter.codeJavaKotlin)
                        Label(ItemFilter.codeSQL.displayName, systemImage: "cylinder").forceIconOnMacOS27().tag(ItemFilter.codeSQL)
                        Label(ItemFilter.codeShell.displayName, systemImage: "terminal").forceIconOnMacOS27().tag(ItemFilter.codeShell)
                        Label(ItemFilter.codeOther.displayName, systemImage: "ellipsis.curlybraces").forceIconOnMacOS27().tag(ItemFilter.codeOther)
                    } label: {
                        Label("コードのみ", systemImage: "chevron.left.forwardslash.chevron.right").forceIconOnMacOS27()
                    }
                    .pickerStyle(.menu)
                    
                    // ファイルピッカーを「コードのみ」の下に配置
                    Picker(selection: $selectedFilter) {
                        // 「すべてのファイル」を最初に表示
                        if #available(macOS 15.0, *) {
                            Label("すべてのファイル", systemImage: "document").forceIconOnMacOS27().tag(ItemFilter.fileOnly)
                        } else {
                            Label("すべてのファイル", systemImage: "doc").forceIconOnMacOS27().tag(ItemFilter.fileOnly)
                        }
                        Divider()
                        Label(ItemFilter.imageOnly.displayName, systemImage: "photo").forceIconOnMacOS27().tag(ItemFilter.imageOnly)
                        Label(ItemFilter.videoOnly.displayName, systemImage: "movieclapper").forceIconOnMacOS27().tag(ItemFilter.videoOnly)
                        Label(ItemFilter.pdfOnly.displayName, systemImage: "text.document").forceIconOnMacOS27().tag(ItemFilter.pdfOnly)
                        Label(ItemFilter.folderOnly.displayName, systemImage: "folder").forceIconOnMacOS27().tag(ItemFilter.folderOnly)
                        Label(ItemFilter.otherFiles.displayName, systemImage: "document.badge.ellipsis").forceIconOnMacOS27().tag(ItemFilter.otherFiles)
                    } label: {
                        if #available(macOS 15.0, *) {
                            Label("ファイルのみ", systemImage: "document").forceIconOnMacOS27()
                        } else {
                            Label("ファイルのみ", systemImage: "doc").forceIconOnMacOS27()
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // カラーコードフィルターをファイルピッカーの下に配置
                    if enableColorCodeFilter {
                        Label(ItemFilter.colorCodeOnly.displayName, systemImage: "paintpalette").forceIconOnMacOS27().tag(ItemFilter.colorCodeOnly)
                    }
                    
                    if !clipboardManager.appUsageHistory.isEmpty {
                        Divider()
                        Picker(selection: $selectedApp) {
                            Label("すべてのアプリ", systemImage: "app").tag(nil as String?)
                            Label("自動", systemImage: "app.badge.checkmark").tag("auto_filter_mode" as String?)
                            Divider()
                            ForEach(clipboardManager.appUsageHistory.sorted(by: { $0.value < $1.value }), id: \.key) { path, localizedName in
                                Label {
                                    Text(localizedName)
                                } icon: {
                                    if FileManager.default.fileExists(atPath: path) {
                                        if let icon = clipboardManager.getResizedAppIcon(for: path) {
                                            Image(nsImage: icon)
                                        } else {
                                            Image(systemName: "app")
                                        }
                                    } else {
                                        Image(systemName: "questionmark.app")
                                    }
                                }
                                .tag(path as String?)
                            }
                        } label: {
                            appPickerLabel
                        }
                        .labelStyle(.titleAndIcon)
                        .pickerStyle(.menu)
                    }
                }
                .pickerStyle(.inline)
                
                if selectedFilter != .all || selectedApp != nil {
                    Divider()
                    Button {
                        selectedFilter = .all
                        selectedApp = nil
                    } label: {
                        Label("すべてのフィルターを解除", systemImage: "xmark.circle")
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .tint(selectedFilter != .all || selectedApp != nil ? .accentColor : .secondary)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
            .padding(.horizontal, 4)
            .disabled(isLoading) // 読み込み中に無効化
            
            // 並び替えボタン
            Menu {
                Picker("並び替え", selection: $selectedSort) {
                    ForEach(ItemSort.allCases, id: \.self) { sort in
                        switch sort {
                        case .newest:
                            Label(sort.displayName, systemImage: "clock").tag(sort)
                        case .oldest:
                            Text(sort.displayName).tag(sort)
                        case .largestFileSize:
                            Divider()
                            Label(sort.displayName, systemImage: "folder").tag(sort)
                        case .smallestFileSize:
                            Text(sort.displayName).tag(sort)
                        }
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                // 並び替えがデフォルト以外の場合はアクセントカラーを適用
                    .tint(selectedSort != .newest ? .accentColor : .secondary)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
            .padding(.horizontal, 4)
            .disabled(isLoading) // 読み込み中に無効化
            
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 5)
    }
}

#Preview {
    HistoryWindowView()
        .environmentObject(ClipboardManager.shared)
}

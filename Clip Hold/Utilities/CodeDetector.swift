import Foundation
import SwiftUI

/// 検出されたプログラミング言語・形式
public enum CodeLanguage: String, CaseIterable, Identifiable, Codable {
    case swift
    case javascript
    case python
    case html
    case css
    case json
    case yaml
    case toml
    case markdown
    case graphql
    case env
    case rust
    case go
    case cpp
    case javaKotlin
    case sql
    case shell
    case other
    
    public var id: String { rawValue }
    
    /// SwiftUI表示用のローカライズキー
    public var displayName: LocalizedStringKey {
        switch self {
        case .swift: return "Swift"
        case .javascript: return "JavaScript / TypeScript"
        case .python: return "Python"
        case .html: return "HTML / XML"
        case .css: return "CSS"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .toml: return "TOML"
        case .markdown: return "Markdown"
        case .graphql: return "GraphQL"
        case .env: return "環境変数 (.env)"
        case .rust: return "Rust"
        case .go: return "Go"
        case .cpp: return "C / C++"
        case .javaKotlin: return "Java / Kotlin"
        case .sql: return "SQL"
        case .shell: return "シェルスクリプト"
        case .other: return "その他のコード"
        }
    }
    
    /// 文字列結合等で使用するローカライズ済み文字列
    public var localizedName: String {
        switch self {
        case .swift: return String(localized: "Swift")
        case .javascript: return String(localized: "JavaScript / TypeScript")
        case .python: return String(localized: "Python")
        case .html: return String(localized: "HTML / XML")
        case .css: return String(localized: "CSS")
        case .json: return String(localized: "JSON")
        case .yaml: return String(localized: "YAML")
        case .toml: return String(localized: "TOML")
        case .markdown: return String(localized: "Markdown")
        case .graphql: return String(localized: "GraphQL")
        case .env: return String(localized: "環境変数 (.env)")
        case .rust: return String(localized: "Rust")
        case .go: return String(localized: "Go")
        case .cpp: return String(localized: "C / C++")
        case .javaKotlin: return String(localized: "Java / Kotlin")
        case .sql: return String(localized: "SQL")
        case .shell: return String(localized: "シェルスクリプト")
        case .other: return String(localized: "その他のコード")
        }
    }
    
    /// HighlighterSwift に渡す言語識別子
    public var highlighterLanguageName: String? {
        switch self {
        case .swift: return "swift"
        case .javascript: return "javascript"
        case .python: return "python"
        case .html: return "html"
        case .css: return "css"
        case .json: return "json"
        case .yaml: return "yaml"
        case .toml: return "ini"
        case .markdown: return "markdown"
        case .graphql: return "graphql"
        case .env: return "ini"
        case .rust: return "rust"
        case .go: return "go"
        case .cpp: return "cpp"
        case .javaKotlin: return "java"
        case .sql: return "sql"
        case .shell: return "bash"
        case .other: return nil
        }
    }
}

/// テキストがプログラミングコードや構造化データであるかを高速かつ安全に判定するユーティリティ
/// （破滅的バックトラッキングを防止するため、入れ子繰り返しや全文字貪欲マッチを完全に排除）
public struct CodeDetector {
    
    /// コード検出エンジンの現在のバージョン番号（検出ロジック更新時にインクリメント）
    public static let currentDetectorVersion: Int = 1
    
    // MARK: - 安全な正規表現パターン（バックトラッキング防止）
    
    /// HTML / XMLタグの判定パターン（HTMLコメント、タグ構造、改行を限定しバックトラッキングを防止）
    private static let htmlTagRegex = try? NSRegularExpression(
        pattern: #"(<!--.*?-->|^<[a-zA-Z][a-zA-Z0-9_-]*\b|<\/?(html|head|body|meta|link|title|style|base|div|span|p|a|ul|ol|li|table|tr|td|th|form|input|button|script|svg|path|code|pre|header|footer|nav|section|article|main|aside|h[1-6]|root|item|key|string|dict|array|configuration|property|settings|strong|em|b|i|br|hr|img|label|select|option|picture|source|video|audio|canvas|iframe|template|slot)\b[^>\n]*>|<!DOCTYPE\b[^>\n]*>|<\?xml\b[^>\n]*\?>|<[a-zA-Z][a-zA-Z0-9_-]*\b[^>\n]*\/>|<[a-zA-Z][a-zA-Z0-9_-]*(?:\s+[^>\n]*)?>[^<\n]*<\/[a-zA-Z][a-zA-Z0-9_-]*>)"#,
        options: [.caseInsensitive]
    )
    
    /// CSSプロパティ宣言の判定パターン（アットルール、波括弧内にCSSプロパティを含むブロック、またはプロパティ: 値;）
    private static let cssPropertyRegex = try? NSRegularExpression(
        pattern: #"(@(media|keyframes|font-face|import|supports|charset|layer)\b|\{\s*[a-zA-Z-]+\s*:\s*[^;{}\n]+\s*;|(?m)^\s*(?:\.[a-zA-Z0-9_-]+|#[a-zA-Z0-9_-]+|[a-zA-Z0-9_-]+)\s*\{[^}]*\b(margin|padding|display|color|background|font|border|flex|grid|position|width|height|opacity|z-index|box-shadow|overflow|align|justify|transform|transition|animation|content|cursor|pointer-events|visibility|white-space|word-break|text|line-height|gap|top|bottom|left|right|max-width|min-width|max-height|min-height|list-style|outline|filter|backdrop-filter|appearance|user-select|var\(--|light-dark\()[^;{}\n]*:|\b(margin|padding|display|color|background|font-size|border|flex|grid|position|width|height|border-radius|box-shadow|line-height|text-align|z-index|overflow|justify-content|align-items|--[a-zA-Z0-9_-]+)\s*:\s*[^;{}\n]+;)"#,
        options: []
    )
    
    /// JSONのキーバリューパターン（コロン前後のスペースを許容）
    private static let jsonKeyRegex = try? NSRegularExpression(
        pattern: #"\"(?:[^\"\\]|\\.)*\"\s*:\s*"#,
        options: []
    )
    
    /// YAMLドキュメント開始マーカー
    private static let yamlDocStartRegex = try? NSRegularExpression(
        pattern: #"(?m)^---\s*$"#,
        options: []
    )
    
    /// YAMLキーパターン（小文字/ハイフン/数字キー + コロン + 値またはインデント）
    private static let yamlKeyRegex = try? NSRegularExpression(
        pattern: #"(?m)^\s*[a-z0-9_-]+\s*:\s*(["'\d{\[]|true\b|false\b|>|\||\s*$)"#,
        options: []
    )
    
    /// YAMLリストパターン
    private static let yamlListRegex = try? NSRegularExpression(
        pattern: #"(?m)^\s*-\s+([a-z0-9_-]+:|\S+)"#,
        options: []
    )
    
    /// TOMLテーブルヘッダーパターン（[section] または [[section]]）
    private static let tomlTableRegex = try? NSRegularExpression(
        pattern: #"(?m)^\s*\[\[?[a-zA-Z0-9_.-]+\]?\]\s*$"#,
        options: []
    )
    
    /// TOMLキー代入パターン（key = value）
    private static let tomlKeyValueRegex = try? NSRegularExpression(
        pattern: #"(?m)^\s*[a-zA-Z0-9_-]+\s*=\s*(["'\d{\[]|true\b|false\b)"#,
        options: []
    )
    
    /// Markdown見出しパターン（# 見出し）
    private static let markdownHeadingRegex = try? NSRegularExpression(
        pattern: #"(?m)^#{1,6}\s+\S+"#,
        options: []
    )
    
    /// Markdownリストパターン（- item, * item, + item）
    private static let markdownListRegex = try? NSRegularExpression(
        pattern: #"(?m)^\s*[-*+]\s+\S+"#,
        options: []
    )
    
    /// Markdown番号付きリストパターン（1. item）
    private static let markdownNumberedListRegex = try? NSRegularExpression(
        pattern: #"(?m)^\s*\d+\.\s+\S+"#,
        options: []
    )
    
    /// Markdown太字パターン（**text**）
    private static let markdownBoldRegex = try? NSRegularExpression(
        pattern: #"\*\*[^\*\n]+\*\*"#,
        options: []
    )
    
    /// Markdownリンク・画像パターン（通常URL、相対パス、アンカー、タイトル付き、参照形式等）
    private static let markdownLinkRegex = try? NSRegularExpression(
        pattern: #"(!*\[[^\]\n]+\]\([^)\n]+\)|!*\[[^\]\n]+\]\[[^\]\n]*\])"#,
        options: []
    )
    
    /// Markdownテーブル行パターン（2列以上のテーブル行）
    private static let markdownTableRegex = try? NSRegularExpression(
        pattern: #"(?m)^\|(?:\s*[^|\n]+\s*\|){2,}\s*$"#,
        options: []
    )
    
    /// Markdown引用・コールアウトパターン（行頭 > ）
    private static let markdownBlockquoteRegex = try? NSRegularExpression(
        pattern: #"(?m)^\s*>\s+\S+"#,
        options: []
    )
    
    /// GraphQLキーワードパターン
    private static let graphqlRegex = try? NSRegularExpression(
        pattern: #"(?m)^\s*(query|mutation|subscription|fragment|schema|type|input|interface|enum)\s+[A-Za-z0-9_]*\s*[\({]"#,
        options: []
    )
    
    /// 環境変数 (.env) 行パターン（大文字スネークケースキー = 値）
    private static let envLineRegex = try? NSRegularExpression(
        pattern: #"(?m)^[A-Z][A-Z0-9_]{1,}\s*=\s*(["'].*?["']|\S.*|$)"#,
        options: []
    )
    
    /// Rust特有の構文パターン
    private static let rustSpecificRegex = try? NSRegularExpression(
        pattern: #"(\b(fn\s+[a-z_][a-z0-9_]*\s*\(|let\s+mut\s+|impl\s+[A-Za-z0-9_]+|match\s+[a-z_][a-z0-9_]*\s*\{|println!|eprintln!|vec!|Result<|Option<)|(?m)^\s*(pub\s+)?(use|mod|struct|enum|trait)\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\{)"#,
        options: []
    )
    
    /// Go特有の構文パターン（package宣言、レシーバー付きfunc、go func/defer/chan等）
    private static let goSpecificRegex = try? NSRegularExpression(
        pattern: #"((?m)^\s*package\s+[a-z0-9_]+\s*(?:\n|\r|//|/\*|$)|(?m)^\s*func\s*\([a-zA-Z0-9_* ]+\)\s*[A-Za-z0-9_]+|\bgo\s+func\s*\(|\bchan\s+[a-zA-Z0-9_]+|\bdefer\s+[a-zA-Z0-9_.]+\(|\b(fmt\.(Println|Printf|Sprintf|Errorf)|http\.(HandleFunc|ListenAndServe))\b)"#,
        options: []
    )
    
    /// C / C++特有の構文パターン
    private static let cppSpecificRegex = try? NSRegularExpression(
        pattern: #"((?m)^\s*#include\s*[<"][a-zA-Z0-9_./]+[>"]|\b(std::|nullptr|cout\s*<<|cin\s*>>|template\s*<|int\s+main\s*\()|\bnamespace\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\{)"#,
        options: []
    )
    
    /// Java / Kotlin特有の構文パターン
    private static let javaKotlinSpecificRegex = try? NSRegularExpression(
        pattern: #"((?m)^\s*package\s+[a-z0-9_.]+\s*;|\b(public\s+class\s+[A-Za-z0-9_]+|private\s+class\s+[A-Za-z0-9_]+|System\.(out|err)\.print|public\s+static\s+void\s+main|fun\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\(|val\s+[a-zA-Z_][a-zA-Z0-9_]*\s*:\s*[A-Z]|override\s+fun\s+|data\s+class\s+[A-Z]|suspend\s+fun\s+))"#,
        options: []
    )
    
    /// SQL文の判定パターン（行頭からのSQL文、または大文字キーワード）
    private static let sqlRegex = try? NSRegularExpression(
        pattern: #"(?m)^\s*(SELECT\s+[^;\n]+\s+FROM|INSERT\s+INTO\s+[^;\n]+|UPDATE\s+[^;\n]+\s+SET|DELETE\s+FROM\s+[^;\n]+|CREATE\s+TABLE|ALTER\s+TABLE|DROP\s+TABLE)\b"#,
        options: [.caseInsensitive]
    )
    
    /// Swift特有の構文パターン（変数宣言、型注釈、関数、SwiftUIプロパティラッパー、View、モディファイア、SPM等）
    private static let swiftSpecificRegex = try? NSRegularExpression(
        pattern: #"((#Preview|#available|#selector|#keyPath|#file|#line)\b|(?m)^\s*//\s*[a-zA-Z0-9_+-]+\.swift\b|\b@testable\s+import\b|(?:\b|\s|^)(\.package\s*\(url:|\.target\s*\(name:|\.testTarget\s*\(name:|\.executableTarget\s*\(name:|\.library\s*\(name:|\.plugin\s*\(name:|Package\s*\()|\b(guard\s+(let|var|[a-zA-Z_])|if\s+(let|var)|@State|@Binding|@Published|@ObservedObject|@StateObject|@EnvironmentObject|@Environment|@AppStorage|@MainActor|@FocusState|@ScaledMetric|@Namespace|extension\s+[A-Za-z0-9_]+|some\s+View|mutating\s+func|override\s+func|weak\s+var|lazy\s+var|private\s+(let|var)|fileprivate\s+(let|var)|public\s+(let|var)|didSet|willSet)\b|\b(let|var|static\s+let|static\s+var|private\s+let|private\s+var)\s+[a-zA-Z_][a-zA-Z0-9_]*\s*:\s*[A-Z\[][a-zA-Z0-9_<>?, :\[\]]*|\b(static\s+let|static\s+var|private\s+let|private\s+var)\s+[a-zA-Z_][a-zA-Z0-9_]*\s*=|\b(convenience\s+|required\s+|override\s+|public\s+|private\s+|fileprivate\s+)?init\s*[!?]?\s*(<[^>]+>)?\s*\([^)\n]*\)\s*(async\s+)?(throws\s+)?(\{|\bwhere\b)|\b(final\s+)?(class|struct|enum)\s+[A-Za-z0-9_]+\s*:\s*[A-Za-z0-9_,\s<>]+\s*\{|\[(weak|unowned)\s+self\]|(?m)^\s*import\s+(SwiftUI[A-Za-z0-9_]*|AppKit|UIKit|Foundation|Combine|Testing|SwiftData|PhotosUI|StoreKit|OSLog|UniformTypeIdentifiers|XCTest|CoreData|CoreGraphics|AVFoundation|WebKit|Security|Network|AuthenticationServices|KeyboardShortcuts|UniversalSFSymbolsPicker|[A-Z][a-zA-Z0-9_]+)\b|\bfunc\s+[A-Za-z0-9_]+\s*\([^)\n]*\)\s*(async\s+)?(throws\s+)?(->|\{)|\bstruct\s+[A-Za-z0-9_]+\s*:\s*(View|Identifiable|Codable|Equatable|Hashable|Sendable)\b|\b(DispatchQueue\.(main|global|concurrentPerform)|UserDefaults\.(standard|resetStandardUserDefaults)|ProcessInfo\.processInfo|UNNotificationAction\(|SMAppService\.(mainApp|loginItem|agent|daemon)|KeyboardShortcuts\.(onKeyDown|onKeyUp|reset|setShortcut|getShortcut|Name|Recorder|isPaused)|String\(localized:\s*")\b|\b(Text|Image|VStack|HStack|ZStack|LazyVStack|LazyHStack|LazyVGrid|LazyHGrid|Button|Toggle|Picker|TextField|SecureField|TextEditor|Slider|Stepper|ProgressView|Menu|Link|Label|List|ScrollView|Section|Group|ForEach|Form|TabView|NavigationStack|NavigationView|NavigationSplitView|Color|Font|Spacer|Divider|EmptyView|Rectangle|RoundedRectangle|Circle|Capsule|GeometryReader)\s*[\(\{]|(?m)^\s*\.(padding|frame|background|foregroundStyle|foregroundColor|font|clipShape|cornerRadius|overlay|opacity|offset|position|scaledToFit|scaledToFill|resizable|aspectRatio|clipped|shadow|border|listRowInsets|listRowBackground|navigationTitle|toolbar|sheet|fullScreenCover|alert|confirmationDialog|popover|contextMenu|task|onAppear|onDisappear|onChange|onTapGesture|onSubmit|searchable|disabled|hidden|environment|environmentObject|tag|badge|toggleStyle|buttonStyle|pickerStyle|textFieldStyle|labelsHidden|buttonBorderShape|controlSize|tint|lineLimit|fixedSize|commands|accessibilityLabel|accessibilityHint|accessibilityValue|accessibilityHidden|accessibilityIdentifier|onMove|onDelete|onInsert|sink|store|assign|safeAreaInset|focused|focusState|scrollContentBackground|containerRelativeFrame|markdownTextStyle|paragraph|strong|listItem|text|selectionDisabled|textSelection|onHover|contentShape|symbolRenderingMode|symbolEffect|sensoryFeedback|scrollBounceBehavior)\b|\bif\s+[a-zA-Z_][a-zA-Z0-9_.]*\s*!=\s*nil\b|\bas\?\s+[A-Z]|\btry\?\s+|\?\?)"#,
        options: []
    )
    
    /// コンパイラエラー・ビルドログの検出パターン
    private static let compilerErrorRegex = try? NSRegularExpression(
        pattern: #"(?m)^/[^:\n]+\.(swift|m|h|cpp|c|rs|go|py|ts|js):\d+:\d+:\s*(error|warning|note):|(?m)^\s*(No such module|Binary operator|Cannot find '[^']+' in scope|Undefined symbol:|Command CompileSwiftSources failed)\b"#,
        options: []
    )
    
    /// 多言語（英語、日本語、ドイツ語、フランス語、スペイン語等）の会話・プロンプト・前置き表現パターン
    private static let multilingualPromptLeadingRegex = try? NSRegularExpression(
        pattern: #"(?i)^(sure|here\s+is|here\s+are|here're|below\s+is|please|i\s+am|i'm|i\s+have|can\s+you|could\s+you|let's|this\s+is|this\s+code|note\s+that|check\s+the|as\s+you\s+can\s+see|you\s+can|we\s+can|hier\s+ist|hier\s+sind|bitte|danke|voici|voila|voilà|merci|aquí\s+está|aqui\s+esta|gracias)\b|^(はい、|承知|了解|現在|こちら|次は|以下の|この|先ほど|[^\n]{0,80}(です|ます|でした|ました|ください|思います|ですね|でしょうか|ありがとうございます|お願い|確認|相談|質問)[。、\n])"#,
        options: []
    )
    
    /// 明確なコード宣言や構文で始まる場合のキーワードプレフィックス一覧
    private static let codeLeadingPrefixes = [
        "import ", "#include", "package ", "func ", "function ", "def ", "class ", "struct ", "enum ",
        "let ", "var ", "const ", "public ", "private ", "fileprivate ", "internal ", "open ", "override ",
        "static ", "final ", "guard ", "if ", "for ", "while ", "switch ", "case ", "typealias ",
        "interface ", "protocol ", "extension ", "dependencies:", "targets:", "products:",
        "<!DOCTYPE", "<?xml", "<!--", "//", "/*", "#!/", "#", "{", "[", "SELECT ", "INSERT ", "UPDATE ", "DELETE ",
        "curl ", "git ", "npm ", "pnpm ", "yarn ", "cargo ", "brew ", "sudo ", "cd ", "mkdir ", "echo ",
        "cat ", "grep ", "export ", "chmod ", "chown ", "find ", "sed ", "awk ", "tar ", "kill ", "ps ",
        "systemctl ", "xcodebuild ", "python ", "node ", "with ", "try", "except", "catch", "print("
    ]
    
    /// Python特有の構文パターン（from...import、import...as、標準モジュールimport、def、class、elif、if __name__、with open等）
    private static let pythonSpecificRegex = try? NSRegularExpression(
        pattern: #"((?m)^\s*from\s+[a-zA-Z0-9_.]+\s+import\s+[a-zA-Z0-9_.*]+|(?m)^\s*import\s+[a-zA-Z0-9_.]+\s+as\s+[a-zA-Z0-9_]+|(?m)^\s*import\s+(os|sys|json|math|re|time|datetime|random|typing|collections|itertools|functools|subprocess|pathlib|shutil|logging|threading|asyncio|numpy|pandas|scipy|matplotlib|torch|tensorflow|sklearn|requests|flask|django|fastapi|pydantic|pytest|pygame)\b|\bdef\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\([^)\n]*\)\s*:|(?m)^\s*class\s+[a-zA-Z_][a-zA-Z0-9_]*(\([a-zA-Z0-9_., ]*\))?\s*:\s*(?:$|#|\n|\r)|(?m)^\s*elif\s+[^:\n]+:|\bif\s+__name__\s*==\s*['"]__main__['"]|(?m)^\s*with\s+open\s*\([^)\n]*\)\s*|\bctypes\.)"#,
        options: []
    )
    
    /// JavaScript / TypeScript特有の構文パターン（ブラウザAPI、ESモジュール、interface等）
    private static let javascriptSpecificRegex = try? NSRegularExpression(
        pattern: #"(\b(const\s+[a-zA-Z_][a-zA-Z0-9_]*\s*(=|:)|let\s+[a-zA-Z_][a-zA-Z0-9_]*\s*=\s*(function|\(.*?\)|\{)|function\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\(|console\.(log|error|warn|info)|export\s+(default|const|let|function|class)|async\s+function|type\s+[A-Z][a-zA-Z0-9_]*\s*=|\bdocument\.(getElementById|querySelector|querySelectorAll|addEventListener|createElement|body|head|title|cookie|location|documentElement)\b|\bwindow\.(addEventListener|location|localStorage|sessionStorage|setTimeout|setInterval|alert|confirm|prompt|open|close|scrollTo|scrollBy|fetch|matchMedia)\b)|\binterface\s+[A-Za-z0-9_]+\s*\{|=>|(?m)^\s*import\s+[^;\n]+\s+from\s+['"][^'"]+['"])"#,
        options: []
    )
    
    /// シェルコマンド・ターミナルセッション特有の構文パターン（フルパス実行、for/whileループ、環境変数設定、zshプロンプト等）
    private static let shellSpecificRegex = try? NSRegularExpression(
        pattern: #"(^#!\s*/(bin|usr)/(bash|zsh|sh)|^Last login:\s+|(?m)^\s*([a-zA-Z0-9_.-]+@[a-zA-Z0-9_.-]+[^#$%\n]*[#$%>]|[$➜%])\s+|(?m)^\s*(/(opt|usr|bin|sbin|etc|Library|System)/[a-zA-Z0-9_./-]+)\s+|(?m)^\s*[A-Za-z_][A-Za-z0-9_]*=[^;\n]+\s*(&&|;)\s*|\bfor\s+[a-zA-Z_][a-zA-Z0-9_]*\s+in\s+[^;]+;\s*do\b|\bwhile\s+[^;]+;\s*do\b|\bif\s+\[\[?\s+[^;]+;\s*then\b|(?m)^\s*(sudo|chmod|chown|mkdir|grep|cat|curl|wget|npm|yarn|pnpm|cargo|xcodebuild|brew|git|docker|kubectl|systemctl|lspci|lsof|netstat|ps|kill|ssh|scp|tar|find|export|source|echo|uptime|apt|apt-get|dnf|pacman|yum|pip|pip3|python|node|deno|bun|sed|awk|df|du|top|htop|journalctl|rsync|touch|cp|mv|rm|alias|smartctl)\b|(?m)^\s*echo\s+.*?(>>|>|\|)\s*|\b\|\s*(grep|jq|awk|sed|cat|tee|xargs|tr|cut|sort|uniq|head|tail|wc)\b)"#,
        options: []
    )
    
    /// 定義系キーワード（行頭または修飾子の後、または括弧/波括弧/コロンが続く）
    private static let definitionKeywordsRegex = try? NSRegularExpression(
        pattern: #"(?m)^\s*(public\s+|private\s+|fileprivate\s+|internal\s+|open\s+|static\s+|final\s+|override\s+|export\s+|async\s+)?(func|function|def|fn|sub|class|struct|enum|interface|protocol|trait|extension|typealias)\s+[a-zA-Z_][a-zA-Z0-9_]*|\b(func|def|function)\s+[a-zA-Z_][a-zA-Z0-9_]*\s*[\(:]|\b(class|struct|enum|interface)\s+[A-Z][a-zA-Z0-9_]*\s*([:{<]|\bextends\b|\bimplements\b)|\btype\s+[A-Z][a-zA-Z0-9_]*\s*="#,
        options: []
    )
    
    /// インポート文（行頭からの import, #include, from ... import, require等）
    private static let importKeywordsRegex = try? NSRegularExpression(
        pattern: #"(?m)^\s*(import\s+[a-zA-Z_]|#include\s*[<"]|from\s+[a-zA-Z0-9_.]+\s+import|require\s*\(['"][a-zA-Z0-9_\-./]+['"]\))"#,
        options: []
    )
    
    /// 宣言系キーワード（let, var, const, val等 + 変数名 + 代入/型宣言）
    private static let declarationKeywordsRegex = try? NSRegularExpression(
        pattern: #"\b(let|var|const|val)\s+[a-zA-Z_][a-zA-Z0-9_]*\s*(=|:)"#,
        options: []
    )
    
    /// 修飾子 + 宣言（public func, private var, export default, async function等）
    private static let modifierDeclarationRegex = try? NSRegularExpression(
        pattern: #"\b(public|private|protected|internal|fileprivate|open|static|final|override|export\s+default|export|async|await)\s+(func|var|let|val|class|struct|def|function|void|int|string|bool|const)"#,
        options: []
    )
    
    /// 制御構文キーワード（if, for, while, switch, guard, catch等 + 括弧やブロック）
    private static let controlFlowRegex = try? NSRegularExpression(
        pattern: #"\b(if|while|for|switch|guard|catch|except)\s*[\(\{]"#,
        options: []
    )
    
    /// 出力・ログ文（print(...), console.log(...), System.out.println等）
    private static let printOrLogRegex = try? NSRegularExpression(
        pattern: #"(\bconsole\.(log|error|warn|info|debug)\s*\(|\bprint\s*\(|\bSystem\.out\.println\s*\(|\bprintf\s*\(|\becho\s+["'])"#,
        options: []
    )
    
    /// アロー記号や比較・代入演算子（->, =>, ===, !==, ==, !=, +=, etc.）
    private static let operatorsRegex = try? NSRegularExpression(
        pattern: #"(->|=>|===|!==|!=|==|\+=|-=|\*=|\/=|&&|\|\||\b=\s*[^=])"#,
        options: []
    )
    
    /// コード特有のリテラル・キーワード（true, false, nil, null, undefined, None等）
    private static let codeLiteralsRegex = try? NSRegularExpression(
        pattern: #"\b(true|false|True|False|nil|null|None|nullptr|undefined|NaN)\b"#,
        options: []
    )
    
    /// 日本語の一般的な文章表現パターン（除外スコア用）
    private static let naturalJapaneseRegex = try? NSRegularExpression(
        pattern: #"(です|ます|でした|ました|こと|これ|それ|あれ|します|お願い|ありがとう|確認|連絡)[。、\n]"#,
        options: []
    )
    
    // MARK: - 主判定メソッド
    
    /// 指定されたテキストがソースコードであるかを判定する
    /// - Parameter text: 判定対象の文字列
    /// - Returns: ソースコードと判定された場合は true
    public static func isCode(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 短すぎる文字列はコードとみなさない（3文字以下は除外）
        guard trimmed.count >= 3 else { return false }
        
        // 1単語のみ（空白・改行・コード特有記号を含まない英数字単体（型名や変数名単体））は非コード
        if !trimmed.contains("\n") && !trimmed.contains(" ") && !trimmed.contains("(") && !trimmed.contains(")") && !trimmed.contains("=") && !trimmed.contains(";") && !trimmed.contains("{") && !trimmed.contains("}") && !trimmed.contains("<") && !trimmed.contains(">") && !trimmed.contains(".") && !trimmed.contains(":") && !trimmed.contains("[") && !trimmed.contains("]") && !trimmed.contains("->") && !trimmed.contains("$") && !trimmed.contains("\"") && !trimmed.contains("'") && !trimmed.contains("/") && !trimmed.contains("`") && !trimmed.contains("#") {
            return false
        }
        
        // 1行かつ英小文字・数字・ドット・ハイフンのみで構成される識別子（SFシンボル名やドメイン名等）は非コード
        if !trimmed.contains("\n") && !trimmed.contains(" ") && !trimmed.contains("(") && !trimmed.contains("=") && !trimmed.contains(";") && !trimmed.contains("{") {
            let identifierPattern = #"^[a-z0-9_-]+(\.[a-z0-9_-]+)+$"#
            if trimmed.range(of: identifierPattern, options: .regularExpression) != nil {
                return false
            }
        }
        
        // 1. シェバン（#!/bin/bash など）
        if trimmed.hasPrefix("#!/") {
            return true
        }
        
        // 2. Markdownコードブロック（``` など）またはMarkdown構文（見出し、リンク、画像等）
        if trimmed.hasPrefix("```") || isMarkdown(trimmed) {
            return true
        }
        
        // パフォーマンス最優先：先頭500文字のみをサンプリング
        let sample = trimmed.count > 500 ? String(trimmed.prefix(500)) : trimmed
        let sampleRange = NSRange(sample.startIndex..., in: sample)
        
        // コンパイルエラーログ・ビルドログの判定（ソースコードではないため非コード）
        if let compilerErrorRegex = compilerErrorRegex, compilerErrorRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return false
        }
        
        // 多言語会話文・プロンプト・通常文章から始まっている場合（コードブロック ``` で囲まれておらず、Markdown見出しを持たない場合は非コード）
        let firstLine = trimmed.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? ""
        let isCodeLeading = codeLeadingPrefixes.contains { kw in
            firstLine.hasPrefix(kw) || firstLine.lowercased().hasPrefix(kw.lowercased())
        }
        if !isCodeLeading {
            let firstLineRange = NSRange(firstLine.startIndex..<firstLine.endIndex, in: firstLine)
            let isPromptLeading = multilingualPromptLeadingRegex?.firstMatch(in: firstLine, options: [], range: firstLineRange) != nil
            let words = firstLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let isSentenceLeading = words.count >= 4 && (firstLine.hasSuffix(".") || firstLine.hasSuffix("!") || firstLine.hasSuffix("?") || firstLine.hasSuffix("。") || firstLine.hasSuffix("！") || firstLine.hasSuffix("？"))
            
            if isPromptLeading || isSentenceLeading {
                if !isMarkdown(trimmed) {
                    return false
                }
            }
        }
        
        // 3. シェルコマンド・ターミナルセッションの判定
        if let shellRegex = shellSpecificRegex, shellRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return true
        }
        
        // 4. Python・Swift・JS等の各言語特有構文パターン
        if let pythonRegex = pythonSpecificRegex, pythonRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return true
        }
        if let swiftRegex = swiftSpecificRegex, swiftRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return true
        }
        if let jsRegex = javascriptSpecificRegex, jsRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return true
        }
        if let goRegex = goSpecificRegex, goRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return true
        }
        if let rustRegex = rustSpecificRegex, rustRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return true
        }
        if let javaKotlinRegex = javaKotlinSpecificRegex, javaKotlinRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return true
        }
        if let cppRegex = cppSpecificRegex, cppRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return true
        }
        
        // 5. クラッシュレポート・診断ログ（その他のコードとして扱う）
        if trimmed.contains("Translated Report") ||
           (trimmed.contains("Process:") && trimmed.contains("Path:") && trimmed.contains("Identifier:")) ||
           trimmed.contains("Crashed Thread:") ||
           trimmed.contains("Exception Type:") ||
           trimmed.contains("Thread 0 Crashed:") {
            return true
        }
        
        // 6. JSON構造の判定
        if isJSON(trimmed) {
            return true
        }
        
        // 6. Markdown文書構造の判定
        if isMarkdown(trimmed) {
            return true
        }
        
        // 7. YAML構造の判定
        if isYAML(trimmed) {
            return true
        }
        
        // 8. TOML構造の判定
        if isTOML(trimmed) {
            return true
        }
        
        // 9. GraphQL構造の判定
        if isGraphQL(trimmed) {
            return true
        }
        
        // 10. 環境変数 (.env) 構造の判定
        if isEnv(trimmed) {
            return true
        }
        
        // 11. HTML / XML / CSS / SQL の判定
        if isMarkupOrSQL(sample, range: sampleRange) {
            return true
        }
        
        // 12. ヒューリスティックスコアリング判定
        let score = calculateScore(for: sample, range: sampleRange)
        return score >= 2.0
    }
    
    /// 指定されたテキストのプログラミング言語・データ形式を検出する
    /// - Parameter text: 判定対象の文字列
    /// - Returns: 検出された言語（コードでない場合は nil）
    public static func detectLanguage(_ text: String) -> CodeLanguage? {
        guard isCode(text) else { return nil }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let sample = trimmed.count > 500 ? String(trimmed.prefix(500)) : trimmed
        let sampleRange = NSRange(sample.startIndex..., in: sample)
        
        // 1. Markdownコードブロック指定の言語チェック
        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: .newlines)
            let firstLine = lines.first ?? ""
            let lang = firstLine.trimmingCharacters(in: CharacterSet(charactersIn: "` \t")).lowercased()
            switch lang {
            case "swift": return .swift
            case "js", "javascript", "ts", "typescript", "jsx", "tsx": return .javascript
            case "py", "python": return .python
            case "html", "htm", "xml": return .html
            case "css", "scss", "sass", "less": return .css
            case "json": return .json
            case "yaml", "yml": return .yaml
            case "toml": return .toml
            case "md", "markdown": return .markdown
            case "graphql", "gql": return .graphql
            case "env": return .env
            case "rust", "rs": return .rust
            case "go", "golang": return .go
            case "c", "cpp", "c++", "h", "hpp": return .cpp
            case "java", "kotlin", "kt": return .javaKotlin
            case "sql": return .sql
            case "sh", "bash", "zsh", "shell": return .shell
            default:
                // 言語指定がない場合、中身のコードを解析
                if lines.count >= 2 {
                    var innerLines = lines
                    innerLines.removeFirst()
                    if innerLines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
                        innerLines.removeLast()
                    }
                    let innerCode = innerLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !innerCode.isEmpty, let innerLang = detectLanguage(innerCode), innerLang != .other {
                        return innerLang
                    }
                }
                // 特定できなければMarkdown構文として.markdownを返す
                return .markdown
            }
        }
        
        // 2. シェバン
        if trimmed.hasPrefix("#!/") {
            return .shell
        }
        
        // 3. Markdown（見出し、リスト、太字、引用、リンク等を含む構造化文書をコードより優先）
        if isMarkdown(trimmed) {
            return .markdown
        }
        
        // 4. JSON
        if isJSON(trimmed) {
            return .json
        }
        
        // 5. Go（package宣言、レシーバー付きfunc、go/defer等）
        if let goRegex = goSpecificRegex, goRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return .go
        }
        
        // 6. C / C++（#include <...> を HTMLタグより先に検出）
        if let cppRegex = cppSpecificRegex, cppRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return .cpp
        }
        
        // 7. Swift（Swift特有構文・SwiftUIモディファイア・マクロ・import・.swiftコメント・SPM）
        if let swiftSpecificRegex = swiftSpecificRegex, swiftSpecificRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return .swift
        }
        
        // 8. シェルスクリプト・ターミナルセッション（curl+出力、echoパイプ、ターミナルログ、コマンド列）
        if let shellSpecificRegex = shellSpecificRegex, shellSpecificRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return .shell
        }
        
        // 9. Python（from...import, def...:, class...:, import numpy/os/sys等）
        if let pythonSpecificRegex = pythonSpecificRegex, pythonSpecificRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return .python
        }
        
        // 10. JavaScript / TypeScript（ブラウザAPI、DOM、ESモジュール等）
        if let jsRegex = javascriptSpecificRegex, jsRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return .javascript
        }
        
        // 11. Java / Kotlin
        if let javaKotlinRegex = javaKotlinSpecificRegex, javaKotlinRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return .javaKotlin
        }
        
        // 12. Rust
        if let rustRegex = rustSpecificRegex, rustRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return .rust
        }
        
        // 12. JavaScript / TypeScript
        if let javascriptSpecificRegex = javascriptSpecificRegex, javascriptSpecificRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return .javascript
        }
        
        // 13. HTML / XML（純粋なHTMLタグ構造）
        if let htmlTagRegex = htmlTagRegex, htmlTagRegex.numberOfMatches(in: sample, options: [], range: sampleRange) >= 1 {
            return .html
        }
        
        // 14. GraphQL
        if isGraphQL(trimmed) {
            return .graphql
        }
        
        // 15. 環境変数 (.env)
        if isEnv(trimmed) {
            return .env
        }
        
        // 16. CSS（YAMLより先に検出、HTML開始タグを除く）
        if !trimmed.hasPrefix("<"), let cssPropertyRegex = cssPropertyRegex, cssPropertyRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return .css
        }
        
        // 17. YAML（Markdown/CSSがfalseの場合のみ検出）
        if isYAML(trimmed) {
            return .yaml
        }
        
        // 18. TOML
        if isTOML(trimmed) {
            return .toml
        }
        
        // 19. SQL
        if let sqlRegex = sqlRegex, sqlRegex.firstMatch(in: sample, options: [], range: sampleRange) != nil {
            return .sql
        }
        
        // 20. その他
        return .other
    }
    
    // MARK: - 個別形式判定
    
    /// JSON形式であるかを判定
    private static func isJSON(_ text: String) -> Bool {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 丸括弧で囲まれている場合（例: ({ "ok": true })）
        if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
            trimmed = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 先頭の閉じ波括弧や角括弧から始まるJSON断片（例: }, "context": { ... }）
        if trimmed.hasPrefix("},") || trimmed.hasPrefix("],") {
            let candidate = "{" + String(trimmed.dropFirst(2)) + "}"
            if let data = candidate.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
                return true
            }
        }
        
        // 通常のオブジェクト / 配列
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if let data = trimmed.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
                return true
            }
            // 部分文字列等でのフォールバック
            let sample = trimmed.count > 500 ? String(trimmed.prefix(500)) : trimmed
            let sampleRange = NSRange(sample.startIndex..., in: sample)
            if let jsonKeyRegex = jsonKeyRegex, jsonKeyRegex.numberOfMatches(in: sample, options: [], range: sampleRange) >= 1 {
                return true
            }
        }
        
        // プロパティキーから始まるJSON断片（例: "details": { ... }）
        if trimmed.hasPrefix("\"") && trimmed.contains(":") {
            let candidate = "{" + trimmed + "}"
            if let data = candidate.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// YAML形式であるかを判定
    private static func isYAML(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") || trimmed.hasPrefix("<") { return false }
        if isMarkdown(trimmed) { return false }
        if trimmed.contains("##") || trimmed.contains("###") || trimmed.contains("**") { return false }
        
        // クラッシュレポート・診断レポート・パニックレポートを除外（.other として扱う）
        if trimmed.contains("Translated Report") ||
           (trimmed.contains("Process:") && trimmed.contains("Path:") && trimmed.contains("Identifier:")) ||
           trimmed.contains("Crashed Thread:") ||
           trimmed.contains("Exception Type:") ||
           trimmed.contains("Thread 0 Crashed:") {
            return false
        }
        
        // CSSやJava等のセミコロン文（property: value;）を除外
        if trimmed.contains(";\n") || trimmed.hasSuffix(";") {
            return false
        }
        
        // エラーログやスタックトレース（Error: ..., at Server...）を除外
        if trimmed.contains("Error: ") || trimmed.contains("at Server.") || trimmed.contains("at async ") || trimmed.contains("at Object.") {
            return false
        }
        
        // lspci やハードウェア情報・PCIデバイスログ（Subsystem:, Kernel driver in use: 等）を除外
        if trimmed.contains("Kernel driver in use:") || trimmed.contains("Kernel modules:") || trimmed.contains("Subsystem:") || trimmed.range(of: #"(?m)^[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]"#, options: .regularExpression) != nil {
            return false
        }
        
        // Swift Package Manager (Package.swift) の依存関係宣言（.package(url:, .target(name: 等）を除外
        if trimmed.contains(".package(") || trimmed.contains(".target(") || trimmed.contains(".testTarget(") || trimmed.contains(".library(") || trimmed.contains(".executableTarget(") {
            return false
        }
        
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 || trimmed.hasPrefix("---") else { return false }
        
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let hasDocStart = (yamlDocStartRegex?.numberOfMatches(in: trimmed, options: [], range: range) ?? 0) >= 1
        let keyMatches = yamlKeyRegex?.numberOfMatches(in: trimmed, options: [], range: range) ?? 0
        let listMatches = yamlListRegex?.numberOfMatches(in: trimmed, options: [], range: range) ?? 0
        
        let hasIndentedKeys = lines.contains { line in
            (line.hasPrefix("  ") || line.hasPrefix("\t")) && line.contains(":")
        }
        
        if hasDocStart && (keyMatches >= 1 || listMatches >= 1) {
            return true
        }
        if hasIndentedKeys && (keyMatches >= 1 || listMatches >= 1) {
            return true
        }
        if listMatches >= 2 && keyMatches >= 1 {
            return true
        }
        return false
    }
    
    /// TOML形式であるかを判定
    private static func isTOML(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[{") || trimmed.hasPrefix("<") { return false }
        // SDP (Session Description Protocol) 形式（v=0, o=, s=, t=, a=, m=）を除外
        if trimmed.hasPrefix("v=0\n") || (trimmed.contains("a=rtpmap:") && trimmed.contains("m=audio")) { return false }
        // HTMLの属性（data-xxx="yyy"）を除外
        if trimmed.contains("data-") { return false }
        
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let hasTable = (tomlTableRegex?.numberOfMatches(in: trimmed, options: [], range: range) ?? 0) >= 1
        let keyValues = tomlKeyValueRegex?.numberOfMatches(in: trimmed, options: [], range: range) ?? 0
        
        return (hasTable && keyValues >= 1) || keyValues >= 2
    }
    
    /// GraphQL形式であるかを判定
    private static func isGraphQL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // セミコロンを含む文（TypeScriptのinterfaceやJava等）はGraphQLとみなさない
        if trimmed.contains(";") { return false }
        
        let sample = trimmed.count > 500 ? String(trimmed.prefix(500)) : trimmed
        let range = NSRange(sample.startIndex..., in: sample)
        
        return (graphqlRegex?.numberOfMatches(in: sample, options: [], range: range) ?? 0) >= 1
    }
    
    /// 環境変数 (.env) 形式であるかを判定
    private static func isEnv(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") || trimmed.hasPrefix("#!/") || trimmed.hasPrefix("<") { return false }
        
        let sample = trimmed.count > 500 ? String(trimmed.prefix(500)) : trimmed
        let range = NSRange(sample.startIndex..., in: sample)
        let envMatches = envLineRegex?.numberOfMatches(in: sample, options: [], range: range) ?? 0
        
        return envMatches >= 2
    }
    
    /// Markdown形式であるかを判定
    private static func isMarkdown(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[{") || trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("#!/") || trimmed.hasPrefix("Last login:") { return false }
        if trimmed.contains("Translated Report") || (trimmed.contains("Process:") && trimmed.contains("Path:")) { return false }
        
        let sample = trimmed.count > 1000 ? String(trimmed.prefix(1000)) : trimmed
        let range = NSRange(sample.startIndex..., in: sample)
        
        let headingMatches = markdownHeadingRegex?.numberOfMatches(in: sample, options: [], range: range) ?? 0
        let listMatches = markdownListRegex?.numberOfMatches(in: sample, options: [], range: range) ?? 0
        let numListMatches = markdownNumberedListRegex?.numberOfMatches(in: sample, options: [], range: range) ?? 0
        let boldMatches = markdownBoldRegex?.numberOfMatches(in: sample, options: [], range: range) ?? 0
        let linkMatches = markdownLinkRegex?.numberOfMatches(in: sample, options: [], range: range) ?? 0
        let tableMatches = markdownTableRegex?.numberOfMatches(in: sample, options: [], range: range) ?? 0
        let blockquoteMatches = markdownBlockquoteRegex?.numberOfMatches(in: sample, options: [], range: range) ?? 0
        
        // 文書の途中に埋め込まれたコードブロック（```）が存在するか（先頭から全体が```で始まっている単体コードブロックは除く）
        let hasEmbeddedCodeBlock = !trimmed.hasPrefix("```") && trimmed.contains("```")
        
        // シェルコマンドやプロンプトが含まれている場合は、見出し・リスト等のMarkdown構造が明確な場合のみMarkdown
        if let shellRegex = shellSpecificRegex, shellRegex.numberOfMatches(in: sample, options: [], range: range) >= 1 {
            if (headingMatches >= 2 || blockquoteMatches >= 1) && (listMatches >= 1 || boldMatches >= 1 || linkMatches >= 1) {
                // 通常のMarkdownドキュメント
            } else {
                return false
            }
        }
        
        // 構造化されたMarkdownドキュメントの判定
        let isStrongMarkdown = (headingMatches >= 2) ||
                               (headingMatches >= 1 && (listMatches >= 1 || numListMatches >= 1 || boldMatches >= 1 || linkMatches >= 1 || blockquoteMatches >= 1)) ||
                               (blockquoteMatches >= 1 && (boldMatches >= 1 || listMatches >= 1 || headingMatches >= 1)) ||
                               (hasEmbeddedCodeBlock && (boldMatches >= 1 || listMatches >= 1 || numListMatches >= 1 || headingMatches >= 1)) ||
                               (boldMatches >= 2 && (listMatches >= 1 || numListMatches >= 1)) ||
                               (tableMatches >= 2)
        
        if !isStrongMarkdown {
            if let pyRegex = pythonSpecificRegex, pyRegex.numberOfMatches(in: sample, options: [], range: range) >= 1 {
                return false
            }
            if let swiftRegex = swiftSpecificRegex, swiftRegex.numberOfMatches(in: sample, options: [], range: range) >= 1 {
                return false
            }
            if let jsRegex = javascriptSpecificRegex, jsRegex.numberOfMatches(in: sample, options: [], range: range) >= 1 {
                return false
            }
        }
        
        if isStrongMarkdown { return true }
        
        // YAMLの典型構造（apiVersion, metadata, spec等）を持つ場合は YAML
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let hasIndentedKeys = lines.contains { line in
            (line.hasPrefix("  ") || line.hasPrefix("\t")) && line.contains(":")
        }
        if hasIndentedKeys && lines.contains(where: { $0.contains("apiVersion:") || $0.contains("spec:") || $0.contains("metadata:") }) {
            return false
        }
        
        if tableMatches >= 2 { return true }
        if headingMatches >= 2 { return true }
        if headingMatches >= 1 && (listMatches >= 1 || numListMatches >= 1 || boldMatches >= 1 || linkMatches >= 1) { return true }
        if (listMatches >= 1 || numListMatches >= 1) && boldMatches >= 1 { return true }
        if linkMatches >= 1 { return true }
        if listMatches >= 2 && !hasIndentedKeys { return true } // リスト単独
        if headingMatches >= 1 && !hasIndentedKeys { return true } // 行頭に # 見出し があれば Markdown
        if (trimmed.hasPrefix("```") && trimmed.hasSuffix("```")) || trimmed.contains("```") { return true } // Markdownコードブロック
        
        return false
    }
    
    /// マークアップ言語またはSQLであるかを判定
    private static func isMarkupOrSQL(_ text: String, range: NSRange) -> Bool {
        // HTMLタグ
        if let htmlTagRegex = htmlTagRegex, htmlTagRegex.numberOfMatches(in: text, options: [], range: range) >= 1 {
            return true
        }
        
        // CSS
        if let cssPropertyRegex = cssPropertyRegex, cssPropertyRegex.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
        
        // SQL文
        if let sqlRegex = sqlRegex, sqlRegex.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
        
        return false
    }
    
    // MARK: - スコアリングロジック
    
    /// プログラミングコードの特徴量スコアを算出
    private static func calculateScore(for text: String, range: NSRange) -> Double {
        var score: Double = 0.0
        
        // 定義系キーワード（+2.0）
        if let regex = definitionKeywordsRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            score += 2.0
        }
        
        // インポート文（+2.0）
        if let regex = importKeywordsRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            score += 2.0
        }
        
        // 宣言系キーワード（+2.0）
        if let regex = declarationKeywordsRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            score += 2.0
        }
        
        // 修飾子 + 宣言（+1.5）
        if let regex = modifierDeclarationRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            score += 1.5
        }
        
        // 制御構文（+1.0）
        if let regex = controlFlowRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            score += 1.0
        }
        
        // 出力・ログ文（+2.0）
        if let regex = printOrLogRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            score += 2.0
        }
        
        // 演算子・記号（+0.8）
        if let regex = operatorsRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            score += 0.8
        }
        
        // リテラル・特殊値（+0.8）
        if let regex = codeLiteralsRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            score += 0.8
        }
        
        // 波括弧ブロック { ... } が存在するか（+0.8）
        if text.contains("{") && text.contains("}") {
            score += 0.8
        }
        
        // 行末セミコロンが存在するか（+0.5）
        if text.contains(";\n") || text.hasSuffix(";") {
            score += 0.5
        }
        
        // 複数行でインデント（スペース2つ以上またはタブ）が存在するか（+0.7）
        let lines = text.components(separatedBy: .newlines)
        if lines.count >= 2 {
            let indentedLines = lines.filter { line in
                line.hasPrefix("  ") || line.hasPrefix("\t")
            }
            if !indentedLines.isEmpty {
                score += 0.7
            }
        }
        
        // 自然言語（日本語文章）のペナルティ減算
        if let regex = naturalJapaneseRegex {
            let japaneseMatches = regex.numberOfMatches(in: text, options: [], range: range)
            if japaneseMatches >= 2 {
                score -= Double(japaneseMatches) * 1.5
            }
        }
        
        // 英文の通常文章判定（スペース区切りの単語で構成され、コード特有の構文・記号がない場合）
        // ※ 既にインポート文や定義、宣言、ログ出力などの明確なコードキーワード（score >= 2.0）がある場合は減算しない
        if score < 2.0 {
            let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            if words.count >= 4 {
                let hasCodeDelimiters = text.contains(";") || text.contains("{") || text.contains("}") ||
                                       text.contains("=") || text.contains("->") || text.contains("=>") ||
                                       text.contains("//") || text.contains("/*") || text.contains("::") ||
                                       (text.contains("(") && text.contains(")"))
                if !hasCodeDelimiters {
                    score -= 2.0
                }
            }
        }
        
        return score
    }
}

import Testing
@testable import Clip_Hold

struct CodeDetectorTests {
    
    // MARK: - ソースコード判定（isCode: true）のテスト
    
    @Test("Swiftコードの判定")
    func testSwiftCodeDetection() {
        // 関数定義・戻り値
        let swiftCode1 = """
        func calculateTotal(items: [Double]) -> Double {
            return items.reduce(0, +)
        }
        """
        #expect(CodeDetector.isCode(swiftCode1))
        
        // 変数・定数宣言（型注釈付き）
        let swiftCode2 = "let maxCount: Int = 100"
        #expect(CodeDetector.isCode(swiftCode2))
        
        let swiftCode3 = "var isCompleted: Bool = false"
        #expect(CodeDetector.isCode(swiftCode3))
        
        let swiftCode4 = """
        // Application configuration
        private let serverPortNumber: Int = 8080
        """
        #expect(CodeDetector.isCode(swiftCode4))
        
        // 構造体・プロトコル準拠
        let swiftCode5 = """
        struct UserProfile: Identifiable, Codable {
            let id: UUID
            var username: String
            var email: String
        }
        """
        #expect(CodeDetector.isCode(swiftCode5))
        
        // SwiftUIプロパティラッパー
        let swiftCode6 = "@State private var isSheetPresented: Bool = false"
        #expect(CodeDetector.isCode(swiftCode6))
        
        let swiftCode7 = "@Binding var selectedIndex: Int"
        #expect(CodeDetector.isCode(swiftCode7))
        
        let swiftCode8 = "@AppStorage(\"hasCompletedOnboarding\") private var hasCompletedOnboarding: Bool = false"
        #expect(CodeDetector.isCode(swiftCode8))
        
        // guard-let 構文
        let swiftCode9 = "guard let targetURL = URL(string: path) else { return }"
        #expect(CodeDetector.isCode(swiftCode9))
        
        // if-let 構文
        let swiftCode10 = "if let responseData = data as? [String: Any] { process(responseData) }"
        #expect(CodeDetector.isCode(swiftCode10))
        
        // enum定義
        let swiftCode11 = """
        enum NetworkState: Equatable {
            case idle
            case loading
            case success(Data)
            case failure(Error)
        }
        """
        #expect(CodeDetector.isCode(swiftCode11))
        
        // extension定義
        let swiftCode12 = """
        extension String {
            var trimmed: String {
                return self.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        """
        #expect(CodeDetector.isCode(swiftCode12))
        
        // SwiftUIモディファイアチェーン
        let swiftCode13 = """
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.blue)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        """
        #expect(CodeDetector.isCode(swiftCode13))
        #expect(CodeDetector.detectLanguage(swiftCode13) == .swift)
        
        let swiftCode14 = """
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.secondary)
        .onTapGesture {
            handleAction()
        }
        """
        #expect(CodeDetector.isCode(swiftCode14))
        #expect(CodeDetector.detectLanguage(swiftCode14) == .swift)
        
        // SwiftUI ビューコンポーネント
        let swiftCode15 = "Text(\"Label\").lineLimit(1).fixedSize(horizontal: true, vertical: false)"
        #expect(CodeDetector.isCode(swiftCode15))
        #expect(CodeDetector.detectLanguage(swiftCode15) == .swift)
        
        // コメントから始まるSwiftコード
        let swiftCode16 = """
        // Returns the default display title for the specified model
        if let config = appConfig, config.isEnabled && modelName.hasPrefix("demo") {
            return config.defaultTitle
        }
        """
        #expect(CodeDetector.isCode(swiftCode16))
        #expect(CodeDetector.detectLanguage(swiftCode16) == .swift)
    }
    
    @Test("JavaScript / TypeScriptコードの判定")
    func testJavaScriptCodeDetection() {
        // アロー関数・async/await
        let jsCode1 = """
        const handleClick = async () => {
            await fetchData();
        };
        """
        #expect(CodeDetector.isCode(jsCode1))
        
        // 通常の関数定義
        let jsCode2 = "function multiply(a, b) { return a * b; }"
        #expect(CodeDetector.isCode(jsCode2))
        
        // ESモジュール import
        let jsCode3 = "import React, { useState, useEffect } from 'react';"
        #expect(CodeDetector.isCode(jsCode3))
        
        // console.log
        let jsCode4 = "console.log('User logged in successfully', userId);"
        #expect(CodeDetector.isCode(jsCode4))
        
        // export宣言
        let jsCode5 = "export const apiEndpoint = 'https://api.example.com/v1';"
        #expect(CodeDetector.isCode(jsCode5))
        
        // TypeScript interface
        let jsCode6 = """
        interface AppConfig {
            apiUrl: string;
            retryCount: number;
            debugMode?: boolean;
        }
        """
        #expect(CodeDetector.isCode(jsCode6))
        
        // TypeScript typeエイリアス
        let jsCode7 = "type ButtonVariant = 'primary' | 'secondary' | 'danger';"
        #expect(CodeDetector.isCode(jsCode7))
        
        // DOM操作
        let jsCode8 = "document.addEventListener('DOMContentLoaded', () => { init(); });"
        #expect(CodeDetector.isCode(jsCode8))
    }
    
    @Test("Pythonコードの判定")
    func testPythonCodeDetection() {
        // 関数定義・内包表記
        let pythonCode1 = """
        def process_items(data):
            return [x.strip() for x in data if x]
        """
        #expect(CodeDetector.isCode(pythonCode1))
        
        // モジュールインポート
        let pythonCode2 = "import os\nfrom datetime import datetime, timezone"
        #expect(CodeDetector.isCode(pythonCode2))
        
        // print文（フォーマット文字列）
        let pythonCode3 = "print(f\"Processing value: {value}\")"
        #expect(CodeDetector.isCode(pythonCode3))
        
        // クラス定義
        let pythonCode4 = """
        class DataManager:
            def __init__(self, filepath: str):
                self.filepath = filepath
                self.records = []
        """
        #expect(CodeDetector.isCode(pythonCode4))
        
        // mainガード構文
        let pythonCode5 = """
        if __name__ == '__main__':
            main()
        """
        #expect(CodeDetector.isCode(pythonCode5))
        
        // with open 構文
        let pythonCode6 = """
        with open('config.json', 'r', encoding='utf-8') as file:
            config = json.load(file)
        """
        #expect(CodeDetector.isCode(pythonCode6))
        
        // ctypes・構造体・コメント付きPythonコード
        let pythonCode7 = """
        import ctypes

        # Define data structure for low-level memory buffer
        class NativeBuffer(ctypes.Structure):
            _fields_ = [("size", ctypes.c_ulong), ("address", ctypes.c_void_p)]

        if is_initialized:
            # --------------------------------------------------
            # Configuration Parameters
            # --------------------------------------------------
            buffer_limit = 4096
            max_channels = 8
            sample_rate = 44100.0
        """
        #expect(CodeDetector.isCode(pythonCode7))
        #expect(CodeDetector.detectLanguage(pythonCode7) == .python)
    }
    
    @Test("HTML / XMLの判定")
    func testHTMLAndXMLDetection() {
        let htmlCode1 = "<div class=\"main-content\"><p>Hello World</p></div>"
        #expect(CodeDetector.isCode(htmlCode1))
        
        let htmlCode2 = "<!DOCTYPE html><html><head><title>Test Page</title></head><body></body></html>"
        #expect(CodeDetector.isCode(htmlCode2))
        
        let htmlCode3 = "<button type=\"submit\" class=\"btn btn-primary\">Save Changes</button>"
        #expect(CodeDetector.isCode(htmlCode3))
        
        let xmlCode1 = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root><item id=\"1\">Sample</item></root>"
        #expect(CodeDetector.isCode(xmlCode1))
        
        let xmlCode2 = """
        <configuration>
            <property name="timeout">3000</property>
            <property name="retries">5</property>
        </configuration>
        """
        #expect(CodeDetector.isCode(xmlCode2))
        
        let htmlSnippet1 = "<h5>Updates</h5><ul><li>Resolved issue causing sync delay.</li><li>Improved UI responsiveness.</li></ul>"
        #expect(CodeDetector.isCode(htmlSnippet1))
        #expect(CodeDetector.detectLanguage(htmlSnippet1) == .html)
        
        let htmlSnippet2 = "<p><strong>UtilityApp</strong> is a tool that enhances clipboard workflow on your Mac.</p>"
        #expect(CodeDetector.isCode(htmlSnippet2))
        #expect(CodeDetector.detectLanguage(htmlSnippet2) == .html)
        
        let htmlPictureSnippet = "<picture><source media=\"(prefers-color-scheme: dark)\" srcset=\"https://example.com/dark.png\"><img src=\"light.png\"></picture>"
        #expect(CodeDetector.isCode(htmlPictureSnippet))
        #expect(CodeDetector.detectLanguage(htmlPictureSnippet) == .html)
    }
    
    @Test("JSONの判定")
    func testJSONDetection() {
        let jsonCode1 = """
        {
            "name": "Clip Hold",
            "version": "1.0.0",
            "enabled": true
        }
        """
        #expect(CodeDetector.isCode(jsonCode1))
        
        let jsonCode2 = "[{\"id\": 1, \"title\": \"Sample Note\"}, {\"id\": 2, \"title\": \"Second Note\"}]"
        #expect(CodeDetector.isCode(jsonCode2))
        
        // コロン前後にスペースがある整形済みJSON出力
        let jsonCodeWithSpaces = """
        {
          "server_config" : {
            "port" : 8080,
            "ssl_enabled" : true,
            "max_connections" : 1000
          },
          "environment" : "production",
          "allowed_origins" : [
            "https://example.com"
          ]
        }
        """
        #expect(CodeDetector.isCode(jsonCodeWithSpaces))
        
        // ネストした配列とオブジェクト
        let jsonCode3 = """
        {
          "data": {
            "users": [
              { "id": 101, "role": "admin" },
              { "id": 102, "role": "viewer" }
            ],
            "total_count": 2
          },
          "status": "ok"
        }
        """
        #expect(CodeDetector.isCode(jsonCode3))
        
        // 丸括弧付きJSON（JavaScript式）
        let jsonCode4 = "({ \"ok\": true, \"status\": 200, \"data\": { \"key\": \"value\" } })"
        #expect(CodeDetector.isCode(jsonCode4))
        #expect(CodeDetector.detectLanguage(jsonCode4) == .json)
        
        // キーから始まるJSONプロパティ断片
        let jsonCode5 = "\"details\": { \"format\": \"safetensors\", \"family\": \"CustomModel\", \"families\": null }"
        #expect(CodeDetector.isCode(jsonCode5))
        #expect(CodeDetector.detectLanguage(jsonCode5) == .json)
        
        // 閉じ波括弧から始まるJSON断片
        let jsonCode6 = "}, \"context\": { \"fileName\": [\"DOCUMENT.md\"], \"includeDirectories\": [\"dir1\"] }"
        #expect(CodeDetector.isCode(jsonCode6))
        #expect(CodeDetector.detectLanguage(jsonCode6) == .json)
    }
    
    @Test("YAMLの判定")
    func testYAMLDetection() {
        let yamlCode1 = """
        version: "3.8"
        services:
          web:
            image: nginx:latest
            ports:
              - "80:80"
          db:
            image: postgres:15
            environment:
              POSTGRES_DB: sample
        """
        #expect(CodeDetector.isCode(yamlCode1))
        
        let yamlCode2 = """
        ---
        name: deploy-action
        on:
          push:
            branches:
              - main
        jobs:
          build:
            runs-on: macos-latest
        """
        #expect(CodeDetector.isCode(yamlCode2))
        
        let yamlCode3 = """
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: app-config
        data:
          app.properties: |
            key=value
        """
        #expect(CodeDetector.isCode(yamlCode3))
        
        // コメントから始まるYAML
        let yamlCode4 = """
        # Application deployment specification
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: service-worker
        spec:
          replicas: 3
        """
        #expect(CodeDetector.isCode(yamlCode4))
        #expect(CodeDetector.detectLanguage(yamlCode4) == .yaml)
    }
    
    @Test("TOMLの判定")
    func testTOMLDetection() {
        let tomlCode1 = """
        [package]
        name = "clip-hold"
        version = "1.0.0"
        edition = "2021"

        [dependencies]
        serde = "1.0"
        tokio = { version = "1.0", features = ["full"] }
        """
        #expect(CodeDetector.isCode(tomlCode1))
        
        let tomlCode2 = """
        [tool.poetry]
        name = "my-project"
        version = "0.1.0"
        description = "A sample Python project"
        authors = ["Developer <dev@example.com>"]

        [tool.poetry.dependencies]
        python = "^3.11"
        requests = "^2.31.0"
        """
        #expect(CodeDetector.isCode(tomlCode2))
    }
    
    @Test("Markdownの判定")
    func testMarkdownDetection() {
        let mdCode1 = """
        # Project Title

        ## Getting Started
        Please check the [documentation](https://example.com/docs) for details.

        - Feature 1
        - Feature 2
        """
        #expect(CodeDetector.isCode(mdCode1))
        
        let mdCode2 = """
        | Column 1 | Column 2 | Status |
        | --- | --- | --- |
        | Value A | Value B | Active |
        | Value C | Value D | Pending |
        """
        #expect(CodeDetector.isCode(mdCode2))
        
        let mdCode3 = """
        ### Release Highlights

        1. Improved detection performance
        2. Added multi-language support
        See [release notes](https://example.com/releases) for more information.
        """
        #expect(CodeDetector.isCode(mdCode3))
        
        let mdCode4 = """
        ## Overview
        ### New Features and Improvements
        - **Keyboard Shortcuts**: Added support for custom trigger hotkeys.
        - **Performance**: Optimized memory usage during large sync operations.
        """
        #expect(CodeDetector.isCode(mdCode4))
        #expect(CodeDetector.detectLanguage(mdCode4) == .markdown)
        
        let mdCode5 = """
        # 1. Build and Run Project
        Run `pnpm install` and start development server with `pnpm dev`.
        # 2. Deploy Application
        Execute `./deploy.sh --production` to publish.
        """
        #expect(CodeDetector.isCode(mdCode5))
        #expect(CodeDetector.detectLanguage(mdCode5) == .markdown)
        
        // 箇条書きリスト単独のMarkdown
        let mdCode6 = """
        - Core application architecture and lifecycle management
        - High performance caching and text indexing engine
        - Global shortcut routing with debounce handling
        """
        #expect(CodeDetector.isCode(mdCode6))
        #expect(CodeDetector.detectLanguage(mdCode6) == .markdown)
        
        // ``` で始まって ``` で終わるコードブロック単体（言語指定なし）
        let mdCode7 = """
        ```
        Sample plain text or general code block content
        Multiple lines of code block
        ```
        """
        #expect(CodeDetector.isCode(mdCode7))
        #expect(CodeDetector.detectLanguage(mdCode7) == .markdown)
        
        // ```markdown 指定のコードブロック
        let mdCode8 = """
        ```markdown
        # Heading inside markdown block
        - Item 1
        - Item 2
        ```
        """
        #expect(CodeDetector.isCode(mdCode8))
        #expect(CodeDetector.detectLanguage(mdCode8) == .markdown)
    }
    
    @Test("GraphQLの判定")
    func testGraphQLDetection() {
        let gqlCode1 = """
        query GetUserProfile($id: ID!) {
          user(id: $id) {
            id
            name
            email
            createdAt
          }
        }
        """
        #expect(CodeDetector.isCode(gqlCode1))
        
        let gqlCode2 = """
        mutation CreateNewItem($input: CreateItemInput!) {
          createItem(input: $input) {
            id
            title
            success
          }
        }
        """
        #expect(CodeDetector.isCode(gqlCode2))
        
        let gqlCode3 = """
        type User {
          id: ID!
          name: String!
          isActive: Boolean!
          posts: [Post!]!
        }
        """
        #expect(CodeDetector.isCode(gqlCode3))
    }
    
    @Test("環境変数 (.env) の判定")
    func testEnvDetection() {
        let envCode1 = """
        DATABASE_URL="postgres://user:pass@localhost:5432/app_db"
        API_SECRET_KEY=secret_token_12345
        NODE_ENV=production
        PORT=8080
        """
        #expect(CodeDetector.isCode(envCode1))
        
        let envCode2 = """
        AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
        AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
        AWS_DEFAULT_REGION=us-west-2
        """
        #expect(CodeDetector.isCode(envCode2))
    }
    
    @Test("Rustコードの判定")
    func testRustDetection() {
        let rustCode1 = """
        fn calculate_sum(numbers: &[i32]) -> i32 {
            numbers.iter().sum()
        }
        """
        #expect(CodeDetector.isCode(rustCode1))
        
        let rustCode2 = """
        pub struct Config {
            pub port: u16,
            pub host: String,
        }
        """
        #expect(CodeDetector.isCode(rustCode2))
        
        let rustCode3 = """
        impl ServiceHandler for MyService {
            fn handle_request(&self, req: Request) -> Result<Response, ServiceError> {
                println!("Handling incoming request");
                Ok(Response::new(200))
            }
        }
        """
        #expect(CodeDetector.isCode(rustCode3))
        
        let rustCode4 = """
        match result {
            Ok(value) => println!("Success: {}", value),
            Err(e) => eprintln!("Error: {}", e),
        }
        """
        #expect(CodeDetector.isCode(rustCode4))
    }
    
    @Test("Goコードの判定")
    func testGoDetection() {
        let goCode1 = """
        package main

        import "fmt"

        func main() {
            fmt.Println("Hello, World!")
        }
        """
        #expect(CodeDetector.isCode(goCode1))
        
        let goCode2 = """
        func fetchUser(id int) (*User, error) {
            user := &User{ID: id}
            return user, nil
        }
        """
        #expect(CodeDetector.isCode(goCode2))
        
        let goCode3 = """
        func (s *Server) Start() error {
            listener, err := net.Listen("tcp", s.Addr)
            if err != nil {
                return err
            }
            defer listener.Close()
            return nil
        }
        """
        #expect(CodeDetector.isCode(goCode3))
    }
    
    @Test("C / C++コードの判定")
    func testCPPDetection() {
        let cppCode1 = """
        #include <iostream>
        #include <vector>

        int main() {
            std::cout << "Running application" << std::endl;
            return 0;
        }
        """
        #expect(CodeDetector.isCode(cppCode1))
        
        let cppCode2 = """
        namespace Core {
            template <typename T>
            class Buffer {
            public:
                Buffer(size_t size) : capacity(size) {}
            private:
                size_t capacity;
            };
        }
        """
        #expect(CodeDetector.isCode(cppCode2))
        
        let cppCode3 = """
        #include "network/client.h"

        void initializeConnection() {
            auto ptr = nullptr;
        }
        """
        #expect(CodeDetector.isCode(cppCode3))
    }
    
    @Test("Java / Kotlinコードの判定")
    func testJavaKotlinDetection() {
        let javaCode1 = """
        package com.example.service;

        public class PaymentService {
            public void process() {
                System.out.println("Processing transaction");
            }
        }
        """
        #expect(CodeDetector.isCode(javaCode1))
        
        let javaCode2 = """
        public class DataController {
            @Override
            public String toString() {
                return "DataControllerInstance";
            }
        }
        """
        #expect(CodeDetector.isCode(javaCode2))
        
        let kotlinCode1 = """
        fun calculateAverage(values: List<Double>): Double {
            val total = values.sum()
            return total / values.size
        }
        """
        #expect(CodeDetector.isCode(kotlinCode1))
        
        let kotlinCode2 = """
        data class UserProfile(
            val id: Long,
            val username: String,
            val isActive: Boolean = true
        )
        """
        #expect(CodeDetector.isCode(kotlinCode2))
    }
    
    @Test("CSS / SCSSの判定")
    func testCSSDetection() {
        let cssCode1 = """
        .main-container {
            display: flex;
            background-color: #ffffff;
            margin: 0 auto;
        }
        """
        #expect(CodeDetector.isCode(cssCode1))
        
        let cssCode2 = "header.nav-bar { color: #333; font-size: 16px; line-height: 1.5; }"
        #expect(CodeDetector.isCode(cssCode2))
        
        let cssCode3 = """
        @media (max-width: 768px) {
            .sidebar {
                display: none;
            }
        }
        """
        #expect(CodeDetector.isCode(cssCode3))
    }
    
    @Test("SQLの判定")
    func testSQLDetection() {
        let sqlCode1 = "SELECT id, title, created_at FROM history_items WHERE is_pinned = 1 ORDER BY created_at DESC;"
        #expect(CodeDetector.isCode(sqlCode1))
        
        let sqlCode2 = "INSERT INTO phrases (title, content, created_at) VALUES ('Greeting', 'Hello World', datetime('now'));"
        #expect(CodeDetector.isCode(sqlCode2))
        
        let sqlCode3 = "UPDATE user_settings SET dark_mode = 1 WHERE user_id = 100;"
        #expect(CodeDetector.isCode(sqlCode3))
        
        let sqlCode4 = "DELETE FROM cache_entries WHERE expires_at < datetime('now');"
        #expect(CodeDetector.isCode(sqlCode4))
        
        let sqlCode5 = """
        CREATE TABLE IF NOT EXISTS clipboard_entries (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            item_type INTEGER NOT NULL
        );
        """
        #expect(CodeDetector.isCode(sqlCode5))
    }
    
    @Test("シェルスクリプト / コマンドの判定")
    func testShellScriptDetection() {
        let shellCode1 = """
        #!/bin/bash
        echo "Building application bundle..."
        exit 0
        """
        #expect(CodeDetector.isCode(shellCode1))
        
        let shellCode2 = "npm run build && yarn test"
        #expect(CodeDetector.isCode(shellCode2))
        
        let shellCode3 = "curl -X POST https://api.example.com/notify -d '{\"status\":\"ready\"}'"
        #expect(CodeDetector.isCode(shellCode3))
        
        let shellCode4 = "mkdir -p ./build/output && chmod 755 ./build/output"
        #expect(CodeDetector.isCode(shellCode4))
        
        // コメント付きシェルスクリプト
        let shellCode5 = """
        # Build project assets
        pnpm install
        # Start development server
        pnpm dev
        """
        #expect(CodeDetector.isCode(shellCode5))
        #expect(CodeDetector.detectLanguage(shellCode5) == .shell)
        
        // curlコマンド入力 + HTML出力
        let shellCode6 = """
        $ curl -i https://example.com/api
        HTTP/1.1 200 OK
        Content-Type: text/html
        
        <!DOCTYPE html>
        <html><body><h1>Response</h1></body></html>
        """
        #expect(CodeDetector.isCode(shellCode6))
        #expect(CodeDetector.detectLanguage(shellCode6) == .shell)
        
        // ターミナルセッションログ
        let shellCode7 = """
        Last login: Wed Aug 24 19:00:00 2026 from 10.0.0.1
        admin@node01:~$ lspci -nnk | grep -iA 2 audio
        00:1f.3 Audio controller [0403]: Intel Corporation Device [8086:7a50]
                Subsystem: Device [1043:8882]
        """
        #expect(CodeDetector.isCode(shellCode7))
        #expect(CodeDetector.detectLanguage(shellCode7) == .shell)
        
        // echo パイプワンライナー
        let shellCode8 = "echo '{\"status\": \"ok\"}' | jq ."
        #expect(CodeDetector.isCode(shellCode8))
        #expect(CodeDetector.detectLanguage(shellCode8) == .shell)
        
        let shellCode9 = "echo \"export PATH=$PATH:/opt/bin\" >> ~/.zshrc"
        #expect(CodeDetector.isCode(shellCode9))
        #expect(CodeDetector.detectLanguage(shellCode9) == .shell)
        
        // コメント行の直後にコマンド
        let shellCode10 = """
        # Check system uptime
        uptime
        """
        #expect(CodeDetector.isCode(shellCode10))
        #expect(CodeDetector.detectLanguage(shellCode10) == .shell)
        
        // フルパスから始まるコマンド実行
        let shellCode11 = "/usr/local/bin/custom-cli --version && /usr/local/bin/pkg-manager update > /dev/null 2>&1"
        #expect(CodeDetector.isCode(shellCode11))
        #expect(CodeDetector.detectLanguage(shellCode11) == .shell)
        
        // for ループ構文
        let shellCode12 = "for file in /var/log/application/*.log; do echo \"Processing: $file\"; done"
        #expect(CodeDetector.isCode(shellCode12))
        #expect(CodeDetector.detectLanguage(shellCode12) == .shell)
        
        // PATH 環境変数の連鎖代入と実行
        let shellCode13 = "PATH=/bin:/usr/bin:/usr/local/bin && /usr/local/bin/deploy-runner --check"
        #expect(CodeDetector.isCode(shellCode13))
        #expect(CodeDetector.detectLanguage(shellCode13) == .shell)
        
        // zsh プロンプト（%）付き実行
        let shellCode14 = "developer@workstation ~ % system-monitor --status --output json /dev/disk0"
        #expect(CodeDetector.isCode(shellCode14))
        #expect(CodeDetector.detectLanguage(shellCode14) == .shell)
    }
    
    // MARK: - 通常テキスト非コード判定（isCode: false）のテスト
    
    @Test("一般的な英語文章・コミットメッセージの非コード判定")
    func testNaturalEnglishNonCodeDetection() {
        // 通常の日常会話・メール文章
        #expect(!CodeDetector.isCode("This is a simple message for the entire engineering team."))
        #expect(!CodeDetector.isCode("The quick brown fox jumps over the lazy dog."))
        #expect(!CodeDetector.isCode("Please let me know if you need any further assistance with the setup."))
        #expect(!CodeDetector.isCode("We are scheduled to hold the sprint review meeting tomorrow at 10 AM."))
        #expect(!CodeDetector.isCode("Thank you very much for providing the requested project details."))
        
        // コードキーワード（import, class, return, select, update等）を含む自然な英語文章
        #expect(!CodeDetector.isCode("We need to import all customer records before proceeding."))
        #expect(!CodeDetector.isCode("The manager will return to the office next Monday."))
        #expect(!CodeDetector.isCode("Students attended a new literature class in the morning."))
        #expect(!CodeDetector.isCode("Please select your preferred option from the list."))
        #expect(!CodeDetector.isCode("Update the documentation according to the new style guidelines."))
        #expect(!CodeDetector.isCode("The function was attended by hundreds of alumni members."))
        
        // Gitコミットメッセージやリリースノート風の英文
        #expect(!CodeDetector.isCode("Fix unexpected window position issue during screen reconnection"))
        #expect(!CodeDetector.isCode("Improve memory footprint and caching performance on large items"))
        #expect(!CodeDetector.isCode("Prevent background task cancellation when switching spaces"))
        #expect(!CodeDetector.isCode("Add accessibility support for custom controls and tooltips"))
        #expect(!CodeDetector.isCode("Refactor settings layout to align with platform design guidelines"))
        
        // SFシンボル名やドット区切りの識別子単体
        #expect(!CodeDetector.isCode("document.badge.plus.fill"))
        #expect(!CodeDetector.isCode("point.3.filled.connected.triangle.path"))
        #expect(!CodeDetector.isCode("arrow.triangle.2.circlepath"))
        #expect(!CodeDetector.isCode("chevron.left.forwardslash.chevron.right"))
        #expect(!CodeDetector.isCode("slider.horizontal.3"))
    }
    
    @Test("一般的な日本語文章の非コード判定")
    func testNaturalJapaneseNonCodeDetection() {
        #expect(!CodeDetector.isCode("明日の15時から全体ミーティングを開始します。よろしくお願いします。"))
        #expect(!CodeDetector.isCode("この機能について確認させていただきました。特に問題ありませんでした。"))
        #expect(!CodeDetector.isCode("Clip HoldはmacOS用のクリップボード履歴マネージャーアプリです。"))
        #expect(!CodeDetector.isCode("インポートしたファイルの形式が正しいかどうかをチェックしてください。"))
        #expect(!CodeDetector.isCode("クラス全体の進捗状況をまとめて報告書を作成します。"))
        #expect(!CodeDetector.isCode("設定画面のデザインを最新のガイドラインに合わせて更新しました。"))
        #expect(!CodeDetector.isCode("ショートカットキーを押すことで素早くアイテムを呼び出すことができます。"))
    }
    
    @Test("空文字・極小文字の非コード判定")
    func testEmptyAndShortTextNonCodeDetection() {
        #expect(!CodeDetector.isCode(""))
        #expect(!CodeDetector.isCode("   "))
        #expect(!CodeDetector.isCode("a"))
        #expect(!CodeDetector.isCode("ok"))
        #expect(!CodeDetector.isCode("123"))
        #expect(!CodeDetector.isCode("hello"))
        #expect(!CodeDetector.isCode("sample note"))
    }
    
    // MARK: - 言語判定（detectLanguage）のテスト
    
    @Test("プログラミング言語の検出精度")
    func testLanguageDetection() {
        // Swift
        let swiftFunc = "func fetchProfile() -> UserProfile? { return nil }"
        #expect(CodeDetector.detectLanguage(swiftFunc) == .swift)
        
        let swiftConst = """
        // Application constant
        private let defaultTimeoutInterval: TimeInterval = 30.0
        """
        #expect(CodeDetector.detectLanguage(swiftConst) == .swift)
        
        let swiftState = "@Binding var isSheetActive: Bool"
        #expect(CodeDetector.detectLanguage(swiftState) == .swift)
        
        let swiftStruct = "struct CustomSettingsView: View { var body: some View { EmptyView() } }"
        #expect(CodeDetector.detectLanguage(swiftStruct) == .swift)
        
        // JavaScript / TypeScript
        let jsCode = "const handleAction = async () => { console.log('completed'); };"
        #expect(CodeDetector.detectLanguage(jsCode) == .javascript)
        
        let tsCode = "interface UserData { id: number; name: string; }"
        #expect(CodeDetector.detectLanguage(tsCode) == .javascript)
        
        // Python
        let pythonDef = "def calculate_dimensions(width, height):\n    return width * height"
        #expect(CodeDetector.detectLanguage(pythonDef) == .python)
        
        let pythonImport = "import sys\nimport os"
        #expect(CodeDetector.detectLanguage(pythonImport) == .python)
        
        let pythonClass = "class APIClient:\n    def __init__(self, endpoint):\n        self.endpoint = endpoint"
        #expect(CodeDetector.detectLanguage(pythonClass) == .python)
        
        // HTML / XML
        let htmlCode = "<div class=\"container\"><p>Sample text</p></div>"
        #expect(CodeDetector.detectLanguage(htmlCode) == .html)
        
        let xmlCode = "<?xml version=\"1.0\"?><settings><enabled>true</enabled></settings>"
        #expect(CodeDetector.detectLanguage(xmlCode) == .html)
        
        // CSS
        let cssCode = ".card-title { color: #222222; font-size: 18px; }"
        #expect(CodeDetector.detectLanguage(cssCode) == .css)
        
        // JSON
        let jsonCode = "{\"name\": \"Clip Hold\", \"count\": 42}"
        #expect(CodeDetector.detectLanguage(jsonCode) == .json)
        
        let jsonWithSpaces = """
        {
          "database" : {
            "host" : "localhost",
            "port" : 5432,
            "ssl" : true
          },
          "max_retries" : 3
        }
        """
        #expect(CodeDetector.detectLanguage(jsonWithSpaces) == .json)
        
        // YAML
        let yamlCode = """
        version: "3.8"
        services:
          app:
            image: node:18
        """
        #expect(CodeDetector.detectLanguage(yamlCode) == .yaml)
        
        // TOML
        let tomlCode = """
        [package]
        name = "clip-hold"
        version = "1.0.0"
        """
        #expect(CodeDetector.detectLanguage(tomlCode) == .toml)
        
        // Markdown
        let markdownDoc = """
        # Overview
        ## Details
        This is a feature summary.
        """
        #expect(CodeDetector.detectLanguage(markdownDoc) == .markdown)
        
        let markdownChangelog = """
        ## English
        ### Bug Fixes and Enhancements
        - **Settings**: Fixed an issue where the slider value was not saved properly.
        - **Sync**: Improved background synchronization reliability.
        """
        #expect(CodeDetector.detectLanguage(markdownChangelog) == .markdown)
        
        let markdownWithEmbeddedHtml = """
        # Documentation Header
        <p><strong>App Name</strong> is a menu bar utility for macOS.</p>
        ## Features
        - **Feature A**: Description
        <br>
        For details, check the website.
        """
        #expect(CodeDetector.detectLanguage(markdownWithEmbeddedHtml) == .markdown)
        
        // HTML
        let htmlSnippet = "<h5>Updates</h5><ul><li>Bug fixes and performance improvements.</li></ul>"
        #expect(CodeDetector.detectLanguage(htmlSnippet) == .html)
        
        // CSS
        let cssDoc = """
        .container {
            display: flex;
            justify-content: center;
            align-items: center;
        }
        """
        #expect(CodeDetector.detectLanguage(cssDoc) == .css)
        
        // GraphQL
        let gqlDoc = """
        query FetchUser($userId: ID!) {
          user(id: $userId) {
            name
          }
        }
        """
        #expect(CodeDetector.detectLanguage(gqlDoc) == .graphql)
        
        // Env
        let envDoc = """
        DATABASE_PORT=5432
        DATABASE_NAME=production_db
        """
        #expect(CodeDetector.detectLanguage(envDoc) == .env)
        
        // Rust
        let rustDoc = """
        fn init_engine() -> Result<(), EngineError> {
            println!("Initializing");
            Ok(())
        }
        """
        #expect(CodeDetector.detectLanguage(rustDoc) == .rust)
        
        let rustStruct = "pub struct AppContext {\n    pub is_ready: bool,\n}"
        #expect(CodeDetector.detectLanguage(rustStruct) == .rust)
        
        // Go
        let goDoc = """
        package service

        func Start() {
            println("Service started")
        }
        """
        #expect(CodeDetector.detectLanguage(goDoc) == .go)
        
        let goReceiver = "func (c *Client) FetchData() (*Response, error) {\n    return nil, nil\n}"
        #expect(CodeDetector.detectLanguage(goReceiver) == .go)
        
        // C / C++
        let cppDoc = """
        #include <string>

        int main() {
            return 0;
        }
        """
        #expect(CodeDetector.detectLanguage(cppDoc) == .cpp)
        
        let cppNamespace = "namespace Utilities {\n    void execute() {\n        auto val = nullptr;\n    }\n}"
        #expect(CodeDetector.detectLanguage(cppNamespace) == .cpp)
        
        // Java / Kotlin
        let javaDoc = """
        package com.example;

        public class Application {
            public static void main(String[] args) {}
        }
        """
        #expect(CodeDetector.detectLanguage(javaDoc) == .javaKotlin)
        
        let kotlinDoc = "fun renderComponent(title: String): Unit {\n    val len = title.length\n}"
        #expect(CodeDetector.detectLanguage(kotlinDoc) == .javaKotlin)
        
        // SQL
        let sqlCode = "SELECT * FROM accounts WHERE is_active = 1;"
        #expect(CodeDetector.detectLanguage(sqlCode) == .sql)
        
        // Shell
        let shellCode = "#!/bin/bash\necho 'Deploying system...'"
        #expect(CodeDetector.detectLanguage(shellCode) == .shell)
        
        // Markdownコードブロック指定
        let markdownSwift = "```swift\nlet count = 10\n```"
        #expect(CodeDetector.detectLanguage(markdownSwift) == .swift)
        
        let markdownYaml = "```yaml\nname: test\n```"
        #expect(CodeDetector.detectLanguage(markdownYaml) == .yaml)
        
        let markdownToml = "```toml\n[table]\na = 1\n```"
        #expect(CodeDetector.detectLanguage(markdownToml) == .toml)
        
        let markdownGql = "```graphql\nquery { id }\n```"
        #expect(CodeDetector.detectLanguage(markdownGql) == .graphql)
        
        let markdownRust = "```rust\nfn main() {}\n```"
        #expect(CodeDetector.detectLanguage(markdownRust) == .rust)
        
        let markdownGo = "```go\npackage main\n```"
        #expect(CodeDetector.detectLanguage(markdownGo) == .go)
        
        let markdownCpp = "```cpp\nint main() {}\n```"
        #expect(CodeDetector.detectLanguage(markdownCpp) == .cpp)
        
        // クラッシュレポート・診断ログ（.other）
        let crashLog = """
        -------------------------------------
        Translated Report (Full Report Below)
        -------------------------------------
        Process:             PreviewService [12345]
        Path:                /System/Library/Frameworks/...
        Identifier:          com.apple.PreviewService
        Version:             1.0 (100)
        Code Type:           ARM-64 (Native)
        """
        #expect(CodeDetector.isCode(crashLog))
        #expect(CodeDetector.detectLanguage(crashLog) == .other)
        
        // 自然言語（非コード）は nil
        #expect(CodeDetector.detectLanguage("これは通常のテキスト文章です。") == nil)
        #expect(CodeDetector.detectLanguage("This is a simple documentation sentence.") == nil)
        #expect(CodeDetector.detectLanguage("Update the project dependencies to the latest stable release.") == nil)
    }
    
    @Test("SwiftUIビュー構文およびモディファイア・マクロの判定")
    func testSwiftUIAndModifierDetection() {
        // ZStack とローカル定数宣言
        let zstackCode = """
        ZStack {
            let isLegacySystem = ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0))
        }
        """
        #expect(CodeDetector.detectLanguage(zstackCode) == .swift)
        
        // Combine sink とクロージャキャプチャ
        let combineCode = """
        .sink { [weak self] primary, secondary in
            self?.serviceController.dispatch(primary: primary, secondary: secondary)
        }
        """
        #expect(CodeDetector.detectLanguage(combineCode) == .swift)
        
        // SwiftUI モディファイアとクロージャブロック
        let commandsCode = """
        .commands {
            InspectorCommands()
        }
        """
        #expect(CodeDetector.detectLanguage(commandsCode) == .swift)
        
        let markdownStyleCode = """
        .markdownTextStyle {
            FontSize(.em(0.85))
        }
        """
        #expect(CodeDetector.detectLanguage(markdownStyleCode) == .swift)
        
        let paragraphCode = """
        .paragraph { element in
            element.label
        }
        """
        #expect(CodeDetector.detectLanguage(paragraphCode) == .swift)
        
        let strongCode = """
        .strong {
            FontWeight(.semibold)
        }
        """
        #expect(CodeDetector.detectLanguage(strongCode) == .swift)
        
        let textModifierCode = """
        .text {
            ForegroundColor(status.isActive ? .green : .secondary)
        }
        """
        #expect(CodeDetector.detectLanguage(textModifierCode) == .swift)
        
        let listItemCode = """
        .listItem { configuration in
            configuration.label
        }
        """
        #expect(CodeDetector.detectLanguage(listItemCode) == .swift)
        
        // SwiftUI Button
        let buttonCode = """
        Button {
            selectedOption = option
        } label: {
            if selectedOption == option {
                Image(systemName: "checkmark.circle.fill")
            }
        }
        """
        #expect(CodeDetector.detectLanguage(buttonCode) == .swift)
        
        // onMove モディファイア
        let onMoveCode = """
        .onMove { sourceOffsets, targetOffset in
            records.move(fromOffsets: sourceOffsets, toOffset: targetOffset)
        }
        """
        #expect(CodeDetector.detectLanguage(onMoveCode) == .swift)
        
        // アクセシビリティモディファイア
        let accessibilityCode = """
        .accessibilityLabel("履歴アイテム一覧")
        .accessibilityHint("クリックしてクリップボードにコピーします")
        """
        #expect(CodeDetector.detectLanguage(accessibilityCode) == .swift)
        
        // #Preview マクロ
        let previewCode1 = """
        #Preview {
            BadgeCardView(caption: "プレビュー用のサンプルデータ")
        }
        """
        #expect(CodeDetector.detectLanguage(previewCode1) == .swift)
        
        let previewCode2 = """
        #Preview {
            PreferenceSettingsContainer()
        }
        """
        #expect(CodeDetector.detectLanguage(previewCode2) == .swift)
        
        // SwiftUI Menu
        let menuCode = """
        Menu {
            ContextMenuItems()
        }
        """
        #expect(CodeDetector.detectLanguage(menuCode) == .swift)
        
        // didSet プロパティオブザーバ
        let didSetCode = """
        didSet {
            if isSyncingPaused {
                suspendSynchronization()
            }
        }
        """
        #expect(CodeDetector.detectLanguage(didSetCode) == .swift)
        
        // SwiftUI HStack
        let hstackCode = """
        HStack {
            Label("進捗", systemImage: "clock")
            Spacer()
        }
        """
        #expect(CodeDetector.detectLanguage(hstackCode) == .swift)
    }
    
    @Test("CSSプロパティおよびスタイルの判定")
    func testCSSPropertyAndStyleDetection() {
        // light-dark を含むクラスセレクタブロック
        let cssBlock1 = """
        .sidebar-panel {
            background: light-dark(#f0f0f0, #1e1e1e);
            padding: 1.25rem;
        }
        """
        #expect(CodeDetector.detectLanguage(cssBlock1) == .css)
        
        // 単体のインラインプロパティ宣言
        let inlineProperties = "width: 100%; height: auto; border-radius: 24px; background-color: #ffffff;"
        #expect(CodeDetector.detectLanguage(inlineProperties) == .css)
        
        // CSSカスタムプロパティ
        let customProps = """
        --theme-primary-height: 44px;
        background-color: var(--theme-color-surface-elevated);
        """
        #expect(CodeDetector.detectLanguage(customProps) == .css)
        
        let borderBottomColor = "border-bottom-color: light-dark(#E8ECF8, #181C28);"
        #expect(CodeDetector.detectLanguage(borderBottomColor) == .css)
        
        let htmlElementRule = "html { scroll-padding-top: 5rem; }"
        #expect(CodeDetector.detectLanguage(htmlElementRule) == .css)
        
        let importantMargin = "margin: 0.75rem 0px !important;"
        #expect(CodeDetector.detectLanguage(importantMargin) == .css)
        
        // コメント付きCSS
        let commentedCSS = """
        /* カードコンポーネントの基本スタイル */
        .card-container div ul {
            list-style: none;
            margin: 0;
        }
        """
        #expect(CodeDetector.detectLanguage(commentedCSS) == .css)
    }
    
    @Test("HTMLタグ構造の判定")
    func testHTMLTagStructureDetection() {
        let metaSpanHTML = "<meta charset='utf-8'><span style=\"color: rgb(240, 240, 240);\">タイトルテキスト</span>"
        #expect(CodeDetector.detectLanguage(metaSpanHTML) == .html)
        
        let linkTagHTML = "<link rel=\"stylesheet\" href=\"/assets/main.css\">"
        #expect(CodeDetector.detectLanguage(linkTagHTML) == .html)
        
        let titleTagHTML = "<title>ダッシュボード概要 - Clip Hold</title>"
        #expect(CodeDetector.detectLanguage(titleTagHTML) == .html)
    }
    
    @Test("Swiftのimport文およびファイル名コメントの判定")
    func testSwiftImportAndFileCommentDetection() {
        // import SwiftUI から始まるビューコード
        let swiftImportCode = """
        import SwiftUI

        struct ProfileCardView: View {
            var body: some View {
                Text("ユーザープロフィール")
            }
        }
        """
        #expect(CodeDetector.detectLanguage(swiftImportCode) == .swift)
        
        // .swift ファイル名コメントから始まるコード
        let swiftCommentCode1 = """
        // SettingsManager.swift
        // Clip Hold

        import Foundation

        final class SettingsManager {
            static let shared = SettingsManager()
            private init() {}
        }
        """
        #expect(CodeDetector.detectLanguage(swiftCommentCode1) == .swift)
        
        let swiftCommentCode2 = """
        // CustomActionButton.swift
        import SwiftUI

        struct CustomActionButton: View {
            let title: String
            var body: some View {
                Button(title) {}
            }
        }
        """
        #expect(CodeDetector.detectLanguage(swiftCommentCode2) == .swift)
    }
    
    @Test("見出しレベル4から始まるMarkdown文書およびコードキーワードを含むMarkdownの判定")
    func testMarkdownHeadingAndCodeKeywordsDisambiguation() {
        // 見出しレベル4（####）から始まるMarkdown文書
        let markdownH4Doc = """
        #### セキュリティとプライバシー設定

        このセクションでは、アプリケーションのアクセス権限とプライバシーについて説明します。

        - アクセシビリティ権限
        - クリップボード監視の停止
        - 除外アプリケーションの登録
        """
        #expect(CodeDetector.detectLanguage(markdownH4Doc) == .markdown)
        
        // コードキーワード（import, self等）を文章中に含むMarkdown文書
        let markdownWithKeywords = """
        #### セットアップと初期化

        以下の手順で初期化を実行してください。

        1. `import config` 設定ファイルを確認します
        2. `self.initialize()` を呼び出します
        3. 実行ログを確認します
        """
        #expect(CodeDetector.detectLanguage(markdownWithKeywords) == .markdown)
    }
    
    @Test("Pythonコードの判定（def、class、from...import等）")
    func testPythonLanguageDetection() {
        let pythonCode1 = """
        import os
        import sys

        def process_dataset(path: str) -> dict:
            if not os.path.exists(path):
                return {}
            with open(path, 'r') as f:
                content = f.read()
            return {"data": content}

        if __name__ == '__main__':
            result = process_dataset("data.json")
            print(result)
        """
        #expect(CodeDetector.detectLanguage(pythonCode1) == .python)
        
        let pythonCode2 = """
        from typing import Optional, List
        import json

        class ItemRepository:
            def __init__(self, initial_items: List[str]):
                self.items = initial_items
        """
        #expect(CodeDetector.detectLanguage(pythonCode2) == .python)
    }
    
    @Test("Swift各種フレームワークおよび拡張構文の判定")
    func testSwiftFrameworkAndSyntaxDetection() {
        let notifCode = "import UserNotifications\nlet center = UNUserNotificationCenter.current()"
        #expect(CodeDetector.detectLanguage(notifCode) == .swift)
        
        let smCode = "import ServiceManagement\nlet service = SMAppService.mainApp"
        #expect(CodeDetector.detectLanguage(smCode) == .swift)
        
        let publishedArray = "@Published var activeIdentifiers: [String] = []"
        #expect(CodeDetector.detectLanguage(publishedArray) == .swift)
        
        let focusState = "@FocusState private var isFieldFocused: Bool"
        #expect(CodeDetector.detectLanguage(focusState) == .swift)
        
        let staticLet = "static let defaultTimeoutInterval: TimeInterval = 30.0"
        #expect(CodeDetector.detectLanguage(staticLet) == .swift)
        
        let initUserDefaults = """
        init() {
            let savedValue = UserDefaults.standard.integer(forKey: "maxItems")
            self.maxItems = savedValue
        }
        """
        #expect(CodeDetector.detectLanguage(initUserDefaults) == .swift)
        
        let selectionDisabled = "Text(\"固定ラベル\").selectionDisabled(true)"
        #expect(CodeDetector.detectLanguage(selectionDisabled) == .swift)
    }
    
    @Test("HTMLコメントおよびインラインスタイルの判定")
    func testHTMLCommentAndInlineStyleDetection() {
        let htmlComment = "<!-- wp:spacer {\"height\":\"32px\"} --> <div style=\"height:32px\" aria-hidden=\"true\"></div>"
        #expect(CodeDetector.detectLanguage(htmlComment) == .html)
        
        let spanStyle = "<span style=\"font-weight: bold; color: rgb(0, 255, 0); font-size: 24px;\">ハイライト</span>"
        #expect(CodeDetector.detectLanguage(spanStyle) == .html)
    }
    
    @Test("AIからの応答やコード埋め込みMarkdownドキュメントの判定")
    func testAIMarkdownResponseWithEmbeddedCodeBlocks() {
        let aiMarkdownDoc = """
        # 音声通知機能の設計ガイドライン

        ## 1. 概要
        アプリのイベント発生時に再生する通知音の設計方針です。

        ## 2. 実装コード例
        以下のスクリプトを実行してオーディオファイルを生成します。

        ```python
        import mido
        from mido import Message, MidiFile

        def generate_tone(filename: str):
            mid = MidiFile()
            mid.save(filename)

        if __name__ == '__main__':
            generate_tone('test.mid')
        ```

        ## 3. 次のステップ
        生成されたファイルをリソースバンドルに追加してください。
        """
        #expect(CodeDetector.detectLanguage(aiMarkdownDoc) == .markdown)
    }
    
    @Test("Swiftのクラス継承・プロトコル適合宣言の判定")
    func testSwiftClassDeclaration() {
        let swiftClass = "class CustomPanelController: NSWindowController, NSWindowDelegate, ObservableObject {"
        #expect(CodeDetector.detectLanguage(swiftClass) == .swift)
        
        let finalSwiftClass = "final class AppStateManager: NSObject, ObservableObject {"
        #expect(CodeDetector.detectLanguage(finalSwiftClass) == .swift)
    }
    
    @Test("Swiftのenum型定義・async/throws関数・複数インポート・@testableの判定")
    func testSwiftEnumAndAsyncFunctionDetection() {
        let enumCode = "enum DisplayMode: Int, CaseIterable, Identifiable, Equatable { case standard = 0 }"
        #expect(CodeDetector.detectLanguage(enumCode) == .swift)
        
        let asyncFunc = "private func syncDatabase(_ id: String) async throws -> Bool { return true }"
        #expect(CodeDetector.detectLanguage(asyncFunc) == .swift)
        
        let multipleImports = "import SwiftUI import AppKit import UniformTypeIdentifiers"
        #expect(CodeDetector.detectLanguage(multipleImports) == .swift)
        
        let testableImport = "import XCTest import Foundation @testable import Clip_Hold"
        #expect(CodeDetector.detectLanguage(testableImport) == .swift)
    }
    
    @Test("JavaScriptのブラウザAPIおよびAppKit windowメソッドとの区別")
    func testJavaScriptBrowserApiDetection() {
        let jsEventListener = "window.addEventListener('load', function() { console.log('ready'); });"
        #expect(CodeDetector.detectLanguage(jsEventListener) == .javascript)
        
        let appKitWindow = "window.setFrameAutosaveName(\"StandardPhraseWindow\")\nwindow.center()"
        #expect(CodeDetector.detectLanguage(appKitWindow) != .javascript)
    }
    
    @Test("HTML属性やSDPプロトコルテキストのTOML誤判定防止")
    func testTOMLAttributeExclusion() {
        let htmlAttributes = "data-lang=\"ja\"\ndata-loading=\"lazy\""
        #expect(CodeDetector.detectLanguage(htmlAttributes) != .toml)
    }
    
    @Test("単語単体や通常英文・ログ文章がコードと判定されないことの検証")
    func testSingleWordsAndSentencesNonCodeDetection() {
        #expect(CodeDetector.detectLanguage("KeyboardShortcuts") == nil)
        #expect(CodeDetector.detectLanguage("DispatchQueue") == nil)
        #expect(CodeDetector.detectLanguage("UserDefaults") == nil)
        #expect(CodeDetector.detectLanguage("Update the KeyboardShortcuts package") == nil)
        #expect(CodeDetector.detectLanguage("KeyboardShortcuts: Shortcut registered successfully.") == nil)
        #expect(CodeDetector.detectLanguage("DEBUG: init() - savedMaxFileSizeToSave: 1048576, currentLimit: 5242880") == nil)
        
        // 正当なSwiftコードは正しく判定されること
        let validAsync = "DispatchQueue.main.async { updateUI() }"
        #expect(CodeDetector.detectLanguage(validAsync) == .swift)
        
        let validDefaults = "UserDefaults.standard.set(true, forKey: \"key\")"
        #expect(CodeDetector.detectLanguage(validDefaults) == .swift)
        
        let validShortcut = "KeyboardShortcuts.onKeyDown(for: .toggle) { show() }"
        #expect(CodeDetector.detectLanguage(validShortcut) == .swift)
        
        let validLocalized = "String(localized: \"Hello\")"
        #expect(CodeDetector.detectLanguage(validLocalized) == .swift)
        
        let validInit = "init() {\n    let val = UserDefaults.standard.integer(forKey: \"k\")\n    self.count = val\n}"
        #expect(CodeDetector.detectLanguage(validInit) == .swift)
    }
    
    @Test("太字セクションや埋め込みコードブロックを持つAI応答ドキュメントのMarkdown判定")
    func testAIMarkdownWithNumberedBoldSectionsAndCodeBlocks() {
        let aiMarkdownDoc = """
        はい、承知いたしました。様々な言語のコードブロックを以下に示します。それぞれのコードブロックには簡単な説明を添えます。

        **1. Python**

        ```python
        def greet(name):
          print(f"こんにちは、{name}さん！")

        greet("太郎")
        ```

        *   **説明:** 簡単な挨拶メッセージを表示するPython関数です。

        **2. JavaScript**

        ```javascript
        function add(a, b) {
          return a + b;
        }
        ```
        """
        #expect(CodeDetector.detectLanguage(aiMarkdownDoc) == .markdown)
    }
    
    @Test("多言語の会話文・プロンプトから始まるテキストの非コード判定")
    func testMultilingualLeadingConversationNonCodeDetection() {
        // 日本語
        let jaPrompt = """
        承知いたしました。次はユーザー一覧セクションのスタイルに合わせて画面を調整してください。参考となるビューの構造は次の通りです。
        import SwiftUI
        struct UserListView: View {
            var body: some View {
                Text("User List")
            }
        }
        """
        #expect(CodeDetector.detectLanguage(jaPrompt) == nil)
        
        let jaSentence = "現在macOS向けの環境設定画面を設計しています。通知設定セクションのレイアウト改善を行いたいと思います。"
        #expect(CodeDetector.detectLanguage(jaSentence) == nil)
        
        // 英語
        let enPrompt = """
        Sure, here is the code you requested for the user list view:
        import SwiftUI
        struct UserListView: View {
            var body: some View {
                Text("User List")
            }
        }
        """
        #expect(CodeDetector.detectLanguage(enPrompt) == nil)
        
        let enSentence = "I am currently building a macOS app. Please check the following implementation:"
        #expect(CodeDetector.detectLanguage(enSentence) == nil)
        
        // ドイツ語
        let dePrompt = """
        Hier ist der Code für die Einstellungen, den Sie angefordert haben:
        import SwiftUI
        struct SettingsView: View {}
        """
        #expect(CodeDetector.detectLanguage(dePrompt) == nil)
        
        // フランス語
        let frPrompt = """
        Voici le code pour la vue de profil:
        import SwiftUI
        struct ProfileView: View {}
        """
        #expect(CodeDetector.detectLanguage(frPrompt) == nil)
        
        // スペイン語
        let esPrompt = """
        Aquí está el código que me pediste:
        import SwiftUI
        struct MyView: View {}
        """
        #expect(CodeDetector.detectLanguage(esPrompt) == nil)
    }
    
    @Test("コンパイルエラーログおよびビルド出力の非コード判定")
    func testCompilerErrorLogNonCodeDetection() {
        let errorLog1 = "/Users/example/Projects/SampleApp/MainView.swift:12:4: error: Cannot find 'SampleModule' in scope\nimport SampleModule\n       ^"
        #expect(CodeDetector.detectLanguage(errorLog1) == nil)
        
        let errorLog2 = "/Users/example/Projects/SampleApp/Calculator.swift:45:10: error: Binary operator '+' cannot be applied to operands of type 'Int' and 'String'"
        #expect(CodeDetector.detectLanguage(errorLog2) == nil)
    }
    
    @Test("ハードウェアデバイス情報・lspciログの非YAML判定")
    func testLspciHardwareLogNonCodeDetection() {
        let lspciLog = """
        00:02.0 Display controller [0300]: Example Tech Graphics Device [1234:5678]
                Subsystem: Example Tech Device [1234:9abc]
                Kernel driver in use: sample-driver
                Kernel modules: samplefb, samplemod
        """
        #expect(CodeDetector.detectLanguage(lspciLog) != .yaml)
    }
    
    @Test("Swift Package Managerの依存関係構文の判定")
    func testSPMPackageDeclarationDetection() {
        let spmDependencies = """
        dependencies: [
            .package(url: "https://github.com/apple/example-package.git", from: "1.0.0")
        ]
        """
        #expect(CodeDetector.detectLanguage(spmDependencies) == .swift)
    }
    
    @Test("Markdown引用およびコールアウト構文の判定")
    func testMarkdownBlockquoteDetection() {
        let calloutDoc = """
        ## Release Notes
        > [!IMPORTANT]
        > Please read the migration instructions before updating.
        """
        #expect(CodeDetector.detectLanguage(calloutDoc) == .markdown)
        
        let quoteDoc = """
        > **Note**\\
        > Configuration parameters are automatically loaded from disk.
        """
        #expect(CodeDetector.detectLanguage(quoteDoc) == .markdown)
    }
    
    @Test("Go言語レシーバーメソッドおよびパッケージ構文の判定")
    func testGoReceiverMethodDetection() {
        let goCode = """
        package server

        import "net/http"

        func (s *HTTPServer) Start() error {
            return http.ListenAndServe(":8080", nil)
        }
        """
        #expect(CodeDetector.detectLanguage(goCode) == .go)
        
        // Swiftの非同期関数はGoではなくSwiftと判定されること
        let swiftAsyncFunc = """
        private func copyItemToClipboard(_ item: ItemModel) async {
            let manager = SharedManager.default
        }
        """
        #expect(CodeDetector.detectLanguage(swiftAsyncFunc) == .swift)
    }
    
    @Test("Markdownリンク・画像リンク・バッジ構文の判定")
    func testMarkdownLinksAndImagesDetection() {
        // 画像リンクと見出しを含むドキュメント
        let imageDoc = """
        ## Architecture Overview
        ![System Diagram](https://example.com/assets/diagram.png)
        Detailed explanation of each component is described below.
        """
        #expect(CodeDetector.isCode(imageDoc))
        #expect(CodeDetector.detectLanguage(imageDoc) == .markdown)
        
        // 相対パスの画像リンクとリストを含むドキュメント
        let localImageDoc = """
        ### User Interface
        ![App Screenshot](./assets/screenshots/main_window.png)
        - Fast search indexing
        - Multi-language code highlighter
        """
        #expect(CodeDetector.isCode(localImageDoc))
        #expect(CodeDetector.detectLanguage(localImageDoc) == .markdown)
        
        // リンク付きバッジ画像
        let badgeDoc = """
        # Clip Hold
        [![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://example.com/actions)
        [![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://example.com/license)
        
        A powerful clipboard manager for macOS.
        """
        #expect(CodeDetector.isCode(badgeDoc))
        #expect(CodeDetector.detectLanguage(badgeDoc) == .markdown)
        
        // 参照形式リンク
        let refLinkDoc = """
        # Documentation
        Please consult the [User Guide][1] and [API Reference][2] for details.
        
        [1]: https://example.com/guide
        [2]: https://example.com/api
        """
        #expect(CodeDetector.isCode(refLinkDoc))
        #expect(CodeDetector.detectLanguage(refLinkDoc) == .markdown)
        
        // リンクリスト
        let linkList = """
        - [Official Documentation](https://example.com/docs)
        - [GitHub Repository](https://github.com/example/repo)
        - [Changelog Notes](https://example.com/releases)
        """
        #expect(CodeDetector.isCode(linkList))
        #expect(CodeDetector.detectLanguage(linkList) == .markdown)
        
        // 1行のMarkdownリンク単体
        let singleLink = "[Apple Developer Documentation](https://developer.apple.com)"
        #expect(CodeDetector.isCode(singleLink))
        #expect(CodeDetector.detectLanguage(singleLink) == .markdown)
        
        // 1行の画像リンク単体
        let singleImage = "![Application Icon](https://example.com/assets/icon.png)"
        #expect(CodeDetector.isCode(singleImage))
        #expect(CodeDetector.detectLanguage(singleImage) == .markdown)
        
        // 1行のリンク付きバッジ単体
        let singleBadge = "[![GitHub Release](https://img.shields.io/github/v/release/example/repo)](https://github.com/example/repo/releases)"
        #expect(CodeDetector.isCode(singleBadge))
        #expect(CodeDetector.detectLanguage(singleBadge) == .markdown)
    }
}

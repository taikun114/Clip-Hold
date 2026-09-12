import Testing
import Foundation
@testable import Clip_Hold

struct HashCalculatorTests {
    
    @Test
    func testCalculateImageDataHash() {
        let sampleData1 = "ClipHoldTestData1".data(using: .utf8)!
        let sampleData2 = "ClipHoldTestData2".data(using: .utf8)!
        
        let hash1A = HashCalculator.calculateImageDataHash(sampleData1)
        let hash1B = HashCalculator.calculateImageDataHash(sampleData1)
        let hash2 = HashCalculator.calculateImageDataHash(sampleData2)
        
        // 同一データからは常に同一のハッシュが生成されること
        #expect(hash1A == hash1B)
        #expect(!hash1A.isEmpty)
        
        // 異なるデータからは異なるハッシュが生成されること
        #expect(hash1A != hash2)
        
        // SHA-256は64文字の16進数文字列
        #expect(hash1A.count == 64)
    }
    
    @Test
    func testCalculateFileHashForTemporaryFile() throws {
        // 一時ファイルを作成してハッシュ計算を検証
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent("ClipHoldHashTest_\(UUID().uuidString).txt")
        let content = "Clip Hold File Hash Test Content"
        try content.write(to: tempFileURL, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let fileHash = HashCalculator.calculateFileHash(at: tempFileURL)
        #expect(fileHash != nil)
        #expect(fileHash?.count == 64)
        
        // 同じファイルに対して再度計算しても一致すること
        let fileHashAgain = HashCalculator.calculateFileHash(at: tempFileURL)
        #expect(fileHash == fileHashAgain)
    }
    
    @Test
    func testCalculateFileHashForNonExistentFileAndDirectory() {
        // 存在しないファイルの場合はnilを返すこと
        let nonExistentURL = URL(fileURLWithPath: "/path/to/non/existent/file.txt")
        #expect(HashCalculator.calculateFileHash(at: nonExistentURL) == nil)
        
        // ディレクトリの場合はnilを返すこと（重複除外の仕様）
        let tempDir = FileManager.default.temporaryDirectory
        #expect(HashCalculator.calculateFileHash(at: tempDir) == nil)
    }
}

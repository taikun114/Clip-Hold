import Foundation
import CryptoKit

class HashCalculator {
    // ファイルのSHA256ハッシュを計算する
    static func calculateFileHash(at url: URL) -> String? {
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }
            
            let hasher = SHA256()
            var hash = hasher
            
            while autoreleasepool(invoking: {
                let chunk = fileHandle.readData(ofLength: 8192)
                if chunk.isEmpty {
                    return false // 終了
                }
                hash.update(data: chunk)
                return true // 続行
            }) { }
            
            let digest = hash.finalize()
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        } catch let error {
            print("HashCalculator: Error calculating hash for file at \(url.path): \(error.localizedDescription)")
            return nil
        }
    }
    
    // 画像データのSHA256ハッシュを計算する
    static func calculateImageDataHash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
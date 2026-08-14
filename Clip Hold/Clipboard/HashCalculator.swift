import Foundation
import CryptoKit

class HashCalculator {
    static func calculateFileHash(at url: URL, fileSize: Int64? = nil, progressHandler: ((Double) -> Void)? = nil, isCancelled: (() -> Bool)? = nil) -> String? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }
        
        if isDirectory.boolValue {
            // ディレクトリの場合はハッシュ計算を行わず、nilを返す（同じ名前のフォルダが重複判定されないようにするため）
            return nil
        }
        
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }
            
            let hasher = SHA256()
            var hash = hasher
            var bytesRead: Int64 = 0
            let size = max(fileSize ?? 1, 1)
            
            while autoreleasepool(invoking: {
                if isCancelled?() == true { return false }
                
                let chunk = fileHandle.readData(ofLength: 32768) // 32KB chunks
                if chunk.isEmpty {
                    return false // 終了
                }
                hash.update(data: chunk)
                
                bytesRead += Int64(chunk.count)
                if let progressHandler = progressHandler {
                    let progress = Double(bytesRead) / Double(size)
                    progressHandler(min(progress, 1.0))
                }
                
                return true // 続行
            }) { }
            
            if isCancelled?() == true { return nil }
            
            let digest = hash.finalize()
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        } catch let error {
#if DEBUG
            print("HashCalculator: Error calculating hash for file at \(url.path): \(error.localizedDescription)")
#else
            print("HashCalculator: Error calculating file hash: \(error.localizedDescription)")
#endif
            return nil
        }
    }
    
    // 画像データのSHA256ハッシュを計算する
    static func calculateImageDataHash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
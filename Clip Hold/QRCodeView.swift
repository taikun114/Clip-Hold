import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit
import UniformTypeIdentifiers

struct QRCodeView: View {
    let text: String
    
    @State private var showingSavePanel: Bool = false
    @State private var imageToSave: NSImage?
    @State private var suggestedFileName: String = "QRCode.png"
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("QRコード")
                .font(.title)
                .fontWeight(.bold)

            if let qrCodeImage = generateQRCode(from: text) {
                Image(nsImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .border(Color.gray, width: 1)
                    .layoutPriority(1) // QRコード画像に高いレイアウト優先度を設定
                    .contextMenu {
                        Button("画像をコピー") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.writeObjects([qrCodeImage])
                        }
                        
                        Button("画像を保存...") {
                            self.imageToSave = qrCodeImage
                            self.suggestedFileName = createSafeFileName(from: text)
                            self.showingSavePanel = true
                        }
                    }
            } else {
                VStack {
                    Spacer()
                    Text("QRコードの生成に失敗しました。")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    
                    Text("入力された情報が長すぎるか、無効な文字が含まれている可能性があります。")
                        .font(.body)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .border(Color.gray, width: 1)
                .layoutPriority(1) // エラーメッセージブロックにも高いレイアウト優先度を設定
            }
            
            ScrollView {
                Text(text)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity) // 残りの余白を埋めるように設定
            
            HStack {
                Spacer()
                Button("閉じる") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 350, height: 500)
        .fileExporter(
            isPresented: $showingSavePanel,
            document: ImageDocument(pngData: imageToSave?.pngData() ?? Data()),
            contentType: .png,
            defaultFilename: suggestedFileName
        ) { result in
            switch result {
            case .success(let url):
                print("Image saved successfully to: \(url.path)")
            case .failure(let error):
                print("Error saving image: \(error.localizedDescription)")
            }
        }
    }
    
    func generateQRCode(from string: String) -> NSImage? {
        guard let data = string.data(using: .utf8) else {
            print("Error: Could not convert string to UTF-8 data.")
            return nil
        }
        
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        
        guard let outputImage = filter.outputImage else {
            print("Error: Could not generate CIImage from QR code filter.")
            return nil
        }
        
        let scale = 10.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)
        
        let rep = NSCIImageRep(ciImage: scaledImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }

    private func createSafeFileName(from text: String) -> String {
        var fileName = text.components(separatedBy: .newlines).first ?? "QRCode"
        
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        fileName = fileName.components(separatedBy: invalidCharacters).joined(separator: "_")
        
        if fileName.isEmpty {
            fileName = "QRCode"
        }
        
        return fileName + ".png"
    }
    
    @Environment(\.dismiss) var dismiss
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}

// ImageDocumentがSendableに準拠するために、NSImageではなくDataを保持するように変更します。
// これにより、Swift 6のSendableチェックに根本的に準拠します。
struct ImageDocument: FileDocument {
    var pngData: Data // NSImageの代わりにPNGデータを保持

    static var readableContentTypes: [UTType] { [.png, .jpeg, .tiff] }
    static var writableContentTypes: [UTType] { [.png] }
    
    // PNGデータを受け取るイニシャライザ
    init(pngData: Data) {
        self.pngData = pngData
    }

    // FileDocumentの要件を満たすためのイニシャライザ（今回は使用しないためfatalError）
    init(configuration: ReadConfiguration) throws {
        fatalError("Reading not implemented for ImageDocument")
    }
    
    // ファイルラッパーを返すメソッド。保持しているPNGデータを直接使用します。
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: pngData)
    }
}

#Preview {
    QRCodeView(text: "これは、プレビューに表示されるQRコードのテストに使用される文字列です。長い文章でも正しく表示されることを確認するために、ここのプレビュー文字列も長めに設定されています。これにより、長い文字列を使ってQRコードを生成した時でも正しく表示されるかどうかを確認するのにとても役に立ちます。果たして、プレビューには正しく表示されているでしょうか？")
}

import SwiftUI
import CoreImage.CIFilterBuiltins

public struct WiFiQRCodeModal: View {
    public let storeName: String
    public let password: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    public init(storeName: String, password: String) {
        self.storeName = storeName
        self.password = password
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text(storeName)
                        .font(.title2.weight(.bold))
                    Text("Wi-Fi SSID: LouisaCoffee")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let qrImage = generateQRCode(for: "WIFI:S:LouisaCoffee;T:WPA;P:\(password);;") {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                }

                VStack(spacing: 8) {
                    Text("密碼：\(password)")
                        .font(.title3.monospaced().weight(.semibold))

                    Button {
                        UIPasteboard.general.string = password
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        Label(copied ? "已複製！" : "複製此密碼", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(copied ? .green : .accentColor)
                }

                Text("💡 若因 iOS 權限限制無法自動連線，或想分享給同行朋友，直接使用相機掃描上方 QR Code 即可一鍵加入 LouisaCoffee！")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Wi-Fi QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }

    private func generateQRCode(for text: String) -> UIImage? {
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

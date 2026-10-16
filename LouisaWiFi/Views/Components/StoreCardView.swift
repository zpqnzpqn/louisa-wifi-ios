import SwiftUI
import CoreLocation

public struct StoreCardView: View {
    public let store: Store
    public let userLocation: CLLocation?
    public let isNearest: Bool
    public let onConnect: (String?) -> Void

    @ObservedObject private var connector = WiFiConnector.shared
    @ObservedObject private var cache = LearnedStoreCache.shared
    @State private var showingQRModal = false
    @State private var selectedPasswordForQR: String = ""
    @State private var copiedPassword: String? = nil

    public init(store: Store, userLocation: CLLocation?, isNearest: Bool = false, onConnect: @escaping (String?) -> Void) {
        self.store = store
        self.userLocation = userLocation
        self.isNearest = isNearest
        self.onConnect = onConnect
    }

    private var isCurrentlyConnected: Bool {
        if case .connected(let connectedStore, _) = connector.status {
            return connectedStore == store.name
        }
        return false
    }

    private var isConnectingThisStore: Bool {
        if case .connecting(let connectingStore, _) = connector.status {
            return connectingStore == store.name
        }
        return false
    }

    private var primaryPassword: String {
        cache.lastVerifiedPassword(forStore: store.name) ?? store.passwords.first ?? ""
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Name & Distance / Status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(store.name)
                            .font(isNearest ? .title3.weight(.bold) : .headline)
                            .foregroundStyle(.primary)

                        if isCurrentlyConnected {
                            Label("已連線", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        } else if isNearest {
                            Text("離你最近")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }

                    Text(store.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if let meters = store.distance(from: userLocation) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.formattedDistance(from: userLocation))
                            .font(.callout.monospacedDigit().weight(.semibold))
                            .foregroundStyle(isNearest ? .orange : .secondary)
                        if meters < 100 {
                            Text("就在這裡")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            // Candidate Passwords List
            VStack(alignment: .leading, spacing: 6) {
                Text("候選密碼（點擊指定連線）：")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.passwords, id: \.self) { pwd in
                            let isLearned = (cache.lastVerifiedPassword(forStore: store.name) == pwd)
                            Button {
                                onConnect(pwd)
                            } label: {
                                HStack(spacing: 4) {
                                    if isLearned {
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    }
                                    Text(pwd)
                                        .font(.subheadline.monospaced().weight(isLearned ? .bold : .regular))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isLearned ? Color.orange.opacity(0.18) : Color(.systemGray6))
                                .foregroundStyle(isLearned ? Color.orange : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isLearned ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = pwd
                                    copiedPassword = pwd
                                } label: {
                                    Label("複製密碼", systemImage: "doc.on.doc")
                                }

                                Button {
                                    selectedPasswordForQR = pwd
                                    showingQRModal = true
                                } label: {
                                    Label("顯示 Wi-Fi QR Code", systemImage: "qrcode")
                                }
                            }
                        }
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 10) {
                Button {
                    onConnect(nil) // Uses best candidate automatically
                } label: {
                    HStack {
                        if isConnectingThisStore {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 4)
                            Text("連線中...")
                        } else if isCurrentlyConnected {
                            Image(systemName: "checkmark")
                            Text("已連上此門市")
                        } else {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("一鍵連上此門市")
                        }
                    }
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isCurrentlyConnected ? Color.green : Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isConnectingThisStore)

                // QR Code Quick Access Button
                Button {
                    selectedPasswordForQR = primaryPassword
                    showingQRModal = true
                } label: {
                    Image(systemName: "qrcode")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .sheet(isPresented: $showingQRModal) {
                    WiFiQRCodeModal(storeName: store.name, password: selectedPasswordForQR)
                }

                // Apple Maps Navigation
                if let loc = store.location {
                    Button {
                        let url = URL(string: "http://maps.apple.com/?daddr=\(loc.coordinate.latitude),\(loc.coordinate.longitude)")!
                        UIApplication.shared.open(url)
                    } label: {
                        Image(systemName: "map")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
        )
    }
}

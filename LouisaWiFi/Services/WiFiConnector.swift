import Foundation
import NetworkExtension
import SystemConfiguration.CaptiveNetwork
import Combine
import os

public enum ConnectionStatus: Equatable {
    case idle
    case connecting(storeName: String, password: String)
    case connected(storeName: String, bssid: String?)
    case failed(reason: String)

    public var isConnecting: Bool {
        if case .connecting = self { return true }
        return false
    }

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var displayText: String {
        switch self {
        case .idle:
            return "未連線至 LouisaCoffee"
        case .connecting(let storeName, _):
            return "正在嘗試連線：\(storeName)..."
        case .connected(let storeName, let bssid):
            if let bssid {
                return "已連上：\(storeName) (\(bssid))"
            }
            return "已連上：\(storeName)"
        case .failed(let reason):
            return "連線失敗：\(reason)"
        }
    }
}

@MainActor
public final class WiFiConnector: ObservableObject {
    public static let shared = WiFiConnector()
    public static let louisaSSID = "LouisaCoffee"

    @Published public private(set) var status: ConnectionStatus = .idle
    @Published public private(set) var currentSSID: String?
    @Published public private(set) var currentBSSID: String?
    @Published public private(set) var isOnline: Bool = false

    public var isConnected: Bool {
        status.isConnected
    }

    private let logger = Logger(subsystem: "io.github.zpqnzpqn.LouisaWiFi", category: "wifi-connector")

    private init() {
        Task {
            await refreshCurrentNetworkState()
        }
    }

    /// Connect to a store using a specific password or the best candidate
    public func connect(to store: Store, password: String? = nil) async -> Bool {
        // 1. Determine candidate password
        let chosenPassword: String
        if let password {
            chosenPassword = password
        } else if let learned = LearnedStoreCache.shared.lastVerifiedPassword(forStore: store.name) {
            chosenPassword = learned
        } else if let first = store.passwords.first {
            chosenPassword = first
        } else {
            self.status = .failed(reason: "無可用密碼候選")
            return false
        }

        self.status = .connecting(storeName: store.name, password: chosenPassword)

        #if targetEnvironment(simulator)
        // Simulator Mocking: Cannot manipulate real Wi-Fi hardware
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        self.currentSSID = Self.louisaSSID
        self.currentBSSID = "00:11:22:33:44:55"
        self.isOnline = true
        self.status = .connected(storeName: store.name, bssid: self.currentBSSID)
        LearnedStoreCache.shared.remember(bssid: self.currentBSSID, store: store.name, password: chosenPassword)
        UsageTracker.shared.startSession(store: store.name)
        return true
        #else

        let configuration = NEHotspotConfiguration(ssid: Self.louisaSSID, passphrase: chosenPassword, isWEP: false)
        configuration.joinOnce = false // Keep network registered in iOS

        return await withCheckedContinuation { continuation in
            NEHotspotConfigurationManager.shared.apply(configuration) { [weak self] error in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                Task { @MainActor in
                    if let error = error as NSError? {
                        let reason = self.mapHotspotError(error)
                        self.logger.error("Hotspot apply error: \(error.localizedDescription)")
                        self.status = .failed(reason: reason)
                        continuation.resume(returning: false)
                        return
                    }

                    // System accepted configuration. Now verify actual connectivity.
                    // Wait a moment for DHCP association
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await self.refreshCurrentNetworkState()

                    // Check if captive portal/internet is reachable
                    let online = await self.checkOnline()
                    self.isOnline = online

                    // Fetch current BSSID if available
                    let bssid = self.currentBSSID
                    LearnedStoreCache.shared.remember(bssid: bssid, store: store.name, password: chosenPassword)
                    UsageTracker.shared.startSession(store: store.name)

                    self.status = .connected(storeName: store.name, bssid: bssid)
                    continuation.resume(returning: true)
                }
            }
        }
        #endif
    }

    /// Disconnect / Remove hotspot configuration from iOS
    public func forgetNetwork() {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: Self.louisaSSID)
        UsageTracker.shared.endSession()
        self.status = .idle
        self.currentSSID = nil
        self.currentBSSID = nil
        self.isOnline = false
    }

    /// Query iOS for currently associated Wi-Fi network information
    public func refreshCurrentNetworkState() async {
        #if targetEnvironment(simulator)
        if case .connected(let store, let bssid) = self.status {
            self.currentSSID = Self.louisaSSID
            self.currentBSSID = bssid
            self.isOnline = true
        }
        #else
        let currentNetwork = await NEHotspotNetwork.fetchCurrent()
        if let currentNetwork {
            self.currentSSID = currentNetwork.ssid
            self.currentBSSID = currentNetwork.bssid

            if currentNetwork.ssid == Self.louisaSSID {
                // Determine store name if we've learned this BSSID
                let storeName: String
                if let entry = LearnedStoreCache.shared.entry(forBSSID: currentNetwork.bssid) {
                    storeName = entry.store
                } else if let active = UsageTracker.shared.currentSessionStore {
                    storeName = active
                } else {
                    storeName = UsageTracker.unknownStore
                }

                self.status = .connected(storeName: storeName, bssid: currentNetwork.bssid)
            } else {
                if case .connected = self.status {
                    UsageTracker.shared.endSession()
                    self.status = .idle
                }
            }
        }
        #endif
    }

    /// Check captive.apple.com to verify actual HTTP Internet connectivity
    public func checkOnline() async -> Bool {
        guard let url = URL(string: "http://captive.apple.com/hotspot-detect.html") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let body = String(decoding: data, as: UTF8.self)
                return body.contains("Success")
            }
        } catch {
            return false
        }
        return false
    }

    private func mapHotspotError(_ error: NSError) -> String {
        switch error.code {
        case NEHotspotConfigurationError.userDenied.rawValue:
            return "您取消了加入 Wi-Fi"
        case NEHotspotConfigurationError.alreadyAssociated.rawValue:
            return "已經連上此網路"
        case NEHotspotConfigurationError.invalid.rawValue:
            return "設定參數無效"
        case NEHotspotConfigurationError.pending.rawValue:
            return "另一個連線請求正在處理中"
        case NEHotspotConfigurationError.systemConfiguration.rawValue:
            return "系統設定錯誤，請稍後再試"
        default:
            return error.localizedDescription
        }
    }
}

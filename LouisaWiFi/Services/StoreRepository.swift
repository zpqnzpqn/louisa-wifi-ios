import CoreLocation
import Foundation
import Combine
import os

/// Manages the database of 500+ Louisa Coffee stores across Taiwan.
public final class StoreRepository: ObservableObject, @unchecked Sendable {
    public static let shared = StoreRepository()

    @Published public private(set) var stores: [Store] = []
    @Published public private(set) var isUpdating = false
    @Published public private(set) var lastSyncDate: Date?

    private static let rawDataURL = URL(string: "https://raw.githubusercontent.com/zpqnzpqn/louisa-wifi-ios/main/data/stores.json")!
    private static let fallbackDataURL = URL(string: "https://raw.githubusercontent.com/madeyexz/louisa-wifi/main/data/stores.json")!

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LouisaWiFi", isDirectory: true)
        return dir.appendingPathComponent("stores_cache.json")
    }

    private let logger = Logger(subsystem: "io.github.zpqnzpqn.LouisaWiFi", category: "store-repository")

    public static let cityOrder = [
        "台北市", "新北市", "基隆市", "桃園市", "新竹市", "新竹縣",
        "苗栗縣", "台中市", "彰化縣", "南投縣", "雲林縣", "嘉義市",
        "嘉義縣", "台南市", "高雄市", "屏東縣", "宜蘭縣", "花蓮縣",
        "台東縣", "澎湖縣", "金門縣", "連江縣"
    ]

    private init() {
        loadStores()
    }

    public func loadStores() {
        // 1. Try local application support cache
        if let data = try? Data(contentsOf: Self.cacheURL),
           let cached = try? JSONDecoder().decode([Store].self, from: data),
           !cached.isEmpty {
            self.stores = cached
            self.lastSyncDate = (try? FileManager.default.attributesOfItem(atPath: Self.cacheURL.path)[.modificationDate]) as? Date
            return
        }

        // 2. Fall back to bundle stores.json
        if let bundleURL = Bundle.main.url(forResource: "stores", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let bundled = try? JSONDecoder().decode([Store].self, from: data) {
            self.stores = bundled
        }
    }

    public func nearestStores(to location: CLLocation, limit: Int = 5) -> [(store: Store, meters: Double)] {
        let ranked = stores.compactMap { store -> (store: Store, meters: Double)? in
            guard let loc = store.location else { return nil }
            return (store: store, meters: loc.distance(from: location))
        }
        return Array(ranked.sorted { $0.meters < $1.meters }.prefix(limit))
    }

    public func nearestStore(to location: CLLocation) -> Store? {
        nearestStores(to: location, limit: 1).first?.store
    }

    public func storesGroupedByCity() -> [(city: String, stores: [Store])] {
        let rank = { (city: String) in Self.cityOrder.firstIndex(of: city) ?? Self.cityOrder.count }
        return Dictionary(grouping: stores, by: \.city)
            .sorted { (rank($0.key), $0.key) < (rank($1.key), $1.key) }
            .map { (city: $0.key, stores: $0.value.sorted { $0.name < $1.name }) }
    }

    @MainActor
    public func syncFromRemote() async throws {
        isUpdating = true
        defer { isUpdating = false }

        var targetData: Data?

        do {
            let (data, response) = try await URLSession.shared.data(from: Self.rawDataURL)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                targetData = data
            }
        } catch {
            logger.notice("Primary raw URL failed, trying fallback...")
        }

        if targetData == nil {
            let (data, response) = try await URLSession.shared.data(from: Self.fallbackDataURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            targetData = data
        }

        guard let validData = targetData else {
            throw URLError(.cannotDecodeContentData)
        }

        let decoded = try JSONDecoder().decode([Store].self, from: validData)
        guard !decoded.isEmpty else {
            throw URLError(.zeroByteResource)
        }

        self.stores = decoded
        self.lastSyncDate = Date()

        // Write to cache
        let url = Self.cacheURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? validData.write(to: url, options: .atomic)
    }
}

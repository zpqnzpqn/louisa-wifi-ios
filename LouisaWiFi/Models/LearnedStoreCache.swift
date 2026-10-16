import Foundation
import os

/// Persists router BSSIDs and stores where Wi-Fi connection has succeeded.
public final class LearnedStoreCache: ObservableObject, @unchecked Sendable {
    public static let shared = LearnedStoreCache()

    public struct Entry: Codable, Equatable, Sendable {
        public let store: String
        public let password: String
        public let updatedAt: Date

        public init(store: String, password: String, updatedAt: Date = Date()) {
            self.store = store
            self.password = password
            self.updatedAt = updatedAt
        }
    }

    @Published public private(set) var entries: [String: Entry] = [:]
    private let lock = NSLock()

    private static var storageURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LouisaWiFi", isDirectory: true)
        return dir.appendingPathComponent("learned.json")
    }

    private init() {
        load()
    }

    public func load() {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? Data(contentsOf: Self.storageURL),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return
        }
        self.entries = decoded
    }

    public func save() {
        lock.lock()
        let snapshot = self.entries
        lock.unlock()

        let url = Self.storageURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            Logger(subsystem: "io.github.zpqnzpqn.LouisaWiFi", category: "cache")
                .error("Failed to save learned store cache: \(error.localizedDescription)")
        }
    }

    /// Look up by BSSID (MAC address format: 00:11:22:33:44:55)
    public func entry(forBSSID bssid: String) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        return entries[normalizeBSSID(bssid)]
    }

    /// Look up the latest verified working password for a specific store name
    public func lastVerifiedPassword(forStore storeName: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        let matches = entries.values.filter { $0.store == storeName }
        return matches.sorted { $0.updatedAt > $1.updatedAt }.first?.password
    }

    /// Record a successful connection
    public func remember(bssid: String?, store: String, password: String) {
        let entry = Entry(store: store, password: password, updatedAt: Date())
        lock.lock()
        if let bssid, !bssid.isEmpty {
            entries[normalizeBSSID(bssid)] = entry
        }
        // Also save an entry keyed by store name for fallback
        entries["store:\(store)"] = entry
        lock.unlock()

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        save()
    }

    /// Reset all learned entries
    public func clearAll() {
        lock.lock()
        entries.removeAll()
        lock.unlock()

        try? FileManager.default.removeItem(at: Self.storageURL)
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    private func normalizeBSSID(_ raw: String) -> String {
        raw.lowercased()
            .split(separator: ":")
            .map { $0.count == 1 ? "0\($0)" : String($0) }
            .joined(separator: ":")
    }
}

import Foundation
import Combine
import os

/// Counts minutes and hours spent on Louisa Wi-Fi, per day and store.
/// Stores usage in "yyyy-MM-dd" -> store name -> seconds, identical to the macOS edition.
public final class UsageTracker: ObservableObject, @unchecked Sendable {
    public static let shared = UsageTracker()
    public static let unknownStore = "未知門市"

    /// "yyyy-MM-dd" -> store name -> seconds
    @Published public private(set) var usage: [String: [String: Double]] = [:]
    @Published public private(set) var currentSessionStore: String?
    @Published public private(set) var currentSessionStart: Date?

    private let lock = NSLock()

    public static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static var storageURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LouisaWiFi", isDirectory: true)
        return dir.appendingPathComponent("usage.json")
    }

    private init() {
        load()
    }

    public func load() {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? Data(contentsOf: Self.storageURL),
              let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) else {
            return
        }
        self.usage = decoded
    }

    public func save() {
        lock.lock()
        let snapshot = self.usage
        lock.unlock()

        let url = Self.storageURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            Logger(subsystem: "io.github.zpqnzpqn.LouisaWiFi", category: "tracker")
                .error("Failed to save usage data: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Management

    public func startSession(store: String) {
        lock.lock()
        // If there was an ongoing session, flush it first
        flushCurrentSessionLocked()
        currentSessionStore = store
        currentSessionStart = Date()
        lock.unlock()

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    public func endSession() {
        lock.lock()
        flushCurrentSessionLocked()
        currentSessionStore = nil
        currentSessionStart = nil
        lock.unlock()

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        save()
    }

    /// Checkpoints elapsed session time to prevent loss on unexpected suspension
    public func checkpointSession() {
        lock.lock()
        flushCurrentSessionLocked()
        // Reset session start to now if still connected
        if currentSessionStore != nil {
            currentSessionStart = Date()
        }
        lock.unlock()

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        save()
    }

    private func flushCurrentSessionLocked() {
        guard let store = currentSessionStore, let start = currentSessionStart else { return }
        let elapsed = max(0, Date().timeIntervalSince(start))
        if elapsed > 10 { // Only record if spent more than 10 seconds
            let dayKey = Self.dayFormatter.string(from: start)
            usage[dayKey, default: [:]][store, default: 0] += elapsed
        }
    }

    public func addUsage(store: String, date: Date = Date(), seconds: Double) {
        guard seconds > 0 else { return }
        lock.lock()
        let dayKey = Self.dayFormatter.string(from: date)
        usage[dayKey, default: [:]][store, default: 0] += seconds
        lock.unlock()

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        save()
    }

    public func resetAll() {
        lock.lock()
        usage.removeAll()
        currentSessionStore = nil
        currentSessionStart = nil
        lock.unlock()

        try? FileManager.default.removeItem(at: Self.storageURL)
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    // MARK: - Query & Aggregations

    public func totalSeconds() -> Double {
        lock.lock()
        defer { lock.unlock() }
        return usage.values.reduce(0) { sum, dayMap in
            sum + dayMap.values.reduce(0, +)
        }
    }

    public func seconds(on date: Date, store: String? = nil) -> Double {
        lock.lock()
        defer { lock.unlock() }
        let key = Self.dayFormatter.string(from: date)
        guard let dayMap = usage[key] else { return 0 }
        if let store {
            return dayMap[store] ?? 0
        }
        return dayMap.values.reduce(0, +)
    }

    public func storeTotals() -> [(name: String, seconds: Double)] {
        lock.lock()
        defer { lock.unlock() }
        var map: [String: Double] = [:]
        for (_, stores) in usage {
            for (name, s) in stores {
                map[name, default: 0] += s
            }
        }
        return map.map { (name: $0.key, seconds: $0.value) }.sorted { $0.seconds > $1.seconds }
    }
}

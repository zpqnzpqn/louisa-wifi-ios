import AppIntents
import CoreLocation

public struct ConnectNearestLouisaIntent: AppIntent {
    public static var title: LocalizedStringResource = "連上最近的路易莎 Wi-Fi"
    public static var description = IntentDescription("自動定位離您最近的路易莎門市並發起 Wi-Fi 連線")

    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some ProvidesDialog {
        LocationManager.shared.startUpdating()
        try? await Task.sleep(nanoseconds: 800_000_000)

        guard let loc = LocationManager.shared.currentLocation,
              let nearest = StoreRepository.shared.nearestStore(to: loc) else {
            return .result(dialog: "無法取得目前定位或附近沒有路易莎門市")
        }

        _ = await WiFiConnector.shared.connect(to: nearest)
        return .result(dialog: "正在為您連上「\(nearest.name)」的 Wi-Fi！")
    }
}

public struct GetNearestLouisaPasswordIntent: AppIntent {
    public static var title: LocalizedStringResource = "取得最近路易莎密碼"
    public static var description = IntentDescription("查詢離您最近的路易莎門市 Wi-Fi 密碼")

    public init() {}

    @MainActor
    public func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        LocationManager.shared.startUpdating()
        try? await Task.sleep(nanoseconds: 800_000_000)

        guard let loc = LocationManager.shared.currentLocation,
              let nearest = StoreRepository.shared.nearestStore(to: loc) else {
            return .result(value: "", dialog: "無法取得目前定位或找不到附近門市")
        }

        let pwd = LearnedStoreCache.shared.lastVerifiedPassword(forStore: nearest.name) ?? nearest.passwords.first ?? ""
        return .result(value: pwd, dialog: "「\(nearest.name)」的 Wi-Fi 密碼為：\(pwd)")
    }
}

public struct LouisaShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ConnectNearestLouisaIntent(),
            phrases: [
                "用 \(.applicationName) 連上路易莎",
                "透過 \(.applicationName) 連上最近的路易莎",
                "使用 \(.applicationName) 連線 Wi-Fi",
                "Connect to Wi-Fi with \(.applicationName)"
            ],
            shortTitle: "連上最近路易莎",
            systemImageName: "cup.and.saucer.fill"
        )
    }
}

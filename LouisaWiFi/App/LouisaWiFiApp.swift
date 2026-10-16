import SwiftUI

@main
struct LouisaWiFiApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Initialize StoreRepository and LocationManager on startup
        StoreRepository.shared.loadStores()
        LocationManager.shared.startUpdating()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        Task {
                            await WiFiConnector.shared.refreshCurrentNetworkState()
                        }
                    case .background:
                        UsageTracker.shared.checkpointSession()
                    default:
                        break
                    }
                }
        }
    }
}

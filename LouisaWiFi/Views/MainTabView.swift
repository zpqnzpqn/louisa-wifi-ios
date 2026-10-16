import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            ConnectView()
                .tabItem {
                    Label("連線", systemImage: "cup.and.saucer.fill")
                }
                .tag(0)

            StoreListView()
                .tabItem {
                    Label("門市", systemImage: "magnifyingglass")
                }
                .tag(1)

            StatsView()
                .tabItem {
                    Label("統計", systemImage: "chart.bar.xaxis")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.orange)
    }
}

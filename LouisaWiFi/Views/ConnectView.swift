import SwiftUI
import CoreLocation

public struct ConnectView: View {
    @ObservedObject private var connector = WiFiConnector.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var storeRepo = StoreRepository.shared
    @ObservedObject private var tracker = UsageTracker.shared

    @State private var hasAutoTriggered = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false

    private var nearestStores: [(store: Store, meters: Double)] {
        guard let location = locationManager.currentLocation else { return [] }
        return storeRepo.nearestStores(to: location, limit: 5)
    }

    private var nearestStore: Store? {
        nearestStores.first?.store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Banner
                    statusBanner

                    // Nearest Store Section
                    if let nearest = nearestStore {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("所在門市", systemImage: "location.fill")
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                                Spacer()
                            }

                            StoreCardView(
                                store: nearest,
                                userLocation: locationManager.currentLocation,
                                isNearest: true
                            ) { selectedPassword in
                                Task {
                                    await performConnect(store: nearest, password: selectedPassword)
                                }
                            }
                        }
                    } else {
                        // Location permission or locating placeholder
                        locatingCard
                    }

                    // Nearby Stores (Rank 2 ~ 5)
                    let otherStores = nearestStores.dropFirst()
                    if !otherStores.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("附近其他路易莎")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            ForEach(Array(otherStores), id: \.store.name) { item in
                                StoreCardView(
                                    store: item.store,
                                    userLocation: locationManager.currentLocation,
                                    isNearest: false
                                ) { selectedPassword in
                                    Task {
                                        await performConnect(store: item.store, password: selectedPassword)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("☕ Louisa Wi-Fi")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        locationManager.requestSingleLocation()
                        Task {
                            await connector.refreshCurrentNetworkState()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert("連線提示", isPresented: $showingErrorAlert) {
                Button("好", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                locationManager.startUpdating()
                triggerAutoConnectIfNeeded()
            }
            .onChange(of: locationManager.currentLocation) { _ in
                triggerAutoConnectIfNeeded()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusBanner: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(connector.isConnected ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: connector.isConnected ? "wifi" : "wifi.slash")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(connector.isConnected ? Color.green : Color.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(connector.status.displayText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if connector.isConnected {
                        HStack(spacing: 6) {
                            if connector.isOnline {
                                Label("可正常上網", systemImage: "globe")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            } else {
                                Label("檢查網際網路中...", systemImage: "ellipsis")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if let bssid = connector.currentBSSID {
                                Text("• BSSID: \(bssid)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("走進路易莎即可一鍵加入 LouisaCoffee")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if connector.isConnected {
                    Button("中斷") {
                        connector.forgetNetwork()
                    }
                    .font(.caption.weight(.medium))
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
        )
    }

    @ViewBuilder
    private var locatingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .padding(.top, 8)
            Text("正在定位最近的路易莎門市...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                VStack(spacing: 6) {
                    Text("⚠️ 需要定位權限以找出最近的門市")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)

                    Button("開啟系統設定") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Actions

    private func performConnect(store: Store, password: String?) async {
        let success = await connector.connect(to: store, password: password)
        if !success {
            if case .failed(let reason) = connector.status {
                self.errorMessage = reason
                self.showingErrorAlert = true
            }
        }
    }

    private func triggerAutoConnectIfNeeded() {
        guard !hasAutoTriggered else { return }
        let autoEnabled = UserDefaults.standard.object(forKey: "autoConnectOnLaunch") as? Bool ?? true
        guard autoEnabled else { return }
        guard !connector.isConnected else { return }
        guard let nearest = nearestStore else { return }

        // Only auto trigger if within 500 meters of a store
        if let meters = nearest.distance(from: locationManager.currentLocation), meters <= 500 {
            hasAutoTriggered = true
            Task {
                await performConnect(store: nearest, password: nil)
            }
        }
    }
}

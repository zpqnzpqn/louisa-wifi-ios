import SwiftUI
import CoreLocation

public struct StoreListView: View {
    @ObservedObject private var storeRepo = StoreRepository.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var connector = WiFiConnector.shared

    @State private var searchText = ""
    @State private var selectedCity: String? = nil
    @State private var selectedStoreForDetail: Store? = nil

    private var filteredStores: [Store] {
        var list = storeRepo.stores

        if let city = selectedCity {
            list = list.filter { $0.city == city }
        }

        if !searchText.isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            list = list.filter {
                $0.name.lowercased().contains(query) ||
                $0.address.lowercased().contains(query) ||
                $0.phone.contains(query)
            }
        }

        // If user location is available, sort nearest first; otherwise sort by name
        if let userLoc = locationManager.currentLocation {
            return list.sorted {
                let d1 = $0.distance(from: userLoc) ?? Double.greatestFiniteMagnitude
                let d2 = $1.distance(from: userLoc) ?? Double.greatestFiniteMagnitude
                return d1 < d2
            }
        } else {
            return list.sorted { $0.name < $1.name }
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // City Filter Horizontal Bar
                cityFilterBar

                // Stores List
                List {
                    ForEach(filteredStores) { store in
                        Button {
                            selectedStoreForDetail = store
                        } label: {
                            storeRow(store)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .searchable(text: $searchText, prompt: "搜尋門市名稱、地址或電話")
            .navigationTitle("門市搜尋 (\(filteredStores.count))")
            .sheet(item: $selectedStoreForDetail) { store in
                StoreDetailSheet(store: store, userLocation: locationManager.currentLocation)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var cityFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedCity = nil
                } label: {
                    Text("全部縣市")
                        .font(.subheadline.weight(selectedCity == nil ? .bold : .regular))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedCity == nil ? Color.orange : Color(.systemGray6))
                        .foregroundStyle(selectedCity == nil ? Color.white : Color.primary)
                        .clipShape(Capsule())
                }

                ForEach(StoreRepository.cityOrder, id: \.self) { city in
                    Button {
                        selectedCity = (selectedCity == city ? nil : city)
                    } label: {
                        Text(city)
                            .font(.subheadline.weight(selectedCity == city ? .bold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedCity == city ? Color.orange : Color(.systemGray6))
                            .foregroundStyle(selectedCity == city ? Color.white : Color.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    @ViewBuilder
    private func storeRow(_ store: Store) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(store.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(store.phone)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.distance(from: locationManager.currentLocation) != nil {
                Text(store.formattedDistance(from: locationManager.currentLocation))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.orange)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Store Detail Sheet

struct StoreDetailSheet: View {
    let store: Store
    let userLocation: CLLocation?
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var connector = WiFiConnector.shared
    @ObservedObject private var cache = LearnedStoreCache.shared

    @State private var customPassword = ""
    @State private var showingQRModal = false
    @State private var qrPassword = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("門市資訊") {
                    LabeledContent("門市名稱", value: store.name)
                    LabeledContent("地址", value: store.address)
                    LabeledContent("電話", value: store.phone)
                    if store.distance(from: userLocation) != nil {
                        LabeledContent("目前距離", value: store.formattedDistance(from: userLocation))
                    }
                }

                Section("候選 Wi-Fi 密碼") {
                    ForEach(store.passwords, id: \.self) { pwd in
                        let isLearned = (cache.lastVerifiedPassword(forStore: store.name) == pwd)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(pwd)
                                        .font(.body.monospaced().weight(isLearned ? .bold : .regular))
                                    if isLearned {
                                        Label("曾成功連線", systemImage: "star.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }

                            Spacer()

                            Button("連線") {
                                Task {
                                    _ = await connector.connect(to: store, password: pwd)
                                    dismiss()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)

                            Button {
                                qrPassword = pwd
                                showingQRModal = true
                            } label: {
                                Image(systemName: "qrcode")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                Section("手動自訂密碼連線") {
                    Text("若該店張貼了非電話變體的特殊密碼，可在此手動輸入連線並記住：")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("輸入店內張貼密碼", text: $customPassword)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button("連線並記住") {
                            guard !customPassword.isEmpty else { return }
                            Task {
                                _ = await connector.connect(to: store, password: customPassword)
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(customPassword.isEmpty)
                    }
                }
            }
            .navigationTitle(store.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showingQRModal) {
                WiFiQRCodeModal(storeName: store.name, password: qrPassword)
            }
        }
    }
}

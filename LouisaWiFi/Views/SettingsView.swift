import SwiftUI

public struct SettingsView: View {
    @AppStorage("autoConnectOnLaunch") private var autoConnectOnLaunch = true
    @ObservedObject private var storeRepo = StoreRepository.shared
    @ObservedObject private var cache = LearnedStoreCache.shared
    @ObservedObject private var tracker = UsageTracker.shared

    @State private var showingSyncAlert = false
    @State private var syncAlertMessage = ""
    @State private var showingClearCacheAlert = false
    @State private var showingResetStatsAlert = false

    public var body: some View {
        NavigationStack {
            Form {
                // Connection Preferences
                Section("連線偏好") {
                    Toggle("打開 App 自動彈出連線", isOn: $autoConnectOnLaunch)
                    Text("當您走到路易莎門市並開啟 App 時，系統將自動比對 GPS 並主動彈出連線確認框，省去手動點擊步驟。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Store Database Sync
                Section("門市資料庫") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已收錄全台門市")
                            if let lastSync = storeRepo.lastSyncDate {
                                Text("上次同步：\(formattedSyncDate(lastSync))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(storeRepo.stores.count) 家")
                            .font(.subheadline.monospacedDigit().weight(.bold))
                            .foregroundStyle(.orange)
                    }

                    Button {
                        Task {
                            do {
                                try await storeRepo.syncFromRemote()
                                syncAlertMessage = "成功同步最新門市資料！目前共 \(storeRepo.stores.count) 家門市。"
                                showingSyncAlert = true
                            } catch {
                                syncAlertMessage = "同步失敗，請確認網路連線：\(error.localizedDescription)"
                                showingSyncAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            if storeRepo.isUpdating {
                                ProgressView()
                                    .padding(.trailing, 4)
                                Text("正在同步門市資料...")
                            } else {
                                Label("立即從 GitHub 同步最新門市", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                    }
                    .disabled(storeRepo.isUpdating)
                }

                // Router Memory & Cache Management
                Section("路由器記憶與統計") {
                    HStack {
                        Text("已記住路由器")
                        Spacer()
                        Text("\(cache.entries.count) 組")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showingClearCacheAlert = true
                    } label: {
                        Label("清除已記住的路由器密碼", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        showingResetStatsAlert = true
                    } label: {
                        Label("重置連線時數統計資料", systemImage: "arrow.counterclockwise")
                    }
                }

                // Shortcuts & Action Button Guide
                Section("iPhone 動作按鈕與捷徑") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("動作按鈕 (Action Button) 一鍵連線", systemImage: "button.programmable")
                            .font(.subheadline.weight(.semibold))

                        Text("若您使用的是支援動作按鈕的 iPhone (15 Pro / 16 系列)，可以在 iOS「設定 → 動作按鈕」中指定執行「捷徑 (Shortcuts)」，並加入「☕ 連上最近的路易莎」動作，走進店裡按一下機身側面按鈕即可立即觸發連線！")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // About & Credits
                Section("關於 Louisa Wi-Fi") {
                    LabeledContent("版本", value: "1.0.0 (Build 1)")
                    LabeledContent("原專案作者", value: "madeyexz/louisa-wifi")
                    LabeledContent("iOS 開發者", value: "zpqnzpqn")

                    Link(destination: URL(string: "https://github.com/madeyexz/louisa-wifi")!) {
                        HStack {
                            Text("造訪 macOS 原版 GitHub 儲存庫")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/zpqnzpqn/louisa-wifi-ios")!) {
                        HStack {
                            Text("造訪本專案 GitHub 儲存庫")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("⚙️ 設定")
            .alert("門市同步", isPresented: $showingSyncAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(syncAlertMessage)
            }
            .alert("清除路由器記憶", isPresented: $showingClearCacheAlert) {
                Button("取消", role: .cancel) { }
                Button("確認清除", role: .destructive) {
                    cache.clearAll()
                }
            } message: {
                Text("確定要清除所有已記住的 Wi-Fi 路由器 BSSID 與歷史成功密碼嗎？")
            }
            .alert("重置統計資料", isPresented: $showingResetStatsAlert) {
                Button("取消", role: .cancel) { }
                Button("確認重置", role: .destructive) {
                    tracker.resetAll()
                }
            } message: {
                Text("確定要重置熱度方格圖與累積時數紀錄嗎？此動作無法復原。")
            }
        }
    }

    private func formattedSyncDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: date)
    }
}

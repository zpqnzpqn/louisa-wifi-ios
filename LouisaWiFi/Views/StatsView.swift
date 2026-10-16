import SwiftUI

public struct StatsView: View {
    @ObservedObject private var tracker = UsageTracker.shared
    @State private var selectedDate: Date?
    @State private var selectedStoreFilter: String?
    @State private var breakdownMode: BreakdownMode = .stores

    public enum BreakdownMode: String, CaseIterable {
        case stores = "門市排行"
        case months = "月份統計"
        case years = "年份統計"
    }

    private var allDaysWithUsage: [String: Double] {
        tracker.usage.mapValues { storeMap in
            if let selectedStoreFilter {
                return storeMap[selectedStoreFilter] ?? 0
            }
            return storeMap.values.reduce(0, +)
        }
    }

    private var totalSeconds: Double {
        allDaysWithUsage.values.reduce(0, +)
    }

    private var visitedDaysCount: Int {
        allDaysWithUsage.values.filter { $0 > 0 }.count
    }

    private var visitedStoresCount: Int {
        let storeSet = Set(tracker.usage.values.flatMap { $0.keys }.filter { $0 != UsageTracker.unknownStore })
        return storeSet.count
    }

    private var longestStreak: Int {
        let sortedDates = tracker.usage.keys.sorted()
        var maxStreak = 0
        var currentStreak = 0
        var previousDate: Date?

        let cal = Calendar.current
        for dateStr in sortedDates {
            guard let date = UsageTracker.dayFormatter.date(from: dateStr),
                  let sec = tracker.usage[dateStr]?.values.reduce(0, +), sec > 0 else {
                continue
            }

            if let prev = previousDate {
                let diff = cal.dateComponents([.day], from: prev, to: date).day ?? 0
                if diff == 1 {
                    currentStreak += 1
                } else if diff > 1 {
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            previousDate = date
            maxStreak = max(maxStreak, currentStreak)
        }
        return maxStreak
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Summary Title & Filter Reset
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(selectedStoreFilter.map { "\($0) 連線紀錄" } ?? "累積連線 \(formatDuration(totalSeconds))")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedStoreFilter != nil {
                                Button("清除篩選") {
                                    selectedStoreFilter = nil
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                                .tint(.orange)
                            }
                        }
                    }

                    // Stat Tiles (4 Grid)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        statTile(label: "到訪天數", value: "\(visitedDaysCount) 天", icon: "calendar")
                        statTile(label: "到訪門市", value: "\(visitedStoresCount) 家", icon: "cup.and.saucer.fill")
                        statTile(label: "最長連續", value: "\(longestStreak) 天", icon: "flame.fill")
                        statTile(label: "平均每日", value: visitedDaysCount > 0 ? formatDuration(totalSeconds / Double(visitedDaysCount)) : "—", icon: "clock")
                    }

                    // Contribution Heatmap Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("連線熱度方格圖")
                            .font(.headline)

                        HeatmapGridView(
                            usage: tracker.usage,
                            filterStore: selectedStoreFilter,
                            selectedDate: $selectedDate
                        )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )

                    // Breakdown Mode Section
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("統計分類", selection: $breakdownMode) {
                            ForEach(BreakdownMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch breakdownMode {
                        case .stores:
                            storesRankingList
                        case .months:
                            monthsChart
                        case .years:
                            yearsRankingList
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("📊 連線統計")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func statTile(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private var storesRankingList: some View {
        let storeTotals = tracker.storeTotals()
        if storeTotals.isEmpty {
            Text("尚無連線紀錄。連上路易莎 Wi-Fi 後將自動記錄停留時間。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            let maxSeconds = storeTotals.first?.seconds ?? 1.0
            VStack(spacing: 12) {
                ForEach(storeTotals, id: \.name) { item in
                    Button {
                        if selectedStoreFilter == item.name {
                            selectedStoreFilter = nil
                        } else {
                            selectedStoreFilter = item.name
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.name)
                                    .font(.subheadline.weight(selectedStoreFilter == item.name ? .bold : .medium))
                                    .foregroundStyle(selectedStoreFilter == item.name ? .orange : .primary)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatDuration(item.seconds))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            // Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.tertiarySystemFill))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(selectedStoreFilter == item.name ? Color.orange : Color.blue)
                                        .frame(width: max(4, geo.size.width * CGFloat(item.seconds / maxSeconds)))
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var monthsChart: some View {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let monthData = (1...12).map { month -> (month: Int, seconds: Double) in
            let prefix = String(format: "%04d-%02d", currentYear, month)
            let seconds = tracker.usage.filter { $0.key.hasPrefix(prefix) }
                .values.flatMap { $0.values }.reduce(0, +)
            return (month: month, seconds: seconds)
        }
        let peak = monthData.map { $0.seconds }.max() ?? 1.0

        HStack(alignment: .bottom, spacing: 8) {
            ForEach(monthData, id: \.month) { item in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.seconds > 0 ? Color.blue : Color(.tertiarySystemFill))
                        .frame(height: peak > 0 ? max(4, 120 * CGFloat(item.seconds / peak)) : 4)

                    Text("\(item.month)月")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 150, alignment: .bottom)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var yearsRankingList: some View {
        let years = Array(Set(tracker.usage.keys.compactMap { Int($0.prefix(4)) })).sorted(by: >)
        if years.isEmpty {
            Text("尚無年份紀錄。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(years, id: \.self) { year in
                    let prefix = "\(year)"
                    let sec = tracker.usage.filter { $0.key.hasPrefix(prefix) }
                        .values.flatMap { $0.values }.reduce(0, +)
                    HStack {
                        Text("\(year) 年")
                            .font(.headline)
                        Spacer()
                        Text(formatDuration(sec))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds / 60)
        if mins >= 60 {
            return "\(mins / 60) 小時 \(mins % 60) 分"
        }
        return "\(mins) 分鐘"
    }
}

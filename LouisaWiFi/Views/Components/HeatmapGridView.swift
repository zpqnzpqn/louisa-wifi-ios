import SwiftUI

public struct HeatmapGridView: View {
    public let usage: [String: [String: Double]]
    public let filterStore: String?
    @Binding public var selectedDate: Date?

    private let calendar = Calendar.mondayFirst
    private let weeksToShow = 20 // past 20 weeks fitted nicely with horizontal scroll
    private let cellSize: CGFloat = 14
    private let gap: CGFloat = 3

    public init(usage: [String: [String: Double]], filterStore: String? = nil, selectedDate: Binding<Date?>) {
        self.usage = usage
        self.filterStore = filterStore
        self._selectedDate = selectedDate
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var gridStartDate: Date {
        let endDate = today
        let daysAgo = (weeksToShow - 1) * 7
        let approxStart = calendar.date(byAdding: .day, value: -daysAgo, to: endDate)!
        return calendar.dateInterval(of: .weekOfYear, for: approxStart)!.start
    }

    private var weeks: [[Date]] {
        (0..<weeksToShow).map { weekIndex in
            (0..<7).map { dayIndex in
                calendar.date(byAdding: .day, value: weekIndex * 7 + dayIndex, to: gridStartDate)!
            }
        }
    }

    private func secondsForDay(_ date: Date) -> Double {
        let key = UsageTracker.dayFormatter.string(from: date)
        guard let dayMap = usage[key] else { return 0 }
        if let filterStore {
            return dayMap[filterStore] ?? 0
        }
        return dayMap.values.reduce(0, +)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: gap) {
                        // Weekday Labels Column (一, 三, 五)
                        VStack(spacing: gap) {
                            ForEach(0..<7, id: \.self) { d in
                                Text(["一", "", "三", "", "五", "", "日"][d])
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14, height: cellSize)
                            }
                        }

                        // Weeks Columns
                        ForEach(0..<weeksToShow, id: \.self) { w in
                            let weekDates = weeks[w]
                            VStack(spacing: gap) {
                                ForEach(0..<7, id: \.self) { d in
                                    let date = weekDates[d]
                                    cellView(date: date)
                                }
                            }
                            .id(w)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                }
                .onAppear {
                    // Scroll to current week
                    proxy.scrollTo(weeksToShow - 1, anchor: .trailing)
                }
            }

            // Legend & Caption
            HStack {
                if let selected = selectedDate {
                    let sec = secondsForDay(selected)
                    Text("\(formattedDate(selected))：\(sec > 0 ? formattedDuration(sec) : "無紀錄")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                } else {
                    Text("點選方格查看當天連線時間")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 3) {
                    Text("少")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    ForEach([0.0, 1.0, 1800.0, 3600.0, 7200.0], id: \.self) { levelSec in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatColor(for: levelSec))
                            .frame(width: 10, height: 10)
                    }
                    Text("多")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func cellView(date: Date) -> some View {
        let isFuture = date > today
        let seconds = secondsForDay(date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false

        RoundedRectangle(cornerRadius: 2.5)
            .fill(isFuture ? Color.clear : heatColor(for: seconds))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 2.5)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !isFuture {
                    if isSelected {
                        selectedDate = nil
                    } else {
                        selectedDate = date
                    }
                }
            }
    }

    private func heatColor(for seconds: Double) -> Color {
        if seconds < 1 {
            return Color(.tertiarySystemFill)
        } else if seconds < 1800 { // < 30 mins
            return Color(red: 0.72, green: 0.83, blue: 0.96)
        } else if seconds < 3600 { // < 1 hour
            return Color(red: 0.43, green: 0.65, blue: 0.92)
        } else if seconds < 7200 { // < 2 hours
            return Color(red: 0.16, green: 0.47, blue: 0.84)
        } else { // >= 2 hours
            return Color(red: 0.06, green: 0.26, blue: 0.55)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "M月d日 (E)"
        return formatter.string(from: date)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let mins = Int(seconds / 60)
        if mins >= 60 {
            return "\(mins / 60) 小時 \(mins % 60) 分"
        }
        return "\(mins) 分鐘"
    }
}

extension Calendar {
    public static var mondayFirst: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }
}

import Foundation

public struct SavedFrame: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isFinite: Bool {
        x.isFinite && y.isFinite && width.isFinite && height.isFinite && width > 0 && height > 0
    }
}

public struct Preferences: Codable, Equatable {
    public var monthlyIncome: Decimal = 10_000
    public var daysPerWeek = 5
    public var startMinutes = 540
    public var endMinutes = 1080
    public var backgroundTransparency = 0
    public var alwaysOnTop = false
    public var floatingMode = false
    public var mainFrame: SavedFrame?
    public var floatingFrame: SavedFrame?

    public init() {}

    public var validationError: String? {
        if monthlyIncome.isNaN || monthlyIncome < 0 || monthlyIncome > 1_000_000_000 {
            return "月收入须在 0 至 1,000,000,000 元之间。"
        }
        if !(1...7).contains(daysPerWeek) { return "每周工作天数须为 1 至 7 天。" }
        if !(0..<1440).contains(startMinutes) || !(0..<1440).contains(endMinutes) || endMinutes <= startMinutes {
            return "下班时间需要晚于当天的上班时间。"
        }
        if !(0...100).contains(backgroundTransparency) { return "背景透明度须在 0% 至 100% 之间。" }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case monthlyIncome, daysPerWeek, startMinutes, endMinutes
        case backgroundTransparency, alwaysOnTop, floatingMode, mainFrame, floatingFrame
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        monthlyIncome = try values.decodeIfPresent(Decimal.self, forKey: .monthlyIncome) ?? 10_000
        daysPerWeek = try values.decodeIfPresent(Int.self, forKey: .daysPerWeek) ?? 5
        startMinutes = try values.decodeIfPresent(Int.self, forKey: .startMinutes) ?? 540
        endMinutes = try values.decodeIfPresent(Int.self, forKey: .endMinutes) ?? 1080
        backgroundTransparency = try values.decodeIfPresent(Int.self, forKey: .backgroundTransparency) ?? 0
        alwaysOnTop = try values.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? false
        floatingMode = try values.decodeIfPresent(Bool.self, forKey: .floatingMode) ?? false
        mainFrame = try values.decodeIfPresent(SavedFrame.self, forKey: .mainFrame)
        floatingFrame = try values.decodeIfPresent(SavedFrame.self, forKey: .floatingFrame)
    }
}

public struct PayrollSnapshot {
    public let dailySalary: Decimal
    public let earned: Decimal
    public let progress: Double
    public let workedSeconds: Int
    public let remainingSeconds: Int
    public let status: String
}

public enum Payroll {
    public static func averageMonthlyDays(_ daysPerWeek: Int) -> Decimal {
        (365 - Decimal(7 - daysPerWeek) * 52 - 13) / 12
    }

    public static func calculate(_ settings: Preferences, now: Date, calendar: Calendar = .current) -> PayrollSnapshot {
        precondition(settings.validationError == nil)
        let start = calendar.date(bySettingHour: settings.startMinutes / 60,
                                  minute: settings.startMinutes % 60, second: 0, of: now)!
        let end = calendar.date(bySettingHour: settings.endMinutes / 60,
                                minute: settings.endMinutes % 60, second: 0, of: now)!
        let duration = end.timeIntervalSince(start)
        let elapsed = min(max(now.timeIntervalSince(start), 0), duration)
        let fraction = elapsed / duration
        let daily = settings.monthlyIncome / averageMonthlyDays(settings.daysPerWeek)
        return PayrollSnapshot(dailySalary: daily, earned: daily * Decimal(fraction), progress: fraction,
                               workedSeconds: Int(elapsed), remainingSeconds: max(0, Int(ceil(end.timeIntervalSince(now)))),
                               status: now < start ? "未上班" : now >= end ? "已下班" : "工作中")
    }

    public static func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }

    public static func time(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    public static func parseTime(_ text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    public static func parseIncome(_ text: String) -> Decimal? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.range(of: "^[0-9]+(?:\\.[0-9]*)?$", options: .regularExpression) != nil else { return nil }
        return Decimal(string: clean, locale: Locale(identifier: "en_US_POSIX"))
    }

    public static func money(_ value: Decimal, digits: Int = 4) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0.0000"
    }
}

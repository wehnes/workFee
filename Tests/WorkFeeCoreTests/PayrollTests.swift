import Foundation
import XCTest
@testable import WorkFeeCore

final class PayrollTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int = 0, _ second: Int = 0, day: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
    }

    func testReferenceCalculation() {
        let result = Payroll.calculate(Preferences(), now: date(15, 18), calendar: calendar)
        XCTAssertEqual(Payroll.money(result.dailySalary, digits: 2), "483.87")
        XCTAssertEqual(Payroll.money(result.earned), "338.7097")
        XCTAssertEqual(result.progress, 0.7, accuracy: 0.000001)
        XCTAssertEqual(Payroll.clock(result.remainingSeconds), "02:42:00")
        XCTAssertEqual(result.workedSeconds, 6 * 3600 + 18 * 60)
    }

    func testWorkBoundariesAndReset() {
        let settings = Preferences()
        let early = Payroll.calculate(settings, now: date(8), calendar: calendar)
        XCTAssertEqual(early.earned, 0)
        XCTAssertEqual(early.status, "未上班")
        XCTAssertEqual(early.remainingSeconds, 10 * 3600)
        XCTAssertEqual(Payroll.calculate(settings, now: date(9), calendar: calendar).earned, 0)
        let end = Payroll.calculate(settings, now: date(18), calendar: calendar)
        XCTAssertEqual(end.earned, end.dailySalary)
        XCTAssertEqual(end.remainingSeconds, 0)
        XCTAssertEqual(end.status, "已下班")
        XCTAssertEqual(Payroll.calculate(settings, now: date(23), calendar: calendar).earned, end.dailySalary)
        XCTAssertEqual(Payroll.calculate(settings, now: date(0, day: 10), calendar: calendar).earned, 0)
    }

    func testWeekendsAndPerSecondUpdate() {
        var settings = Preferences()
        settings.monthlyIncome = 3000
        let monday = Payroll.calculate(settings, now: date(11), calendar: calendar)
        let sunday = Payroll.calculate(settings, now: date(11, day: 8), calendar: calendar)
        XCTAssertEqual(monday.earned, sunday.earned)
        let next = Payroll.calculate(settings, now: date(11, 0, 1), calendar: calendar)
        XCTAssertNotEqual(Payroll.money(monday.earned), Payroll.money(next.earned))
        for days in 1...7 { XCTAssertGreaterThan(Payroll.averageMonthlyDays(days), 0) }
        settings.monthlyIncome = 0
        XCTAssertEqual(Payroll.calculate(settings, now: date(11), calendar: calendar).earned, 0)
    }

    func testValidationAndTimeParsing() {
        var settings = Preferences()
        settings.endMinutes = settings.startMinutes
        XCTAssertNotNil(settings.validationError)
        settings = Preferences()
        settings.daysPerWeek = 0
        XCTAssertNotNil(settings.validationError)
        settings = Preferences()
        settings.backgroundTransparency = 101
        XCTAssertNotNil(settings.validationError)
        XCTAssertEqual(Payroll.parseTime("9:05"), 545)
        XCTAssertEqual(Payroll.parseTime("23:59"), 1439)
        XCTAssertNil(Payroll.parseTime("24:00"))
        XCTAssertNil(Payroll.parseTime("9:60"))
        XCTAssertNil(Payroll.parseTime("abc"))
        XCTAssertEqual(Payroll.parseIncome("12345.67"), Decimal(string: "12345.67"))
        XCTAssertNil(Payroll.parseIncome("123abc"))
        XCTAssertNil(Payroll.parseIncome("1,2"))
        XCTAssertNil(Payroll.parseIncome("-3"))
    }

    func testPersistenceAndMissingFields() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("workfee-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SettingsStore(directory: directory)
        XCTAssertNil(store.load().1)
        var settings = Preferences()
        settings.monthlyIncome = Decimal(string: "12345.67")!
        settings.floatingMode = true
        settings.backgroundTransparency = 67
        settings.mainFrame = SavedFrame(x: 20, y: 30, width: 576, height: 488)
        settings.floatingFrame = SavedFrame(x: 100, y: 100, width: 260, height: 90)
        try store.save(settings)
        XCTAssertEqual(store.load().0, settings)
        try Data("{}".utf8).write(to: store.url)
        XCTAssertEqual(store.load().0, Preferences())
        try Data("{broken".utf8).write(to: store.url)
        XCTAssertNotNil(store.load().1)
        try store.save(settings)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains(where: { $0.hasSuffix(".bak") }))
        XCTAssertEqual(store.load().0, settings)
    }
}

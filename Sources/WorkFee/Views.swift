import SwiftUI
import WorkFeeCore

enum Palette {
    static let paper = Color(red: 1, green: 0.988, blue: 0.973)
    static let ink = Color(red: 0.16, green: 0.15, blue: 0.14)
    static let muted = Color(red: 0.52, green: 0.48, blue: 0.44)
    static let gold = Color(red: 0.71, green: 0.49, blue: 0.08)
    static let paleGold = Color(red: 0.78, green: 0.63, blue: 0.36)
    static let red = Color(red: 0.80, green: 0.18, blue: 0.16)
    static let blush = Color(red: 0.98, green: 0.94, blue: 0.92)
    static let stone = Color(red: 0.95, green: 0.93, blue: 0.90)
}

@MainActor struct MoneyView: View {
    let value: Decimal
    let fontSize: CGFloat

    var body: some View {
        let text = Payroll.money(value)
        (Text("¥" + String(text.dropLast(2)))
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundColor(Palette.gold)
         + Text(text.suffix(2))
            .font(.system(size: fontSize * 0.48, weight: .medium, design: .rounded))
            .foregroundColor(Palette.paleGold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.08)
            .accessibilityLabel("今日已赚 ¥\(text)")
    }
}

struct MainActions {
    let floating: () -> Void
    let pin: () -> Void
    let settings: () -> Void
    let minimize: () -> Void
    let close: () -> Void
}

@MainActor struct MainView: View {
    @ObservedObject var model: AppModel
    let actions: MainActions

    private func icon(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .regular))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 400 || geometry.size.height < 390
            let wide = geometry.size.width >= 760 && geometry.size.width > geometry.size.height * 1.5
            let narrow = geometry.size.width < 440
            VStack(spacing: compact ? 6 : 12) {
                HStack(spacing: 2) {
                    Text("下班倒计时")
                        .font(.system(size: compact ? 12 : 14, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    icon("rectangle.inset.filled", help: "悬浮窗模式", action: actions.floating)
                    icon(model.preferences.alwaysOnTop ? "pin.fill" : "pin", help: "切换置顶", action: actions.pin)
                        .foregroundColor(model.preferences.alwaysOnTop ? Palette.gold : Palette.muted)
                    icon("gearshape", help: "设置", action: actions.settings)
                    icon("minus", help: "最小化", action: actions.minimize)
                    icon("xmark", help: "退出", action: actions.close)
                }
                .padding(.horizontal, compact ? 12 : 16)
                .frame(height: compact ? 36 : 46)
                .background(Palette.stone.opacity(model.backgroundOpacity))

                VStack(spacing: compact ? 6 : 10) {
                    if !compact {
                        HStack(spacing: 6) {
                            Circle().fill(Palette.paleGold).frame(width: 6, height: 6)
                            Text(model.snapshot.status).font(.system(size: 11))
                            Spacer()
                        }
                        .foregroundColor(Palette.muted)
                        .frame(height: 16)
                    }
                    VStack(spacing: compact ? 0 : 3) {
                        Text("今日已赚").font(.system(size: compact ? 14 : 17, weight: .semibold))
                        MoneyView(value: model.snapshot.earned, fontSize: min(110, max(38, geometry.size.height * 0.19)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(1)
                        if !compact {
                            Text("实时累计 · 每秒更新")
                                .font(.system(size: 10))
                                .foregroundColor(Palette.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if wide {
                        HStack(spacing: 12) {
                            IncomeCard(model: model, compact: compact, narrow: false)
                            CountdownCard(model: model, compact: compact, stacked: true)
                        }
                        .frame(height: compact ? 82 : 104)
                    } else {
                        IncomeCard(model: model, compact: compact, narrow: narrow)
                            .frame(height: compact ? 82 : 104)
                        CountdownCard(model: model, compact: compact, stacked: false)
                            .frame(height: compact ? 36 : 54)
                    }
                    HStack(spacing: 12) {
                        Text("\(Payroll.time(model.preferences.startMinutes)) 上班")
                        Rectangle().fill(Palette.muted.opacity(model.backgroundOpacity * 0.35)).frame(height: 1)
                        Text("\(Payroll.time(model.preferences.endMinutes)) 下班")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(Palette.muted)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 18)
                }
                .padding(.horizontal, compact ? 14 : 24)
                .padding(.bottom, compact ? 10 : 16)
            }
            .foregroundColor(Palette.ink)
            .background(Palette.paper.opacity(model.backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .padding(8)
    }
}

@MainActor private struct IncomeCard: View {
    @ObservedObject var model: AppModel
    let compact: Bool
    let narrow: Bool

    var body: some View {
        VStack(spacing: compact ? 4 : 7) {
            HStack {
                Text("收入进度").font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(Int((model.snapshot.progress * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                    .foregroundColor(Palette.red)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Palette.red.opacity(model.backgroundOpacity * 0.10))
                    .clipShape(Capsule())
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.red.opacity(model.backgroundOpacity * 0.12))
                    Capsule().fill(LinearGradient(colors: [Color(red: 0.89, green: 0.32, blue: 0.25), Palette.red], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * model.snapshot.progress)
                        .animation(.easeOut(duration: 0.4), value: model.snapshot.progress)
                }
            }
            .frame(height: compact ? 10 : 15)
            Spacer(minLength: 0)
            if narrow {
                VStack(alignment: .leading, spacing: 2) {
                    worked
                    total
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) { worked; Spacer(minLength: 0); total }
            }
        }
        .font(.system(size: 10))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(compact ? 10 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.blush.opacity(model.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var worked: some View {
        Text("已上班 \(model.snapshot.workedSeconds / 3600)小时\(String(format: "%02d", model.snapshot.workedSeconds / 60 % 60))分")
            .foregroundColor(Palette.muted)
    }

    private var total: some View {
        Text("今日总工资 ¥\(Payroll.money(model.snapshot.dailySalary, digits: 2))").foregroundColor(Palette.muted)
    }
}

@MainActor private struct CountdownCard: View {
    @ObservedObject var model: AppModel
    let compact: Bool
    let stacked: Bool

    var body: some View {
        Group {
            if stacked {
                VStack(alignment: .leading, spacing: 5) {
                    title
                    time
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack { title; Spacer(minLength: 8); time }
            }
        }
        .padding(.horizontal, compact ? 10 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.stone.opacity(model.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var title: some View { Text("距离下班").font(.system(size: 12)).foregroundColor(Palette.muted) }
    private var time: some View {
        Text(Payroll.clock(model.snapshot.remainingSeconds))
            .font(.system(size: compact ? 23 : 29, weight: .semibold, design: .rounded))
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
    }
}

@MainActor struct FloatingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GeometryReader { geometry in
            MoneyView(value: model.snapshot.earned, fontSize: max(20, geometry.size.height * 0.7))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.paper.opacity(model.backgroundOpacity))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(8)
        .allowsHitTesting(false)
    }
}

@MainActor struct SettingsView: View {
    @ObservedObject var model: AppModel
    let save: (Preferences) -> String?
    let cancel: () -> Void
    @State private var income: String
    @State private var days: Int
    @State private var start: String
    @State private var end: String
    @State private var transparency: Double
    @State private var errorText = ""

    init(model: AppModel, save: @escaping (Preferences) -> String?, cancel: @escaping () -> Void) {
        self.model = model
        self.save = save
        self.cancel = cancel
        _income = State(initialValue: NSDecimalNumber(decimal: model.preferences.monthlyIncome).stringValue)
        _days = State(initialValue: model.preferences.daysPerWeek)
        _start = State(initialValue: Payroll.time(model.preferences.startMinutes))
        _end = State(initialValue: Payroll.time(model.preferences.endMinutes))
        _transparency = State(initialValue: Double(model.preferences.backgroundTransparency))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("你的上班小账本").font(.system(size: 22, weight: .semibold))
            Text("设置收入与时间，看看今天已经赚了多少。")
                .font(.system(size: 11)).foregroundColor(Palette.muted)
            VStack(alignment: .leading, spacing: 5) {
                Text("月收入（元）")
                TextField("月收入", text: $income).textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Picker("每周工作天数", selection: $days) {
                ForEach(1...7, id: \.self) { Text("\($0) 天").tag($0) }
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("上班时间")
                    TextField("09:00", text: $start).textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("下班时间")
                    TextField("18:00", text: $end).textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("背景透明度")
                    Spacer()
                    Text("\(Int(transparency))%").foregroundColor(Palette.gold).monospacedDigit()
                }
                Slider(value: $transparency, in: 0...100, step: 1)
                    .accentColor(Palette.gold)
                    .onChange(of: transparency) { model.previewTransparency = Int($0) }
                Text("0% 为不透明，100% 为背景全透明。文字与金额保持清晰。")
                    .font(.system(size: 10)).foregroundColor(Palette.muted)
            }
            Text("按全年平均工作日折算，全年扣除 13 天法定节假日。\n当天收入按上下班之间的整段时间累计。")
                .font(.system(size: 10)).foregroundColor(Palette.muted)
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.stone).cornerRadius(8)
            Text(errorText).font(.system(size: 11)).foregroundColor(Palette.red).frame(minHeight: 16)
            HStack {
                Text("配置保存在用户应用支持目录").font(.system(size: 10)).foregroundColor(Palette.muted)
                Spacer()
                Button("取消", action: cancel).keyboardShortcut(.cancelAction)
                Button("保存", action: saveValues).keyboardShortcut(.defaultAction)
            }
        }
        .font(.system(size: 12))
        .foregroundColor(Palette.ink)
        .padding(24)
        .frame(width: 440)
        .background(Palette.paper)
    }

    private func saveValues() {
        guard let amount = Payroll.parseIncome(income) else {
            errorText = "请输入有效的月收入。"
            return
        }
        guard let startMinutes = Payroll.parseTime(start), let endMinutes = Payroll.parseTime(end) else {
            errorText = "请使用 24 小时时间，例如 09:00、18:00。"
            return
        }
        var candidate = model.preferences
        candidate.monthlyIncome = amount
        candidate.daysPerWeek = days
        candidate.startMinutes = startMinutes
        candidate.endMinutes = endMinutes
        candidate.backgroundTransparency = Int(transparency)
        if let error = candidate.validationError { errorText = error; return }
        errorText = save(candidate) ?? ""
    }
}

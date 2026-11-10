# WorkFee · 下班倒计时

使用 SwiftUI 和 AppKit 编写的 macOS 桌面小工具。主界面突出今日已赚金额，以金色显示四位小数，并搭配红色收入进度条。

## 下载

在 [Releases](https://github.com/wehnes/workFee/releases/latest) 下载 `WorkFee-macOS-arm64.zip`，解压后打开 `WorkFee.app`。

适用于 Apple Silicon M 系列 Mac，最低系统版本为 macOS 12。

## 功能

- 自定义月收入、每周工作天数、上下班时间。
- 根据当天已工作时长计算实时收入，每秒重新计算。
- 下班倒计时、红色进度条和自适应窗口布局。
- 背景透明度从 0% 到 100%，支持预览、保存及取消恢复。
- 仅显示金额的置顶悬浮窗，支持拖动和缩放。
- 主窗口与悬浮窗分别记住大小和位置，启动时恢复上次模式。

在主窗口标题栏点击悬浮窗按钮切换模式。双击悬浮金额返回主窗口，右键可打开设置或退出。点击 Dock 图标也可返回主窗口。

## 计算方式

```text
平均每月工作天数 = [365 − (7 − 每周工作天数) × 52 − 13] ÷ 12
日工资 = 月收入 ÷ 平均每月工作天数
今日已赚 = 日工资 × 当天已工作时长 ÷ 每日工时
```

每日工时按上下班之间的整段时间计算。上班前收入为零，下班后停在当日工资。每天采用同样的规则，收入为娱乐性估算。

默认月收入 10,000 元，每周 5 天，09:00—18:00。配置保存在 `~/Library/Application Support/WorkFee/settings.json`。

## 本地构建

在 Mac 上安装兼容的 Apple 命令行工具或 Xcode 后执行以下命令。

```bash
swift test --configuration release --arch arm64
bash scripts/build.sh
open dist/WorkFee.app
```

GitHub Actions 在公开仓库的标准 macOS 构建机上编译、测试和打包。通过验证后，会发布应用压缩包、校验和及窗口验证截图。

## 首次运行

自动构建采用本地临时签名，尚未配置 Developer ID 签名及 Apple 公证。首次运行可能需要按照 macOS 提示，在“系统设置 → 隐私与安全性”中确认打开。

参见 [Apple 关于打开应用的说明](https://support.apple.com/102445)。

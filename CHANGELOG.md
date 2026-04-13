# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.10.0] - 2026-04-13

### Fixed
- 密码输入框被黑幕遮挡问题：弹出 NSAlert 前临时隐藏黑幕窗口，密码错误后自动恢复

## [1.9.0] - 2026-04-13

### Fixed
- 恢复原始自定义 Tab Bar 风格（VStack + 粉色按钮），放弃 macOS 原生 NavigationSplitView toolbar
- 「系统设置」作为第三个 Tab 按钮嵌入原有 Tab Bar
- 「下班」按钮常驻 Tab Bar 右侧，红色加粗，进入下班后变为橙色「取消下班」

## [1.8.0] - 2026-04-13

### Fixed
- 系统设置改为独立 Tab（第三个标签页），解决 sheet 方式不弹出的问题
- 「下班」按钮改为红色文字，常驻 toolbar 右侧

## [1.7.0] - 2026-04-13

### Added
- 系统设置面板（工具栏新增「系统设置」按钮，以 Sheet 弹出）
- 下班黑幕退出密码保护：在系统设置中配置密码，Esc 时需验证身份
- 未设置密码则无需输入，与原有行为兼容

## [1.6.0] - 2026-04-13

### Added
- 下班模式：一键触发全屏纯黑遮罩（Swift 原生封装，对应 oblack 逻辑）
- 下班模式防止系统休眠（NSProcessInfo.beginActivity，替代 caffeinate）
- 进入下班模式自动暂停所有提醒规则，退出时可选择是否恢复
- Menu Bar 菜单新增「下班 🌙」快捷项
- 设置面板工具栏新增「下班」按钮（状态感知，进入后变为「取消下班」）
- Esc 键退出下班模式，并弹窗询问是否恢复提醒计时

### Changed
- SettingsView 重构为单一 NavigationSplitView + toolbar Segmented Control
- 修复「当前状态」与「规则配置」两 Tab 的 header 高度不一致问题

## [1.5.0] - 2026-04-13

### Changed
- Removed Dock icon (back to Menu Bar only, LSUIElement)

## [1.4.0] - 2026-04-13

### Changed
- Interval minutes and duration seconds fields now support direct text input alongside the stepper

## [1.3.0] - 2026-04-13

### Added
- App now shows in both Dock and Menu Bar simultaneously
- Closing the settings window no longer quits the app (stays running in background)

## [1.2.0] - 2026-04-13

### Added
- 4 new light/soft overlay themes: 温柔杏, 少女粉, 马卡龙, 冷库冰蓝
- ThemeColors now supports light-background themes with adaptive text colors
- Theme preview cards show correct label colors for both dark and light themes

## [1.1.0] - 2026-04-13

### Added
- Multi-rule parallel timer engine
- Interval trigger mode (every N minutes)
- Scheduled trigger mode (fixed daily times, multiple allowed)
- 4 overlay themes: red-alarm, blue-calm, green-fresh, mono-minimal
- Full-screen overlay covering all screens and full-screen Spaces
- Real-time status dashboard with countdown progress bars
- Enter key backdoor (4 presses within 3s) to force-dismiss overlay
- Open-at-login via `SMAppService` (macOS 13+)
- Settings window hides on close (re-opens instantly)
- Automatic version management via `release.sh`
- DMG installer packaging

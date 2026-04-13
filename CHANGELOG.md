# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

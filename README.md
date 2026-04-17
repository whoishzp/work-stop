# Magicer

> 工作中断提醒 + 开发者工具箱 — macOS App

[![Version](https://img.shields.io/badge/version-1.69.0-blue.svg)](https://github.com/whoishzp/magicer/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/swift-5.9%2B-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Magicer 是一个轻量的 macOS 应用，同时提供**定时提醒**和**前端开发工具**两大核心功能模块，应用在 Dock 和 Menu Bar 中均常驻。

## 截图

> 安装后效果：Dock + Menu Bar 常驻 → 弹出全屏蒙层（覆盖所有屏幕） → 倒计时后可关闭

## 功能特性

### 定时提醒

- **多规则并行**：创建多条提醒规则，各自独立计时，互不干扰
- **提醒时机双模式**：「桌面提醒」全屏蒙层；「定时脚本」按同一套时间策略执行 Shell（`/bin/sh -c`），可配置日志目录，每次执行追加写入 `magicer-<规则UUID>.log`（标准输出与标准错误、退出码）；支持一键复制命令
- **循环提醒**：每隔 N 分钟触发一次，重启后自动恢复剩余倒计时（本地缓存）
- **定点提醒**：每天指定时刻触发，可配置多个时刻
- **一次提醒**：选择指定时刻，触发一次后自动停用；关闭蒙层后还可配置「跟进提醒」在 N 分钟后再次弹出
- **跟进提醒**：任意触发模式均可配置关闭蒙层后 N 分钟自动补发一次（0 = 不跟进）
- **8 套蒙层主题**：黑白极简 / 深蓝平静 / 深红警告 / 深绿清新 / 粉嫩可爱 / 马卡龙 / 冰霜冷调 / 温柔晚霞
- **主题预览**：规则编辑时可实时预览各主题蒙层效果
- **全屏蒙层**：弹窗覆盖所有屏幕及扩展屏，切换桌面（Space）后自动抢回焦点，优先级高于所有窗口
- **倒计时锁定**：可设置弹窗最短停留时长（0 = 随时可关）
- **Enter 后门**：弹窗期间 3 秒内连按 Enter 4 次，强制显示关闭按钮
- **实时状态面板**：查看每条规则距下次触发的倒计时与进度条

### 下班模式

- 点击右上角「下班」按钮，全屏黑幕遮屏，暂停所有提醒
- 防止系统休眠（`ProcessInfo.beginActivity`）
- 可选密码保护退出（系统设置中配置）
- 黑屏上有漂浮的动态眼睛动画，多个眼睛以物理碰撞方式自由移动
- 退出时自动恢复已暂停的提醒规则

### 系统设置

- **开机自启**：原生 `SMAppService` 实现
- **下班密码**：可设置/修改/清除密码，支持纯空格及任意字符
- **启动命令**：App 启动时自动执行配置的 Shell 命令（可配置多条，各自启用/禁用）；每条可一键复制完整 shell 到剪贴板（复制后柔和提示，成功约 3 秒 / 失败约 5 秒）、一键立即执行；手动执行结束后显示柔和提示条（约 6 秒后淡出，含退出码或错误摘要）
- **下班快捷键**：自定义全局键盘快捷键（需含修饰键），在任意应用中均可触发下班/取消下班

### Fe 助手（开发者工具）

| 工具 | 功能 |
| --- | --- |
| JSON 美化 | 树形展开/折叠视图、嵌套 JSON 字符串自动解析展开、悬停复制整个节点子树 JSON、叶子节点鼠标框选复制、复制全部 |
| JSON 比对 | 双面板可直接编辑、自动格式化、黄色高亮差异行 |
| 信息编码转换 | Unicode/URL/Base64/MD5/SHA1/HEX/HTML/JWT/Cookie 等 18 种操作 |
| 时间(戳)转换 | 智能解析多种格式、实时当前时间、快捷操作、双击复制 |

## 系统要求

| 项目 | 要求 |
| --- | --- |
| macOS | 13.0 (Ventura) 或更高 |
| 架构 | Apple Silicon / Intel |

## 安装

### 方式一：下载安装包（推荐）

1. 前往 [Releases](https://github.com/whoishzp/magicer/releases) 下载最新 `.dmg`
2. 打开 DMG，将 `Magicer.app` 拖入 `Applications` 文件夹
3. 首次运行时在「系统设置 → 安全性 → 仍然打开」允许

### 方式二：从源码构建

```bash
git clone git@github.com:whoishzp/magicer.git
cd magicer
./build.sh
open Magicer.app
```

## 使用

1. 启动后自动打开设置窗口（Dock + Menu Bar 均常驻图标）
2. **定时提醒**：新增规则，配置触发方式（循环/定点/一次）、蒙层主题和停留时长，可选跟进提醒
3. **当前状态**：实时查看各规则倒计时进度
4. **下班模式**：点击右上角「下班」按钮（或 Fe 助手工具栏快捷按钮）进入全屏黑幕模式；可在系统设置配置全局快捷键
5. **系统设置**：配置开机自启、下班密码、启动命令、下班全局快捷键
6. **Fe 助手**：4 个前端开发工具横向切换
7. 关闭设置窗口不退出应用，随时从 Menu Bar 或 Dock 重新打开

## 开发

### 环境依赖

- Xcode Command Line Tools（`xcode-select --install`）
- Swift 5.9+
- macOS 13+（编译目标）

### 构建

```bash
# Debug 编译
swift build

# Release 打包（更新 VERSION 后执行）
./release.sh
```

### 目录结构

```
magicer/
├── Sources/
│   ├── App/
│   │   ├── main.swift                   # App 入口（Dock + Menu Bar）
│   │   ├── AppDelegate.swift            # 窗口管理 + 生命周期
│   │   ├── MenuBarManager.swift         # 状态栏图标 + 菜单
│   │   ├── HideOnCloseWindow.swift      # 隐藏式关闭窗口
│   │   ├── HotkeyManager.swift          # 全局快捷键监听（下班模式）
│   │   ├── StartupCommandRunner.swift   # 启动命令执行器（含手动执行结果结构）
│   │   └── ScheduledScriptExecutor.swift # 定时脚本规则执行 + 文件日志
│   ├── Models/
│   │   ├── ReminderRule.swift           # 提醒规则数据模型
│   │   ├── RulesStore.swift             # 规则持久化 (UserDefaults)
│   │   ├── Theme.swift                  # 8 套蒙层主题 + 布局定义
│   │   ├── AppSettings.swift            # 全局设置模型
│   │   ├── OffWorkShortcut.swift        # 下班快捷键数据模型
│   │   └── StartupCommand.swift         # 启动命令数据模型
│   ├── Timer/
│   │   └── RuleTimerManager.swift       # 多规则并行计时引擎（含缓存恢复）
│   ├── Overlay/
│   │   ├── OverlayManager.swift         # 全屏蒙层管理 + 键盘监听
│   │   ├── OverlayLayouts.swift         # 8 种蒙层布局实现
│   │   └── CloseButtonView.swift        # 自定义关闭按钮
│   ├── OffWork/
│   │   ├── OffWorkManager.swift         # 下班模式逻辑 + 密码验证
│   │   ├── OffWorkState.swift           # 下班状态 ObservableObject
│   │   └── ScanningEyesView.swift       # 物理碰撞浮动眼睛动画
│   └── Settings/
│       ├── SettingsView.swift           # 主设置窗口（左侧导航栏）
│       ├── ReminderView.swift           # 定时提醒（状态+规则子 Tab）
│       ├── StatusView.swift             # 状态卡片 + 实时倒计时
│       ├── System/
│       │   └── AppSettingsView.swift    # 系统设置页
│       ├── Rules/
│       │   ├── RuleEditView.swift       # 规则编辑（桌面/脚本切换 + 内联面板）
│       │   ├── DesktopTimingPanel.swift # 桌面提醒：触发方式 + 跟进/时长
│       │   ├── ScheduledScriptTimingPanel.swift # 定时脚本：触发 + 命令 + 日志目录
│       │   └── ThemeCard.swift          # 主题选择卡片
│       ├── Preview/
│       │   └── ThemePreviewView.swift   # 蒙层主题预览
│       └── FeHelper/
│           ├── FeHelperView.swift       # Fe 助手主容器
│           ├── JsonBeautifyView.swift   # JSON 美化工具
│           ├── JsonDiffView.swift       # JSON 对比工具
│           ├── JsonEditorPanel.swift    # 可编辑语法高亮面板
│           ├── JsonSyntaxHighlighter.swift # JSON 语法着色
│           ├── EncodingView.swift       # 信息编码转换工具
│           └── TimestampView.swift      # 时间(戳)转换工具
├── Resources/
│   └── AppIcon.icns
├── Info.plist
├── Package.swift
├── VERSION
├── build.sh                             # 编译 + 打包 .app
└── release.sh                           # 升版 + 打包 DMG（仅保留最新）
```

### 版本管理

每次修改代码后：

```bash
# 1. 修改 VERSION 文件
echo "1.48.0" > VERSION

# 2. 打包发布（自动清理旧 DMG，生成新安装包）
./release.sh

# 3. 推送
git add -A && git commit -m "release: v1.48.0" && git push
git tag v1.48.0 && git push origin v1.48.0
```

## 变更日志

### v1.69.0（2026-04-17）

- **JSON 美化**：兼容 JSON 字符串转义格式输入（内容含字面量 `\n`、`\"` 等转义序列时自动反转义后再解析，无需手动处理）

### v1.68.0（2026-04-17）

- **定时提醒**：修复新建规则后立即弹出蒙层的问题 — 无历史触发时间的新规则现在从创建时刻开始计时，等待完整间隔后才首次触发

### v1.67.0（2026-04-17）

- **JSON 美化**：新增嵌套 JSON 字符串自动解析，string 类型字段若内容为合法 JSON 对象/数组，自动递归展开为可交互树节点（兼容 `callback_column` 等转义场景）

### v1.66.0（2026-04-17）

- **定时提醒**：「提醒时机」改为「桌面提醒 / 定时脚本」双按钮；桌面配置与脚本配置拆成独立内联面板
- **定时脚本**：三种触发方式（循环 / 定点 / 一次）与桌面一致；多行 Shell 编辑、复制命令、选择日志目录；执行日志按规则写入目录下 `magicer-<UUID>.log`
- **数据模型**：`ReminderRule` 新增 `actionKind`、`shellCommand`、`logDirectoryPath`；HTTP API / Skill 导出同步说明

### v1.65.0（2026-04-16）

- **启动命令**：复制 shell 后显示与执行反馈同风格的提示条（成功约 3 秒 / 失败约 5 秒自动消失）；失败时提示重试
- **Cursor 规则**：`.cursor/rules/magicer.mdc` 增加「Cursor Good 强制」条款，要求在本仓库工作时遵循 `~/.cursor/rules/main.mdc` 的 CursorGood MCP 闭环

### v1.64.0（2026-04-16）

- **启动命令一键复制**：已配置命令行增加「文档」图标按钮，点击将完整 shell 正文写入系统剪贴板

### v1.63.0（2026-04-16）

- **启动命令**：移除「执行记录」列表与本地持久化，仅保留手动执行后的柔和提示条；启动时仍静默执行（失败写入系统日志）
- 首次启动时清除遗留的 `ws_startup_command_logs` 数据

### v1.62.0（2026-04-16）

- **启动命令执行记录**：每次启动时与手动播放均写入日志（时间、来源「启动/手动」、标签、成功/失败、退出码或错误摘要），列表可滚动查看，支持清空
- **手动执行反馈**：完成后在列表上方显示非模态提示条（成功绿色 / 未成功橙色），约 6 秒自动消失，并引导查看执行记录
- `StartupCommandRunner`：`waitUntilExit` 后记录退出码；`AppSettings` 持久化 `ws_startup_command_logs`

### v1.61.0（2026-04-16）

- **启动命令一键执行**：系统设置「启动执行命令」列表每行增加播放按钮，点击后立即在后台执行该条 shell（与启动时逻辑一致，不阻塞界面）

### v1.60.0（2026-04-15）

- **Carbon 全局快捷键**：新增 `CarbonBridge` C 扩展模块，通过 `InstallApplicationEventHandler` + `RegisterEventHotKey` 实现真正无权限全局热键
- 放弃 `NSEvent.addGlobalMonitorForEvents` + Input Monitoring 方案（macOS 15 下授权后仍不可靠）
- `CarbonHotkeyManager` 改为纯 C 桥接调用，兼容 Swift-C 混合 SPM 多 target 编译
- 移除系统设置「输入监控」权限提示 UI（Carbon 方案不需要任何额外权限）
- `Package.swift` 新增 `CarbonBridge` 静态库 target，链接 Carbon.framework

### v1.59.0（2026-04-15）

- 全局快捷键同时注册 global+local monitor：app 在后台和前台均可触发
- 录制模式激活时标记 `isAnyRecording`，避免录制期间误触发已配置的快捷键
- 系统设置快捷键区块增加「输入监控」权限状态提示：无权限时显示橙色警告条 + 「前往设置」按钮
- `HotkeyManager.start()` 启动时自动调用 `CGRequestListenEventAccess()` 申请输入监控权限

### v1.58.0（2026-04-15）

- 系统设置「全局快捷键」区块新增两条独立快捷键配置：「下班模式」和「Fe 助手」
- 录制逻辑重写：使用 `NSEvent.addLocalMonitorForEvents`，点击「录制」后直接按组合键即可，Esc 取消，支持重新录制和清除
- Fe 助手全局快捷键：在任意程序中按下后自动将设置窗口置顶并切换到 Fe 助手 Tab
- 下班模式全局快捷键：在任意程序中按下后触发进入/退出下班黑幕（应用后台同样生效）
- 移除 Fe 助手工具栏中误加的「下班」快捷按钮（功能已统一在系统设置 + 主窗口工具栏管理）

### v1.57.0（2026-04-15）

- Fe 助手工具栏新增「下班」快捷按钮，当前快捷键可见时直接显示键位
- 系统设置新增「下班快捷键」区块：点击「录制」按下任意组合键（含修饰键）完成设置，支持清除；快捷键存入 `UserDefaults`，重启自动恢复
- 新增 `HotkeyManager`：监听全局键盘事件，匹配快捷键后自动触发下班/取消下班（应用在后台时同样生效）
- 新增 `OffWorkShortcut` 数据模型（`Codable`），负责快捷键序列化与展示字符串（⌘⇧D 等）

### v1.56.0（2026-04-14）

- 新增嵌入式 HTTP Server（`127.0.0.1:18879`）：实现完整 CRUD API（`GET /reminders`、`POST /reminders`、`PUT /reminders/{id}/toggle`、`DELETE /reminders/{id}`），AI Agent 可通过 curl 直接读写提醒规则
- 定时提醒右上角新增「安装 Skill」按钮：一键同时写入 Cursor（`~/.cursor/skills/magicer-reminders/SKILL.md`）和 Claude（`~/.claude/CLAUDE.md` 标记块），支持重复安装（幂等更新）
- 安装结果细分三态：全部成功 / 部分成功 / 失败，颜色区分

### v1.55.0（2026-04-14）

- 移除定时提醒页面「导出 Skill」按钮（Skill 文件已在规则变更时自动同步，无需手动触发）

### v1.54.0（2026-04-14）

- 全屏覆盖根本修复：参考 cursor-stop 三要素 — 恢复 `.transient`、改用 `orderFrontRegardless()`、弹出时临时切换激活策略为 `.accessory`（不占 Space），关闭后恢复 `.regular`
- 下班模式同步应用以上策略

### v1.53.0（2026-04-14）

- 修复全屏蒙层白框：`NSTextField` label 强制 `drawsBackground = false / backgroundColor = .clear`
- 全屏覆盖进一步加固：去掉 `.transient`（该 flag 会在 Mission Control 切换时隐藏窗口），窗口层级提升至 `screenSaver + 200`
- 新增 MCP 服务：Magicer 内嵌 HTTP server（127.0.0.1:18879），AI Agent 可通过 `cursor/magicer_mcp.py` 读写提醒规则
- 提醒规则编辑页新增**时间冲突检测**：定点/一次提醒时间与其他规则冲突时展示橙色内联警告

### v1.52.0（2026-04-14）

- 修复历史提醒规则升级后丢失的问题（自定义 Codable decoder 向后兼容新字段）
- 全屏蒙层覆盖扩展屏 full-screen Space：改用 `OverlayNSWindow`（重写 `canBecomeKey`）+  `makeKeyAndOrderFront` + 0.35s 延迟重试
- JSON 美化工具重写为**树形视图**：展开/折叠节点、悬停复制节点完整子树 JSON、叶子节点文本可框选
- 新增 `JsonTreeView.swift` 组件

### v1.51.0（2026-04-14）

- 定时提醒新增**一次提醒**触发方式：选定时刻触发一次后自动停用
- 所有触发方式支持**跟进提醒**：关闭蒙层后 N 分钟补发一次（0 = 不跟进）
- 全屏蒙层切换桌面（Space）后自动抢回焦点（`activeSpaceDidChangeNotification`）
- 下班模式同步支持切桌面后焦点恢复
- 面板打开时 Cmd+Q 只关闭面板，不退出应用
- JSON 美化支持行内鼠标框选复制（`.textSelection(.enabled)`）

### v1.47.0（2026-04-14）

- JSON 比对面板底部加内边距，UI 美观改进
- JSON 比对支持粘贴自动格式化
- 时间工具布局调整：当前时间置顶，解析结果置底
- 解析结果行支持双击复制 + Toast 提示，移除复制按钮
- 循环提醒本地缓存：重启后自动恢复剩余倒计时
- 状态栏图标修复（variableLength）
- 修复时间戳计算 Int 溢出崩溃（改用 Int64 + 边界校验）
- 所有按钮热区修复（contentShape + opacity 替代 Color.clear）

### v1.31.0（2026-04-13）

- 合并「当前状态」和「规则配置」为「定时提醒」（内含子 Tab）
- 新增「信息编码转换」工具（18 种操作，FeHelper 风格）
- 时间戳工具优化：智能解析器 + 双击复制

### v1.27.0（2026-04-12）

- 新增「Fe 助手」模块：JSON 美化、JSON 比对、信息编码转换、时间(戳)转换
- 侧边导航栏新增 Fe 助手入口

### v1.22.0（2026-04-12）

- 项目更名：WorkStop → **Magicer**
- 功能模块调整为左侧纵向导航栏
- 新增启动执行命令配置
- 迁移 git 仓库至 magicer

### v1.15.0（2026-04-11）

- 8 套蒙层主题，各主题有独特布局设计
- 下班模式黑屏动态眼睛（物理碰撞浮动）
- 蒙层主题预览功能

### v1.6.0（2026-04-11）

- 新增「下班」模式（全屏黑幕 + 防睡眠 + 暂停规则）
- 新增系统设置（下班密码）

### v1.1.0（2026-04-10）

- 初始发布
- 多规则并行计时
- 循环 + 定点两种触发模式
- 实时状态面板 + Enter 键后门
- 开机自启支持

## License

[MIT](LICENSE)

---

> 灵感来自 [cursor-stop](https://github.com/whoishzp/cursor-stop)

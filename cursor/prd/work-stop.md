# work-stop — 工作中断提醒 Mac 应用

## 进度概览

| 步骤 | 标题 | 状态 |
|---|---|---|
| 步骤一 | 项目方案设计 | ✅ 已完成 |
| 步骤二 | 核心功能实现 | ⬜ 未开始 |
| 步骤三 | 设置页 UI | ⬜ 未开始 |
| 步骤四 | 打包发布 | ⬜ 未开始 |

---

## 一、需求概述

独立 macOS 应用，无需 VSCode/Cursor 宿主，系统启动后后台常驻（Menu Bar App）。

### 已确认需求

| # | 需求 | 确认结论 |
|---|---|---|
| 1 | 开机自启 | **必须有** |
| 2 | 提示时长最小值 | **0 秒**（`canCloseImmediately = true` 时立即可关） |
| 3 | 多屏幕行为 | **所有屏幕均显示蒙层** |
| 4 | 蒙层风格 | **设计多套主题，配置中可选** |
| 5 | 多组配置 | **支持多个提醒规则并行运行** |

### 单条提醒规则配置项

| 配置项 | 说明 | 默认值 |
|---|---|---|
| 规则名称 | 自定义名称（如"专注计时"） | "提醒 1" |
| 提示时间（间隔） | 每隔多少分钟触发一次提醒 | 60 分钟 |
| 提示时长 | 弹窗最短显示多少秒（0 = 随时可关） | 10 秒 |
| 提示文字 | 弹窗正文自定义文案 | "该休息了，离开屏幕活动一下。" |
| 是否可立即关闭 | true = 随时可关；false = 倒计时后才出现关闭按钮 | false |
| 主题风格 | 见下方风格列表 | 深红警告 |
| 启用/停用 | 单独开关 | 启用 |

### 蒙层主题风格（4 套）

| 主题 ID | 名称 | 背景色 | 主色 | 风格描述 |
|---|---|---|---|---|
| `red-alarm` | 深红警告 | `#08000E` | `#FF3434` | cursor-stop 原版风格，强烈警示感 |
| `blue-calm` | 深蓝平静 | `#020A1A` | `#4A9EFF` | 蓝色调，较温和 |
| `green-fresh` | 深绿清新 | `#021008` | `#3DC46A` | 绿色调，放松感 |
| `mono-minimal` | 黑白极简 | `#111111` | `#EEEEEE` | 无彩色，低干扰 |

---

## 二、技术方案 ✅ 已完成

### 整体架构

```
work-stop/
├── WorkStop.xcodeproj/
├── WorkStop/
│   ├── WorkStopApp.swift        # @main 入口 + 开机自启注册
│   ├── AppDelegate.swift        # Menu Bar 图标 + 窗口管理
│   ├── Settings/
│   │   ├── SettingsView.swift   # 设置主页（规则列表）
│   │   ├── RuleEditView.swift   # 单条规则编辑页
│   │   └── ThemePickerView.swift# 主题选择组件
│   ├── Timer/
│   │   └── RuleTimerManager.swift  # 多规则并行计时引擎
│   ├── Overlay/
│   │   └── OverlayWindow.swift  # 全屏蒙层（复用 cursor-stop 方案 + 多主题）
│   └── Models/
│       ├── ReminderRule.swift   # 单条规则数据模型（Codable）
│       └── Theme.swift          # 主题颜色定义
├── build.sh
└── README.md
```

### 技术选型

| 模块 | 技术 | 理由 |
|---|---|---|
| 整体框架 | SwiftUI + AppKit | macOS 原生，设置页用 SwiftUI，覆盖层用 AppKit NSWindow |
| 构建 | Xcode Project | 生成正规 .app bundle，支持 Dock/Menu Bar |
| 配置持久化 | UserDefaults（JSON encode `[ReminderRule]`） | 支持多条规则序列化 |
| 多规则计时 | `[UUID: Timer]` 字典，每条规则独立 Timer | 规则增删时动态管理 |
| 弹窗覆盖 | NSWindow per screen (level: .screenSaver+100) | 复用 cursor-stop 方案，所有屏幕全显 |
| 开机自启 | `SMAppService.mainApp.register()` (macOS 13+) | 系统原生 API，不需要 LaunchAgent plist |

### Menu Bar App 方案

- `LSUIElement = YES`（Info.plist）→ 无 Dock 图标，只在状态栏显示
- 状态栏 Menu 含：「查看状态」「立即触发」「打开设置」「退出」
- 设置页点击后弹出独立 NSWindow，SwiftUI Form 渲染

### 全屏蒙层（复用 cursor-stop）

cursor-stop 已验证的 Swift 全屏蒙层核心逻辑直接复用：

```swift
// 关键参数透传
win.level = NSWindow.Level(rawValue: Int(NSWindow.Level.screenSaver.rawValue) + 100)
win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
```

差异点：
- 弹窗文字改为读取 UserDefaults `reminderText`
- `closeDelaySeconds = 0` 时立即显示关闭按钮（是否可关闭）
- 不再需要 `workMinutes` 写死，从 Settings 读取

### 多规则计时逻辑

```
App 启动 → RuleTimerManager.start(rules)
  ┣ Rule A → Timer A（每 intervalMinutes 分钟触发）→ OverlayWindow(theme=red-alarm)
  ┣ Rule B → Timer B（每 30 分钟触发）→ OverlayWindow(theme=blue-calm)
  └ Rule C → Timer C（已禁用，跳过）

用户关闭弹窗 → 对应 Timer 重置，不影响其他 Timer
用户在设置页增/改/删规则 → RuleTimerManager 热更新对应 Timer
```

无需监听键盘/鼠标，纯绝对时间间隔触发。

### 设置页交互流程

```
设置主页
  ├── 规则列表（每行: 名称 + 间隔 + 启用开关）
  ├── [+] 新增规则
  └── 点击某行 → 规则编辑页
       ├── 规则名称
       ├── 提示间隔（分钟）
       ├── 提示时长（秒，0 = 随时可关）
       ├── 是否可立即关闭（toggle）
       ├── 提示文字（多行文本框）
       ├── 主题选择（4 个色块卡片）
       └── 保存 / 删除
```

---

## 三、目录约定

```
/Users/mader/Documents/work-stop/   ← 项目根
```

---

## 四、疑问点（已全部确认）

> Q1：是否需要「开机自启」功能？**答：必须有**

> Q2：提示时长最小值是多少秒？**答：0（随时可关）**

> Q3：多屏幕时是否所有屏幕都显示蒙层？**答：所有屏幕**

> Q4：图标/蒙层风格设计？**答：提供多套主题，配置页可选（已设计 4 套：深红/深蓝/深绿/极简）**

> Q5：是否支持多组配置？**答：支持，配置页可增删多条提醒规则，并行运行**

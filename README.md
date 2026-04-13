# WorkStop — 工作中断提醒

一个轻量的 macOS Menu Bar 应用，定时弹出全屏提醒蒙层，帮助你养成规律休息的习惯。

## 功能

- **多规则并行**：配置多条提醒规则，各自独立计时
- **循环提醒**：每隔 X 分钟触发一次
- **定点提醒**：每天指定时刻触发（可配置多个时刻）
- **4 套蒙层主题**：深红警告 / 深蓝平静 / 深绿清新 / 黑白极简
- **全屏覆盖**：弹窗覆盖所有屏幕及全屏 Space
- **倒计时锁定**：可设置强制停留时长，或随时关闭
- **Enter 后门**：弹窗期间连按 Enter 4 次强制显示关闭按钮
- **开机自启**：设置后随系统自动启动

## 安装

1. 下载 `dist/WorkStop-latest.dmg`
2. 双击打开 DMG
3. 将 `WorkStop.app` 拖入 `Applications` 文件夹
4. 从 Applications 启动 WorkStop

## 开发

**环境要求**：macOS 13+，Swift 5.9+，Xcode Command Line Tools

```bash
# 编译（debug）
swift build

# 打包发布（更新 VERSION 文件后运行）
./release.sh
```

## 版本

当前版本见 `VERSION` 文件。每次修改后运行 `release.sh` 自动升版打包。

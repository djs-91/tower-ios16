# 塔台 Tower — iOS 16 移植版构建说明

本项目已从 iOS 17 最低版本移植到 **iOS 16.0**（针对 iOS 16.5 越狱 + TrollStore 设备）。
本文件说明在 macOS + Xcode 上如何构建出可用于侧载的 IPA。

## 移植内容摘要

原始仓库 (https://github.com/pengchujin/tower) 的 `IPHONEOS_DEPLOYMENT_TARGET` 已从
17.0 改为 16.0（全部 8 处 build configuration）。以下 iOS 17 专属 API 已被替换或降级：

| iOS 17 API | 处理方式 | 功能影响 |
|---|---|---|
| `@Observable` / `Observation` / `@ObservationIgnored` | `AppModel` 改为 `ObservableObject` + `@Published`（72 个属性） | 无（同样驱动 UI 刷新） |
| `@Environment(AppModel.self)` | `@EnvironmentObject` | 无 |
| `.environment(model)` | `.environmentObject(model)` | 无 |
| `@Bindable` (TowerApp) | 普通属性 + `$model` 绑定 | 无 |
| `@Entry` (TowerTheme) | 普通 `EnvironmentValues` extension + computed var | 无 |
| `.sensoryFeedback(...)` ×19 | `.sensoryFeedback16()` no-op shim | 触觉反馈不可用 |
| `.contentTransition(...)` ×18 | `.contentTransition16()` no-op | 数字滚动等过渡动画不可用 |
| `.symbolEffect(...)` ×3 | `.symbolEffect16()` no-op | 图标动效不可用 |
| `.geometryGroup()` ×6 | `.geometryGroup16()` no-op | 个别复杂布局动画可能略有差异 |
| `.scrollBounceBehavior` | `.scrollBounceBehavior16()` no-op | 无 |
| `.scrollTargetBehavior` / `.scrollContentBackground` | `*16()` no-op | 无 |
| `ContentUnavailableView` ×7 | `TowerContentUnavailableView`（自绘同布局） | 视觉接近系统版 |
| `PhaseAnimator`（WelcomeView） | `PhaseDriver`（定时步进） | 动画节奏近似 |
| `KeyframeAnimator` ×2（WelcomeView） | 直接到达最终状态的 spring/ease 动画 | 飞入弧线动画简化 |
| `MagnifyGesture` | shim：`MagnificationGesture` + `Value{magnification,startAnchor}` | 无 |
| `SpatialTapGesture` | shim：零距离 `DragGesture` 提供 `value.location` | 无 |
| `OSAllocatedUnfairLock` | shim：`os_unfair_lock` 封装 | 无 |
| `withAnimation(_:completionCriteria:completion:)` ×5 | `withAnimation16(_:completion:)`（下一 runloop 触发） | 完成时机近似 |
| `onGeometryChange` ×3 | `onGeometryChange16`（GeometryReader 背景测量）/ 常驻预热 | 无 |
| `onChange(of:) { old, new in }` ×25 | iOS 16 单参数形式 | 无 |
| `onChange(of:, initial: true)` | `onAppear` + `onChange` | 无 |
| `IndexPath(row:section:)` | `IndexPath(index:)` | 无 |
| `NWParameters.PrivacyContext`（DoH 强制） | `#available(iOS 17,*)` 门控 | iOS 16 上 DoH 强制解析不可用（走系统 DNS） |
| `.tabViewStyle(.page(indexDisplayMode:))` | `PageTabViewStyle(indexDisplayMode:)` | 无 |
| `.smooth/.snappy` 动画 | `.easeInOut` / `.spring(response:dampingFraction:)` | 动画手感近似 |
| `.symbolRenderingMode(.hierarchical)` | `.monochrome` | 图标单色 |
| `Button(role: .destructive)` | `Button {} label: {}` + `.foregroundColor(.red)` | 等效 |

**iOS 16 上不可用的功能**：触觉反馈、iOS 17 视觉过渡/符号动效、强制 DoH 解析。
**其余功能全部保留**（订阅管理、节点、规则、导出、iCloud 同步等）。

## macOS 构建步骤

要求：Xcode 15+（建议 15.4 或 16.x，仓库原要求 26+ 是为了 iOS 17 SDK，16 目标用 15 即可）、
免费或付费 Apple ID（TrollStore 安装不需要开发者账号签名）。

```bash
# 1. 解包
unzip tower-ios16.zip
cd tower-ios16

# 2. 打开工程
open Tower.xcodeproj

# 3. Xcode 里：
#    - 签名页把 Team 设为你的 Personal Team（TrollStore 安装其实可以随意签）
#    - 目标 iOS 16.0 已设置好（IPHONEOS_DEPLOYMENT_TARGET = 16.0）
#    - 选 Generic iOS Device
#    - Product > Archive

# 4. 导出 IPA（不打 App Store 签名）：
#    Organizer > Distribute App > Custom > 直接导出
#    （或命令行：）
xcodebuild -project Tower.xcodeproj -scheme Tower -configuration Release \
    -destination 'generic/platform=iOS' -archivePath build/Tower.xcarchive archive
# 然后从 Tower.xcarchive/Products/Applications/ 取 Payload/Tower.app 打包：
cd build/Tower.xcarchive/Products/Applications
mkdir Payload && cp -R Tower.app Payload/
zip -r Tower-iOS16.ipa Payload
```

## TrollStore 安装

1. 把 `Tower-iOS16.ipa` 传到手机（AirDrop/文件/网页皆可）。
2. TrollStore 里选 "Install IPA" 安装。
3. 无需重签：TrollStore 用 CoreTrust 绕过签名校验。

## 测试要点

- 首次启动：onboarding（WelcomeView 的动画已简化，应能正常走完）
- 订阅导入 / 节点列表 / 规则目录 / 导出（presentationDetents 是 iOS 16 API，正常）
- 地图视图（WorldDotMapView：MagnifyGesture/SpatialTapGesture 已桥接）
- 已知无害警告：`CardSwipeRow` 的 UITableView 配置方式不变，iOS 16 正常。

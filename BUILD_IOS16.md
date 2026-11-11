# 塔台 Tower — iOS 16 移植版构建说明

当前基线：上游 [pengchujin/tower](https://github.com/pengchujin/tower) **v1.0.31 (73)**，移植到 **iOS 16.0**（针对 iOS 16.5 越狱 + TrollStore 设备）。
本文件说明这套移植改了什么、以及如何构建出可用于侧载的 IPA。

## 移植内容摘要

工程 `IPHONEOS_DEPLOYMENT_TARGET` 已从 17.0 改为 16.0（全部 8 处 build configuration），
版本号与上游一致（MARKETING 1.0.31 / CURRENT 73）。以下 iOS 17 专属 API 已被替换或降级：

| iOS 17 API | 处理方式 | 功能影响 |
|---|---|---|
| `@Observable` / `Observation` / `@ObservationIgnored` | `AppModel` 等改为 `ObservableObject` + `@Published`（59 处属性） | 无（同样驱动 UI 刷新） |
| `@Environment(AppModel.self)` | `@EnvironmentObject` | 无 |
| `.environment(model)` | `.environmentObject(model)` | 无 |
| `@Bindable` (TowerApp) | 普通属性 + `$model` 绑定 | 无 |
| `@Entry` (TowerTheme) | 普通 `EnvironmentValues` extension + computed var | 无 |
| `.sensoryFeedback(...)` ×18 | 整条移除（iOS 16 无等价 API） | 触觉反馈不可用 |
| `.symbolEffect(...)` ×3 | 改写为 `.contentTransition(.opacity)` | 图标动效不可用 |
| `.contentTransition(.numericText)` | `.contentTransition(.opacity)` | 数字滚动过渡简化 |
| `.geometryGroup()` ×6 | 整行移除（无 iOS 16 等价物） | 个别复杂布局动画可能略有差异 |
| `.menuActionDismissBehavior(...)` ×2 | 整条移除 | 菜单动画期间不再抑制抖动 |
| `.scrollBounceBehavior` | no-op | 无 |
| `.onGeometryChange` ×3 | `onGeometryChange16`（GeometryReader 背景测量）/ 常驻预热 | 无 |
| `ContentUnavailableView` ×9 | `TowerContentUnavailableView`（自绘同布局） | 视觉接近系统版 |
| `PhaseAnimator`（WelcomeView） | `PhaseDriver`（定时步进） | 动画节奏近似 |
| `KeyframeAnimator` ×2（WelcomeView） | 直接到达最终状态的 spring/ease 动画 | 飞入弧线动画简化 |
| `MagnifyGesture` | 改用 `MagnificationGesture`（value 为 CGFloat，配合自存起始 viewport 计算缩放） | 无 |
| `SpatialTapGesture` | iOS 16.0 起原生可用，未做改动 | 无 |
| `OSAllocatedUnfairLock` | iOS 16.0 起原生可用，未做改动 | 无 |
| `withAnimation(_:completionCriteria:completion:)` ×5 | `withAnimation16`（下一 runloop 触发，token 守卫收尾） | 完成时机近似 |
| `navigationDestination(item:)` ×2 | `navigationDestination16`（RouteBox 包装） | 无 |
| `.toolbar(.navigationBarTitleDisplayMode…)` 等 17-only 重载 | `toolbar16` 显式泛型重载 | 无 |
| `.accessibilityAddTraits(.isToggle)` | 移除（17-only trait） | 无 |
| `onChange(of:) { old, new in }` ×33 | iOS 16 单参数形式（仅一处旧值读取补 `@State` 记录） | 无 |
| `onChange(of:, initial: true)` | `onAppear` + `onChange` | 无 |
| `NWParameters.PrivacyContext`（DoH 强制） | `#available(iOS 17,*)` 门控 | iOS 16 上 DoH 强制解析不可用（走系统 DNS） |
| `.tabViewStyle(.page(indexDisplayMode:))` | `PageTabViewStyle(indexDisplayMode:)` | 无 |
| `.smooth/.snappy` 动画 | `.easeInOut` / `.spring(response:dampingFraction:)` | 动画手感近似 |

兼容层集中在 `Tower/Design/iOS16Compat.swift` 与 `Tower/Design/ContentUnavailableView16.swift`。
上游 `TowerTests` 中 6 处「读源码断言 iOS 17 API 存在」的守卫同步改为断言移植形态
（`navigationDestination16` 等），其余测试文件保持上游原样；CI 归档不跑测试，但本地
跑 `TowerTests` 应全绿。

版本跟进：1.0.30 (71) → 1.0.31 (73) 都是产品侧改动，上游新增的 Swift 代码没有引入新的 iOS 17 API，本次升级未新增降级项，只把版本号与部署目标对齐。

**iOS 16 上不可用的功能**：触觉反馈、iOS 17 视觉过渡/符号动效、强制 DoH 解析。
**其余功能全部保留**（订阅管理、节点、规则、导出、iCloud 同步等）。

## 构建步骤（本仓库 CI）

`.github/workflows/build-ios16-ipa.yml`：macos-15 + Xcode 16，`xcodebuild archive`
后把 `Payload/Tower.app` 打成 `Tower-iOS16.ipa` 上传为 Actions artifact
（名字 `tower-ios16`），并把构建日志推到 `buildlog` 分支。
Release 页（tag `v<版本>-ios16`）挂同一份 IPA。

本地构建（macOS）：

```bash
git clone https://github.com/djs-91/tower-ios16 && cd tower-ios16
xcodebuild -project Tower.xcodeproj -scheme Tower -configuration Release \
    -destination 'generic/platform=iOS' -archivePath build/Tower.xcarchive archive
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
- 地图视图（WorldDotMapView：放大手势已桥接为 `MagnificationGesture`，点按用 iOS 16 原生的 `SpatialTapGesture`）
- 已知无害警告：`CardSwipeRow` 的 UITableView 配置方式不变，iOS 16 正常。

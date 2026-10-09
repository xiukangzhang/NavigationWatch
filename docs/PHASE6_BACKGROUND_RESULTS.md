# Phase 6 实体 iPhone 后台导航验证

日期：2026-10-06。设备：iPhone Air，iOS 26.6。导航依赖：`AMapNavi-NO-IDFA` 11.2.100。只验证实体 iPhone 的高德导航快照；Watch 功能另由配对模拟器验证。Physical Apple Watch validation deferred。

## 本轮配置与证据方法

- iPhone App 的 `UIBackgroundModes` 包含 `location`；位置权限文案明确说明路线规划与锁屏后持续引导。
- `AMapNaviDriveManager` 在 GPS 导航开始前设置 `allowsBackgroundLocationUpdates = true`、`pausesLocationUpdatesAutomatically = false`；开始失败、停止和到达时恢复关闭后台定位。
- iPhone Debug 构建明确启用 `DEBUG`。本地缓存 `Library/Caches/navigation-snapshots.jsonl` 记录事件、UTC 时间、App 状态、sessionID、sequence、快照时间、剩余距离/时间及指令是否非空；不记录坐标、道路名或 Key。通过设备服务读取文件，用锁屏期间的多条时间戳判断是否持续产生，不能只看解锁后的 UI。
- [Apple 后台位置文档](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates) 和 [高德导航定位设置](https://lbs.amap.com/api/ios-navi-sdk/guide/location-info/location-setting-callback) 都要求后台位置能力与导航管理器设置配合使用。

## 当前最小验证

| 检查 | 状态 | 证据 |
|---|---|---|
| Phase 5A 正式 Pod 前台基础闭环 | PASS（用户回报） | 修改后台配置前，实体 iPhone 静止前台约 1–2 分钟出现导航指令、序号持续增加，未报告错误或闪退；见 `PHASE5_INTEGRATION_RESULTS.md` |
| Phase 6 Foreground baseline | PASS（事件驱动，更新稀疏） | 回调诊断版 09:05:47 开始，09:05:49–09:05:50 产生序号 0–3；09:06:48、09:06:49 高德再次发送导航信息回调，序号升为 4、5。全部由 SDK 回调生成，未使用定时器。序号 5 的状态为 navigating、指令非空、剩余距离 317920 m、剩余时间 14373 s。手机静止时 SDK 近 1 分钟无导航信息回调，不能要求每秒递增。此前 09:00 的用户观察“序号停住”与这次原始回调记录一致，属于静止期间更新稀疏，不能据此判定 Core 丢回调。未验证移动中字段变化 |
| Home Screen background | PASS | 09:06:58 进入后台，09:07:48、09:07:57、09:08:47 在 `UIApplicationState` 为 background 时收到 SDK 导航信息并写入快照序号 7、8、9；09:08:48 回前台后同一会话继续为序号 10。约 1 分 50 秒的后台区间有多条直接时间戳证据 |
| Locked screen | PASS | 用户确认按侧边键锁屏并静止放置约 2–3 分钟。记录 09:09:59 进入 background、09:12:36 回到 active；期间 09:10:00、09:10:23、09:10:24、09:10:45、09:11:44、09:11:46 收到 SDK 导航信息并生成序号 22–28；解锁后生成序号 29。证明快照在锁屏期间产生，而非仅解锁时补刷。静止时末段约 50 秒无回调，刷新频率没有保证 |
| Stop navigation cleanup | PASS（直接路径） | 09:13:11 最后一条导航信息生成序号 32，09:13:12 记录 `stop_requested`、`stop_completed`；约 1 分钟后读取同一文件，停止事件后没有 SDK 导航/定位回调或新快照。`stopNavigation()` 调用 `stopNavi()`，关闭 `allowsBackgroundLocationUpdates`，恢复自动暂停定位，移除 delegate/data representative 并销毁管理器。没有独立测量设备 GPS 功耗 |

当前已排除一个诊断盲点：项目原 iPhone Debug 配置未定义 `DEBUG`，首个后台配置构建中的结构化记录代码实际上未编译；现已修正。分层记录证明静止时暂停的是 SDK 导航信息回调；收到回调时 Provider→Core 正常产生快照。按本轮锁屏后持续产生真实快照的验收规则，Phase 6：**PASS**。这只证明本次静止、正常网络和定位条件下约 2–3 分钟的设备行为，不推断长时、移动或弱网表现。

## Watch Simulator 最小回归

配对的 iPhone Air（iOS 27）与 Apple Watch Series 12（42mm，watchOS 27）模拟器：当前源码的无 Pod Mock 构建成功，两端安装、启动；iPhone 点击“开始模拟导航”后显示序号 0，之后至少升到 13，Watch 同步显示“继续直行”、距离和道路；iPhone 停止后 Watch 显示“等待 iPhone 导航”。**Validated on Simulator only**，**Physical Apple Watch not verified**。正式 Pod 模拟器构建仅含 x86_64，无法装到本机 arm64 模拟器，所以本回归使用同一源码的不含 Pod 构建；实体 iPhone 的 AMap 测试使用正式 Pod 11.2.100。

## 未验证边界

- 实际移动中的 maneuver、距离变化、车道和路况：NOT YET VERIFIED。
- 实体 Watch 的 Bluetooth/Wi-Fi 通信性能、后台调度、抬腕、熄屏、实际延迟、功耗和触觉：NOT VERIFIED ON PHYSICAL WATCH。
- iPhone Simulator + Apple Watch Simulator 的既有 Mock 联测只能证明模拟器应用层路径，不能替代实体 iPhone → 实体 Watch 端到端验收。

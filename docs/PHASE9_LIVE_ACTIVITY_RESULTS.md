# Phase 9 — Live Activity + Apple Watch Smart Stack

更新：2026-10-07；当前阶段：PASS，已完成本轮最小验收，导航已停止。

## 环境与公开 API

- Xcode 27.0 (27A266a)；iOS / watchOS SDK 27.0；部署保持 iOS 18 / watchOS 11。
- 实体设备已识别：iPhone Air，iOS 26.6；Apple Watch Series 10，watchOS 26.6。
- 从本机 SDK swiftinterface 核对 Activity.request(attributes:content:pushType:)、update(ActivityContent)、end(dismissalPolicy:)、ActivityContent.staleDate、ActivityViewContext.isStale、ActivityFamily.small、supplementalActivityFamilies、activityFamily。
- WidgetKit 的 supplementalActivityFamilies / activityFamily 是 iOS 18+ API，watchOS 侧不可直接调用。提供一个 iPhone Widget Extension 的 small 布局，由系统同步、呈现 Smart Stack；无独立 Watch Live Activity Target，也不模拟 Smart Stack。
- 官方机制：[Apple ActivityFamily](https://developer.apple.com/documentation/widgetkit/activityfamily)、[Bring your Live Activity to Apple Watch](https://developer.apple.com/videos/play/wwdc2024/10068/)。系统展示受设置、系统选择和更新预算影响，不保证实时展示。

## 实现与边界

NavigationCore → NavigationSnapshot → LiveActivityCoordinator → ActivityKit。
原 WatchSyncCoordinator 路径不变；Shared 模型、Provider、Watch UI 未修改。UI 只消费 NavigationActivityAttributes.ContentState，无 SDK 类型和独立导航状态机。

- 唯一新增 NavigationWidgets iOS Widget Extension；原工程无 Widget Target。
- 静态属性仅 navigationSessionID；动态内容为 maneuver、distanceToManeuver、nextRoad（最多 80 字）、remainingDistance、remainingDuration、eta、timestamp、navigationState、可选 trafficStatus。
- 不含 GPS 坐标、完整路线、车道、电子眼、道路事件或供应商对象；JSON 专项检查不超过 4 KB。
- 路线搜索不创建。provider.startNavigation 成功后 enable，首个非过期 navigating Snapshot 创建；模拟导航使用同一派生链路，测试证据与道路证据区分。
- 所有 start/update/end 串行执行；重复/乱序/退役 session 拒绝。替换 session 先 end 旧 Activity，再创建新 Activity；arrival/stopped/idle 终态不会被同 session 后续 Snapshot 重启。
- Stop、开始失败、取消/异常终止调用 end(reason:)；终止 API 为真正 .immediate ActivityKit end。开始/结束同时清理孤立 Activity。既有 Provider 不提供运行中终止型 Error Snapshot，本轮未新增错误协议；任何未来终止型错误必须经 PhoneModel 的 end 路径接入，非致命 GPS 问题不应擅自结束。
- 本地 request 的 pushType 为 nil，无服务器、APNs 或 Push Token 路径。
- Policy 可配置：远距离 50 m 桶 / 5 秒；100 m 内 10 m 桶 / 2 秒；剩余距离 100 m 桶；时长和 ETA 60 秒有意义变化；有新鲜快照时最长 10 秒 freshness refresh；15 秒 staleDate。上述为本轮初始参数，不声称官方最优。
- maneuver、nextRoad、navigationState 变化立即更新；其余必要变化节流且延迟发布最新值。无变化不反复写；快照停止时不自行刷新 timestamp。staleDate 由 Snapshot 源时间计算，UI 过期隐藏方向与距离，显示“导航信息已过期 / 等待导航更新”。
- Lock Screen 为系统字体、中性背景、蓝色转向图标、距离/下一道路/剩余时长；Dynamic Island 覆盖 compact leading/trailing、minimal、expanded；small 显示同源紧凑导航信息，无地图和完整车道。
- DEBUG 日志 Library/Caches/live-activity-diagnostics.jsonl 仅 event、sessionID、activityID、记录时间。含 started、update_requested、skipped_dedup、skipped_throttle、updated、ended_reason、ActivityKit_error；Release 不写这些日志。
- ActivityKit 的 Activity 类型在当前 SDK 未声明 Sendable，适配文件使用 @preconcurrency import；所有 SDK 操作由 MainActor 串行协调器隔离，不并发访问同一 Activity。

## 最小自动验证

16 项 LiveActivityTests PASS，0 failures。执行筛选仅 LiveActivityTests，未运行 Lane / Traffic / Camera / WatchConnectivity / Mock Navigation 全量回归。

覆盖：mapping/encoding/隐私与 NaN 距离清理、仅成功导航后单 start、重复 update 不重复创建、278→275 m dedup、必要距离 throttle、延迟任务无新快照仍发布、maneuver 立即更新、stop end 与拒绝晚到快照、Session A→B 先结束后创建与拒绝 A 回流、Stop A→Start B、arrival 结束不重启、staleDate/freshness、新会话过期拒绝、异常 end、Stop 取消 pending、重复/乱序序号拒绝。

实体签名 Debug build PASS；主 App 含唯一 PlugIns/NavigationWidgets.appex、NSSupportsLiveActivities=true、AMap.bundle / AMapNavi.bundle 存在。初次安装因 Extension 缺 CFBundleVersion 拒绝，已补齐主 App / Extension 1.0 (1) 后重新构建；最终安装与启动 PASS，主 App / Extension 最终 Info.plist 的版本均为 1.0 (1)。

## 真机结果（已完成）

实体 iPhone Air / Watch Series 10，iOS / watchOS 26.6。2026-10-07 北京时间导航 start_requested 18:44:07，stop_completed 18:45:58，共 1 分 51 秒（约 2 分钟）；Activity 18:44:17 创建，18:45:58 ended_stop。未延长测试或为 Phase 8 绕路。

| 项目 | 结果与证据 |
|---|---|
| Activity Start | PASS，真实 ActivityKit started 1 次、唯一 Activity ID |
| Activity Update | PASS，真实 updated 7 次；请求 66 次，其中 dedup 49、throttle 10。节流后 delayed/后续快照可继续发布，因此各计数不要求逐项相加相等。 |
| Lock Screen | PASS，用户观察确认出现、更新正常 |
| Dynamic Island | PASS，支持设备，用户观察确认展示正常；四种布局编译通过，但未对每种布局分别留截图 |
| Stop Ends Activity | PASS，真实 ended_stop 1 次、stop_completed；用户确认停止后消失 |
| Session Isolation | PASS，专项 fixture A→B 与 Stop A→Start B；本次真实道路仅一个 session，不宣称已完成真机 A→B |
| Apple Watch Smart Stack | PASS，用户观察确认出现、更新、随 Stop 结束；无独立截图取证 |

用户对包含上述各项和闪退问题的完整验收问题回答“都正常”。视觉 PASS 的依据明确是用户现场反馈，不伪称自动截图或 Watch App 日志能证明 Smart Stack 显示。未来设备/路线未观察时仍须写 NOT OBSERVED ON CURRENT WATCH TEST。

日志 sessionID 7A1D4359-FA00-407E-A773-0795B2D07B33，Activity ID 47F90C53-7B6A-443C-ADDF-1FF1C1F6DC74。Watch 同会话日志 PID 924，观察到应用 sequence 10→66（停止终态序号）；本轮未发现新增 Watch 退出，系统 NavigationWatch Watch crash 列表为空。iPhone 系统列表最新已有 IPS 为 18:10:24，早于本次导航，未发现本次新增 IPS。该短测试不构成长时稳定性证明。

证据目录：<LOCAL_PROJECT_PATH>
包括 tests.log、device-build.log、install.json、launch.json、sdk-mechanism.txt、live-activity-diagnostics.jsonl、navigation-snapshots.jsonl、watch-diagnostics.jsonl、双方 crash-list.json、evidence-summary.json。日志不随源码包交付。

## Phase 8 与历史故障

本轮正常导航再次观察到 redLight Camera；真实限速、非空 Road Event 均 NOT OBSERVED ON CURRENT ROUTE，Road callback 仍为空列表。Watch event text 未独立视觉确认，不能从“都正常”的 Live Activity 验收反馈推断通过。Phase 8 Implementation PASS / Real coverage PARTIAL。
Phase 7.5 PASS WITH KNOWN HISTORICAL ISSUE，历史 Watch 退出根因 UNKNOWN；本轮约 2 分钟未观察到新的 Watch 退出或 crash；历史退出根因仍 UNKNOWN，不写 ROOT CAUSE FIXED。

## Gate 与下一步

Phase 9 PASS；Implementation PASS，Real-device Coverage 在本轮最小验收范围内 PASS（视觉依据为用户现场确认）。start/update/end 真实日志、session isolation 专项测试和 Lock Screen 实体反馈齐全。Arrival 与 A→B 真机未单独执行，相关 lifecycle 已用 fixture 覆盖。当前无已确认 blocker；系统展示预算、后台可调度性、长时间稳定性与其他设备覆盖未在本轮扩大验收。
完成本轮即停止，不进入红绿灯倒计时、多 Provider 或 CarPlay。

## 后续进度更正（2026-10-07）

原Phase9 PASS仅适用于本页记录的最小展示/start-update-end验收。用户后续报告Watch Smart Stack点击显示Open on iPhone，未直接进入Watch App，以及Watch内出现Smart Stack按钮；原验收没有确认点击入口。
Phase10.5追加修正Watch启动声明WKSupportsLiveActivityLaunchAttributeTypes空数组，双端build/install及签名plist检查PASS；Watch因Locked拒绝自动启动，实际解锁后点击效果UNKNOWN / 尚未验证。按钮来源仍UNKNOWN。原展示PASS不被扩展为点击入口PASS；最新问题与证据读PHASE105_STABILITY_RESULTS.md。本次文档同步未追加系统视觉验收。

23:02:35追加版本Watch正常启动由journal确认，初次Locked启动拒绝不再作为当前启动待确认项；此日志仍不证明Smart Stack点击入口PASS，点击效果与按钮来源尚未确认。详见Phase10.5最新复现记录。

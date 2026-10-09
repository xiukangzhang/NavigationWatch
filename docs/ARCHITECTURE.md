# 架构 — AMap-only RC1

## 当前正式路径

关键词 → AMapDestinationSearch → NavigationPlace（optional address、GCJ02坐标来源）→ AMapNavigationProvider.calculateRoute → AMapRouteCatalog → NavigationRoute（真实距离/时间、optional traffic、公开UUID）→用户选路→selectNaviRoute/startGPSNavi→原NavigationCore/NavigationSnapshot→原WatchConnectivity与ActivityKit。

Search独立SDK只存在Providers/AMap，Shared/Watch无AMapSearch类型；SDK routeID仅在Provider内持有。新optional字段保持旧wire解码。AMap capability supportsSearch已启用。正式只AMap，Apple文件仍保留独立实验Package但不编入Release iPhone target，Mock及开发入口DEBUG隔离。

PhoneModel用generation拒绝旧回调并统一finish：先退役generation，发布终态，再Activity end、Core/Provider stop与清空模型。SDK错误仅在已经退出navigation时进入fatal cleanup；一般重算错误给用户提示，不自动restart。Provider既有stopNavi/关闭后台定位/移除代表与destroy策略保留，不为静止callback改变freshness或生命周期。

Core、freshness、Watch传输与Live Activity核心保持不变；Watch补齐Stop UI及已有消息类型发送入口；iPhone仅增加sessionID gate，防止迟到请求停止新会话；未改导航快照同步机制。Release自身不写精确轨迹；Debug诊断保持原路径。RC1本次用户确认十项核心链路正常；具体用户证据/能耗及Stack点击覆盖边界见RELEASE_CANDIDATE_RESULTS，不仅由架构推断PASS。

## 下方历史架构说明（当前策略以本节为准）

# 架构（Phase 0–11）

```text
AMap SDK → AMapNavigationProvider ────────→ NavigationCore → NavigationSnapshot
MockNavigationProvider ──────────────────↗              ├→ WatchSyncCoordinator → WatchConnectivity → Watch UI
                                                     └→ LiveActivityCoordinator → ActivityKit → 系统 Lock Screen / Dynamic Island / Smart Stack
```

- iPhone 的 `NavigationCore` 是活动导航状态的唯一拥有者。Provider 只产出项目自己的 `NavigationSnapshot`，Shared 和 Watch 不引入供应商类型。
- `NavigationProvider` 用 `AsyncStream` 发送更新。Mock 约 1 Hz 运行 6 分钟，模拟直行、转向、车道、交通、偏航、重规划、到达。高德 Provider 已接入终点坐标算路和驾车导航回调；POI 搜索、移动中的车道和路况仍未验证。
- 并发模型：Provider、Core、双端连接协调器归 `@MainActor`；模型为 `Codable & Sendable`。WCSession delegate 的非隔离回调只提取 `Data`，再交回主 actor。iPhone 对最新编码消息用锁保护，以便同步回答 Watch 的 pull 请求。
- 会话模型：每次开始导航生成新 UUID，序号从 0 开始。Watch 只接受协议版本 1、信封与快照 ID/序号一致的消息。同会话严格递增；新会话的第一条可为任意序号（支持重连直接追上），但其 iPhone 源时间必须晚于最后已应用快照。停止发送终态。iPhone 系统时钟回拨和重装后的会话判定仍需真机验证；未来可用 iPhone 持久化单调 generation 代替时间比较。
- 传输：Watch 可达时用 `sendMessage`，同时通过 `updateApplicationContext` 保存最新状态。Watch 初始化、页面恢复、重连或状态过期时用 request/reply 拉取。不会回放旧状态队列。Watch 的旧数据超过可配置阈值时隐藏转向与距离。WatchConnectivity 不保证硬实时、后台持续运行或消息必达。
- 错误：统一 `NavigationError`；高德 Provider 映射算路失败与定位权限提示。触觉属后续阶段；Live Activity 已由 Phase 9 本地适配层实现。
- 后台：仅在真实高德 GPS 导航期间允许后台定位；停止或到达后关闭高德后台定位并停止导航资源。Debug 本地记录快照时间与序号，不记录坐标或道路名。没有账号、广告或云端轨迹；高德 SDK 是 iPhone 端第三方依赖。

## Phase 7.5 / 8 当前补充

- Phase 7.5 targeted soak 16 分 56 秒及三次恢复通过；历史 Watch 退出本次未复现。已确定并修复的 iPhone WCSession errorHandler 隔离断言见 PHASE75_WATCH_STABILITY_RESULTS.md。以下旧 Phase 2–4 实体状态为历史，不能当作当前 blocker。
- 正式 Provider 和全部高德 mapper 位于 Providers/AMap；纯 Mapper 测试使用独立 AMapMappers 包目标，Shared/Watch 无 SDK 类型。AMapNavigationProvider 的原 iOS 路径已迁移。
- Phase 8 复用 speedLimit，增量 typed CameraEvent、RoadEvent、AverageSpeedZone；旧 version-1 payload 缺新字段仍可解码，缺 supportsRoadEvents 默认 false。legacy camera/roadEvent 保留。当前 SDK 无道路事件直接剩余距离与严重度，保留 nil；过去的 segment/link 事件过滤，事件独立源时间限制展示寿命。
- 车道、转向源时间不因辅助 callback 伪刷新；限速/电子眼/道路事件的 capability 仅在已实现的正式 Provider 路径启用，Mock 仍默认 false。Phase 8 真实回调结果单独见 PHASE8_SPEED_CAMERA_EVENT_RESULTS.md。

## Phase 2–4 诊断与门槛（历史记录）

- Debug 双端页面显示 session、sequence、activation、reachability、context/pull/reconnect 时间及拒绝计数。Watch 记录信封接收延迟和 SwiftUI 页面更新回调延迟的 count/median/P95/P99/max。日志以 `[GENERATE]`、`[SEND]`、`[RECEIVE]`、`[DROP]`、`[PULL]`、`[RECOVERY]`、`[APPLY]` 分类，不包含位置。
- `SnapshotGate` 拒绝重复、乱序、已退役 session 和旧时间的新 session；首次收到新 session 的任意序号可直接追上。
- `sendMessage` 仅在可达时发送，`updateApplicationContext` 保存最新值，恢复时主动 pull。没有队列回放保证，也不把 `sequenceGaps` 误称为实际丢包。
- Watch 模拟器中 Mock 导航更新及停止恢复等待状态已验证。用户随后报告实体 Watch 已连接，但实际通信中断/延迟；开发工具现已识别 Series 10，稳定同步、熄屏/重连、延迟和功耗仍待真机复测。实体 iPhone 的高德 Home 后台与锁屏快照由 `PHASE6_BACKGROUND_RESULTS.md` 单独记录，不能据此声称实体 Watch 链路通过。


## Phase 9

LiveActivityCoordinator 是 NavigationCore 快照的派生消费者；NavigationActivityStateMapper 将统一 Snapshot 转为最小 Activity ContentState。Shared 模型和 Watch 传输未修改。所有 ActivityKit 操作串行，本地 pushType=nil，先成功导航再创建，Stop/arrival/异常终止/换 session 结束 Activity；session gate、dedup/throttle、staleDate 与 DEBUG diagnostics 见 PHASE9_LIVE_ACTIVITY_RESULTS.md。
唯一 iPhone NavigationWidgets Extension 使用 ActivityConfiguration + supplementalActivityFamilies([.small])，系统负责 Apple Watch Smart Stack 呈现，无独立 Watch ActivityKit Target、无第二导航状态机。真实 Lock Screen/Dynamic Island/Smart Stack 的本轮视觉 PASS 来自用户现场确认；A→B / Arrival 生命周期由专项 fixture 覆盖。


## Phase 10

高德公开 SDK 标量回调经 Mapper/LocationQualityMapper/NavigationEventLifecycle 进入统一 Snapshot；NavigationCore 仍是导航状态唯一拥有者。trafficLightInfo 仅消费路线剩余信号灯数，不制造最近距离、灯态或秒数。LocationQuality 独立使用 SDK accuracy/locationTimestamp/GPS signal/provider state，辅助事件回调不更新定位或引导源年龄。camera/road/speedLimit 身份稳定，route-scoped ledger 统一 firstSeen/update/removal/pass/expiry，typed Phase 8 payload 保留；坐标仅在 Provider 内生成不可读哈希身份，不传 Watch。
Watch/iPhone 按源时间降级定位并清理过期事件，UI 时钟只控制展示刷新，不是导航数据源。Shared wire version 1 增量 optional 字段；supportsTrafficLightState 缺字段默认 false。Phase 9 ActivityKit ContentState 与 UI 未新增增强事件，WatchConnectivity/session/sequence 逻辑未改。本轮不新增 Haptic、其他地图 Provider 或商业倒计时数据路径。

## Phase 11

AMap Full Navigation与Apple Experimental Route-only均遵循NavigationProvider。Apple通过MKLocalSearch/MKDirections和私有Mapper输出统一Place/Route，不发实时Snapshot；unsupportedOperation明确拒绝start/pause/resume/reroute。capabilities新增search/route/turnByTurn/background，旧payload默认false。坐标来源optional，Apple拒绝未标注/其他来源坐标；不新增坐标转换。public构造支持独立模块。AMap capability profile复用，source/生命周期不改。

统一Snapshot的optional字段可降级；Watch与LiveActivity继续只消费统一状态，不引入供应商分支。创建入口保留AMap生产授权流，Apple仅独立实验构造；没有Registry或自动fallback。详细问题、必须修复3项及未来边界见PHASE11_MULTI_PROVIDER_RESULTS.md。

## 1.0(9)规划详情扩展

NavigationRoute可选RoutePlanningInfo表达红绿灯总数、是否高速、预计通行费和各类路况长度；SDK类型留在AMap provider/mapper，缺失metadata兼容旧模型，不加入NavigationSnapshot、WatchSync或LiveActivity。高速判定来自Link道路类型而非收费推断，规划交通长度不作为实时最近拥堵距离。首页FocusState控制键盘与最近目的地可见性；历史存储规则未改。

## 1.0(10)规划地图

规划地图属于iPhone AMap专属适配：PhoneModel只读lookup经route catalog验证的SDK路线，UIViewRepresentable将其GCJ02原始几何绘于SDK内置MAMapView。SDK地图类型与坐标不进入Shared/Watch或LiveActivity。预览不切换manager路线，不启动导航，不新增用户定位。

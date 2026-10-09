# Phase 10.6 — Diagnostic Closure

更新：2026-10-07（北京时间）。当前PARTIAL：三项诊断确认已完成；明确类型声明后的卡片已打开Watch导航App，稳定定位恢复仍未确认。Phase10.5保持PARTIAL，不能标记候选PASS。

## 范围与分层时间戳

唯一生产数据路径保持AMap Provider → NavigationCore → NavigationSnapshot → Watch/本地ActivityKit。未增加第二Provider，未改LiveActivity/Widget UI、stale阈值或源时间，没有道路扩测。
复用现有DEBUG LocationPipelineTimeline：
- 上游对照：upstreamProbeRequestedAt、upstreamProbeCompletedAt、upstreamResponseAt、upstreamSourceAt、upstreamAccuracy、errorCode。复用现有权限CLLocationManager的公开requestLocation，只取时间戳/精度，不记录坐标，不把结果交给SDK/Core/Snapshot。
- AMap出口：lastRawLocationAt（自车位置回调时间，不是SDK隐藏的原始CoreLocation回调）、sourceLocationAt、lastSourceAdvancedAt、lastAMapNavigationCallbackAt、lastSnapshotGeneratedAt、generated session/sequence。
- Core消费：DEBUG只读diagnosticConsumedAt/SessionID/Sequence，在真实AsyncStream消费点更新；Phone监控复制到timeline lastCoreConsumedAt/coreConsumedSessionID/coreConsumedSequence。lastSnapshotAppliedAt仍为Phone收到Core.onSnapshot时间。
- Watch入口：复用receive/apply/source age/snapshot age与session/sequence journal，不改传输策略。

每次AMap导航仅首120秒允许最多两次对照，至少间隔60秒，只在stale/unavailable条件触发；每次10秒截止。Stop取消待完成请求、结束预算；Release没有对照请求/诊断字段。这里没有持续新增定位服务；requestLocation可能唤起系统定位并影响SDK随后的更新节奏，因此对照只能用于缩小观测边界，不能把对照期间恢复当作生产根因已修复。

边界分类：若Provider已有新序号而Core消费时间超过2秒不推进，记coreConsumptionPending；这是观察，不把bufferingNewest的短暂间隙当停死。一次性CoreLocation响应新、AMap出口回调超过15秒无新回调→amapCallbackGap；出口回调仍到但SDK源时间过期→amapSourceStale。一次性响应自身过期→upstreamSampleStale；失败/截止→upstreamProbeFailed；尚未响应→upstreamProbePending。对照完成超过15秒自动回到upstreamUnobserved，绝不据旧一次性测量证明上游一直正常。SDK内部实际CLLocationManager输入仍不可直接观测，分类不是对其私有实现的断言。

## Smart Stack点击目标

继续复用既有Watch App和唯一iPhone Widget Extension。Watch签名Info.plist的WKSupportsLiveActivityLaunchAttributeTypes空数组已验证存在，允许所有本App Activity类型启动Watch；companion bundle dev.local.NavigationWatch匹配。
本轮在现有Watch NavigationStack绑定NavigationPath，注册公开NSUserActivityTypeLiveActivity入口：清空诊断页导航路径，返回现有Watch导航根页并复用resume拉取当前Snapshot。DEBUG记录LAUNCH/live_activity_open、target=watch_navigation_root、当前session/sequence，不读未知userInfo，不在点击时开始/停止导航。没有widgetURL、Link或新增target，没有修改Activity显示UI。首轮实体结果：截图仍为系统全屏页，底部Open on iPhone；复制的Watch journal无live_activity_open，因此不能写已打开Watch导航页。后续仅将启动声明由空数组改为明确NavigationActivityAttributes，签名build及产物检查PASS；安装/最小点击结果单独记录，不以编译通过代替真机通过。
当前SDK公开接口依据：[Live Activity启动](https://developer.apple.com/documentation/activitykit/launching-your-app-from-a-live-activity)、[Watch用户活动处理](https://developer.apple.com/documentation/watchkit/handling-user-activity)、[启动声明](https://developer.apple.com/documentation/bundleresources/information-property-list/wksupportsliveactivitylaunchattributetypes)。当前WatchOS27 SDK WidgetKit/WGWidgetDefines.h实际包含NSUserActivityTypeLiveActivity，双端编译通过。

## Smart Stack按钮来源

用户本轮明确：按钮出现在“点击Smart Stack卡片后出现的全屏页面”，不是App内常驻按钮。Widget/ActivityKit/Watch当前源码审查没有Smart Stack文案、Button、Link或自定义跳转按钮；唯一Watch工具栏入口是DEBUG通信诊断。Activity update没有alertConfiguration。
与Apple官方公开行为对应：未匹配Watch启动声明/未有可启动伴侣App时，系统显示LiveActivity全屏wrapper和Open on iPhone入口。结合用户指明的页面和源码，来源归为watchOS系统Live Activity wrapper，不是NavigationWatch自绘按钮。启动声明及入口验证将决定当前版本是否直接打开Watch；不通过删除不存在的App按钮处理，不自行隐藏系统UI。[Apple系统wrapper说明](https://developer.apple.com/documentation/bundleresources/information-property-list/wksupportsliveactivitylaunchattributetypes)。当前用户截图已直接确认该系统wrapper及Open on iPhone按钮仍存在。用户文字答“没有”不能据此推定按钮已移除。白底浅色文字难辨认也已确认，原因未验证；遵守本轮不改Live Activity UI约束，仅记录。

## 最小验证与待验收

4项Phase106DiagnosticTests（层级区分、一次性样本到期/错误/编码、预算/Stop、真实Core消费及stale→恢复同session）+既有Core/Watch gate恢复1项+Activity恢复1项，6项不同用例PASS。修正Core判定后仅重跑4项Phase106测试，PASS。无Lane/Traffic/Camera/WatchConnectivity业务全量回归。
实体双端Debug签名build PASS，双端install JSON success，iPhone启动success；Watch实际启动以卡片点击/用户反馈及journal为准。签名Watch plist、AMap.bundle/AMapNavi.bundle及Widget UI无变更检查PASS。临时Config.local已清理。
证据work/phase106：tests.log、diagnostic-tests-final.log、build.log、artifact-check.json、install/launch JSON、phone-final.jsonl、watch-current.jsonl、summary.json、smart-stack-system-wrapper.PNG。实体原地导航23:20:34–23:22:49约2分15秒，Phone日志确认Stop。Watch复制日志截止23:21:22，不能据此证明本轮Stop等待页或后续状态；不追加长soak/道路测试。

## 收口规则

三项完成后，根据用户本轮授权可将Phase10.5改为PASS WITH KNOWN INTERMITTENT LOCATION STALENESS：接受高德/CoreLocation可能存在偶发源停留，但必须保留自动恢复可靠、提示正确、session/sequence未破坏的证据，及Watch历史退出根因UNKNOWN。不等同ROOT CAUSE FIXED。当前稳定自动恢复未满足：用户反馈“否”，日志仅短暂恢复后再次stale；最新点击已通过，不消除定位问题。因此保持PARTIAL，不使用候选PASS。历史Watch退出根因仍UNKNOWN。

## 本轮真实分层结果（北京时间）

23:21:34的第二次一次性对照：Core Location返回源年龄0.738秒、精度4.67米的新样本；AMap自车位置回调已43.692秒无新回调，SDK源年龄44.739秒。但AMap导航信息回调仅0.976秒前仍到，Provider生成seq62，Core约13.7毫秒后消费同session/seq62，Phone随后应用。分类amapCallbackGap。这将本次问题缩小到AMap自车位置输出/其内部输入处理边界，不支持NavigationCore消费停住；独立CLLocation新样本不证明SDK内部实际收到同一定位，SDK底层原因仍UNKNOWN。本次GPS字段unknown，不能套用23:01那轮strong。
23:21:06显示stale；23:21:51收到源23:21:40，短暂恢复，23:21:56又stale。用户反馈未自动恢复，与“短暂约5秒恢复但不稳定”一致；不称可靠恢复。全程未观察session自动重建，核心seq推进。两次对照预算生效，首笔在启动无样本时触发；过期对照自动回upstreamUnobserved。

| 诊断项目 | 实际结论 |
|---|---|
| 分层时间戳/消费层排除 | PASS；实测边界amapCallbackGap，底层原因UNKNOWN |
| Smart Stack点击到Watch导航页 | PASS（最新显式类型版本）；用户确认直接进入，journal验证导航根页入口；首轮空数组版本FAIL |
| Smart Stack按钮来源 | CONFIRMED SYSTEM LIVE ACTIVITY WRAPPER；首轮截图按钮仍在，最新点击直接进App |
| 定位稳定自动恢复 | NOT CONFIRMED；用户答否，短暂恢复后再stale |
| 文字可读性 | ISSUE OBSERVED；白底浅色，本轮不修改UI |

明确类型声明修正参考当前Apple公开启动键定义；Apple开发者论坛有同类空数组失败、显式类型改善的报告，但不作为本设备根因结论：[Apple启动声明](https://developer.apple.com/documentation/bundleresources/information-property-list/wksupportsliveactivitylaunchattributetypes)、[同类讨论](https://developer.apple.com/forums/thread/761052)。当前签名plist显式数组已核实，最新实体点击已确认通过；无新增Target、无颜色/布局改动。

最新显式类型声明版本：双端install JSON success；已取得安装后的点击结果：用户确认直接进入Watch导航App；未由代理预先启动Watch，以免混淆卡片入口。无需重复定位soak。

## 最新最小点击复核：PASS

将Watch启动声明由空数组改为NavigationActivityAttributes显式数组后，双端签名build/install success。用户反馈“直接进入 Watch 导航 App”；23:33:45及23:33:49 Watch journal两次live_activity_open记录target=watch_navigation_root current_snapshot_only，PID1449，同session 3D101AE1-FA99-4ABE-8090-5A824C02ACDF/seq14，首笔snapshotAge0.596秒。因此点击目标与现有导航根页路由已确认，未新增target或修改LiveActivity UI。证据watch-explicit-type.jsonl、explicit-type-artifact.json、explicit-type-build.log及双端install JSON。最新App可读性没有独立新截图，不以跳转成功推定系统wrapper配色已修复。

本轮三项诊断确认完成：定位边界已缩小、点击目标已通过、按钮来源已明确。但定位自动恢复条件尚不可靠，Phase10.5仍PARTIAL，不作候选PASS收口。无需再重复长观察或道路测试。

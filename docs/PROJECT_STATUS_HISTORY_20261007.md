# 最新有效状态：Phase 7.5 修复待复测

首轮真实导航 soak 发现 iPhone 在 WCSession 发送错误回调后台线程执行时崩溃，已取得 17:18:53 系统 IPS 并定位 MainActor 隔离断言；Watch 本身同一进程且未见匹配 crash。已仅将正常/诊断发送 errorHandler 标 @Sendable；生产回调代码的 worker-thread harness、正式 Pod Debug 构建 PASS，iPhone 修复版已安装。Phase 7.5 当前 PARTIAL，首轮验收 FAIL，修复后至少 15 分钟 soak 待做。Phase 8 未开始。详见 PHASE75_WATCH_STABILITY_RESULTS.md。

# 当前接续状态（2026-10-07 Phase 7.5）

Phase 7 Implementation PASS；真实道路完整验收 PARTIAL（lane 未观察，traffic PASS）。Phase 7.5 Debug 日志已补齐，5 项定向测试、Watch Debug/Release 构建通过，新版 Watch 已安装启动并提取持久日志。用户已同意至少 15 分钟真机 soak，待开始确认与结束取证；当前 Gate PARTIAL。Phase 8 未开始。详见 PHASE75_WATCH_STABILITY_RESULTS.md。

以下为历史阶段记录，不能将旧 FAIL、旧未安装或短时 PASS 当作本次 soak 结论。

# Current Phase

本轮已结束：用户确认停止，手机日志北京时间 16:58:00 stop_completed，采集日志无新活跃快照。Phase 7 限定实现和最小验证已完成；真实车道未观察，真实路况回调已观察；此前 Watch 退出本次未复现、根因 UNKNOWN。不再等待停止操作，不自动追加测试或其他功能。

最新有效观察：用户同场景复测回复“已正常”，Watch console 未捕获崩溃，结束捕获后同一 PID 900 仍运行；本次短时恢复正常，早前闪退根因 UNKNOWN，不声称已修复所有间歇性退出。Phase 7 Lane/Traffic mapper 与显示完成，真实车道 NOT OBSERVED ON CURRENT ROUTE，真实路况回调进入统一模型 PASS。最终手机快照至少到 114；这次新路线提取日志时尚未停止，需用户点击停止。本轮不扩展其他功能。

最新回归：**Phase 7 Watch 稳定性 FAIL（用户报告）**，触发于熄屏返回或打开通信诊断。仅继续定位修复，不扩展新功能。正式高德真实路况 callback 已进入统一模型（slow，拥堵段长度 3334→3757 m），车道 callback 为 NOT OBSERVED ON CURRENT ROUTE；见 PHASE7_LANE_TRAFFIC_RESULTS.md。前一版本的真实同步 A–D PASS 保留为限定历史证据，不代表新版已无 crash。

Phase 7（2026-10-07）：仅 Lane Guidance + Traffic，纯 mapper 与最小双端展示已实现；5 项定向测试、正式 SDK 双端构建、Watch 42mm 有/无车道视觉检查通过；最终双端版已安装，Watch 锁屏导致远程启动被系统拒绝，待用户手动打开并完成当前路线短时回调观察。Snapshot 编码结构不变。详见 PHASE7_LANE_TRAFFIC_RESULTS.md。

2026-10-07 最新有效结论：**Physical iPhone → Physical Apple Watch real navigation sync verified**。本轮 A–D 经阈值修复后已测范围 PASS，用户确认持续显示、熄屏返回及停止回等待页均正常，无 Watch crash；停止后日志未见新活跃快照。实际移动未确认，不扩大为长期/移动完整验收。Phase 7 现开始，仅车道与实时路况；旧失败及早期状态保留为历史。详见 WATCH_DEVICE_SYNC_RESULTS.md 最新结论。

2026-10-07 最新跟进：本轮真实导航 A PASS，Watch Applied 序号持续增长且未报告 crash，但熄屏返回仍显示过期提示，C FAIL；D 未测，因此本轮真实导航同步整体 FAIL / 尚未完成验收，Phase 7 未开始。已针对 SDK 最长已观察 52 秒回调间隔与旧 5 秒阈值不匹配，将 Watch 默认源时间阈值调整为 90 秒；2 项定向测试及 Watch 真机构建通过，仅 Watch 新版安装、启动成功，功能回归待用户确认。详见 WATCH_DEVICE_SYNC_RESULTS.md 的 2026-10-07 记录；下文保留此前阶段证据。

更新于 2026-10-06。正式 `AMapNavi-NO-IDFA` 11.2.100 Pod 已安装，实体 iPhone 构建、安装、启动并完成静止导航复测：算路后出现指令，真实 SDK 回调生成快照，序号增长。**Phase 5A PASS**。Phase 6 的 Home 后台、锁屏和停止后清理均取得真机时间戳证据，**Phase 6 PASS**；静止时 SDK 回调可能间隔近 1 分钟，不保证固定频率。实体 Series 10 已连接；Mock 短时同步正常。真实高德首次联测 Watch 显示过期后未恢复；诊断复测用户确认持续更新，并抓到系统初期暂报 Watch App 未安装、随后自行恢复的证据。实体 Watch 稳定同步仍为 **PARTIAL / NOT COMPLETE**。

## 新窗口接续入口

1. 先读 `docs/NEXT_SESSION_HANDOFF.md` 和本文件，再按所选任务读 `docs/ARCHITECTURE.md` 与相应结果记录；当前实体 Watch 看 `docs/WATCH_DEVICE_SYNC_RESULTS.md`。`DEVICE_TEST_RESULTS.md` 的九项表是早期基线，不能代替最新结果。
2. Phase 5A/6 验收时用户曾将实体 Apple Watch 验证改为 deferred，不作为两阶段阻塞条件；随后报告实体 Watch 已连接，并明确提出中断/延迟问题，现作为独立后续任务处理。不要将 Series 12 模拟器结果写成 Series 10 真机结果。
3. 用户要求**每次只进行与当次改动直接相关的最小测试**，并记录构建、安装、启动、功能表现各自的结果。不要默认重跑全部用例。
4. 当前目录是从只读 ChatGPT 同步镜像复制出的可写 Phase 5 副本；原同步文件未修改。`sources/` 未复制。两个 scheme 为 `NavigationWatch`（iPhone）和 `NavigationWatchWatch`（Watch）。

## 待办与边界

| 优先级 | 待办 | 当前状态 / 下一步 |
|---|---|---|
| 1 | Phase 5A 正式 Pod 基础闭环 | PASS；正式 Pod 11.2.100 的实体 iPhone 算路、指令和快照序号增长已验证；诊断版记录指令非空及剩余距离/时间数值。移动中变化仍未验证。详见 `PHASE5_INTEGRATION_RESULTS.md` 和 `PHASE6_BACKGROUND_RESULTS.md`。 |
| 2 | Phase 6 iPhone 后台导航 | PASS；实体 iPhone Home 后台、锁屏期间均有 SDK 导航信息回调和新增快照的时间戳；停止约 1 分钟后无新回调/快照，代码关闭后台定位并销毁管理器。详见 `PHASE6_BACKGROUND_RESULTS.md`。 |
| 3 | 实体 Watch 通信稳定性 | PARTIAL / NOT COMPLETE；Mock 双端前台约 1 分钟正常。真实高德首次不恢复，第二次用户回报持续更新；iPhone 记录前 67 个快照的 context 因 WCError 7006 被拒，安装识别恢复后 211 次 context 接受。安装识别恢复时立即重发最新快照的修复已构建、装到 iPhone；这次更新后 Watch App 确实消失，已重新安装启动。双端修复版待联测。 |

实体 Watch 新问题与验证边界详见 `WATCH_DEVICE_SYNC_RESULTS.md`。

# Completed

- Phase 0：检查空白工作区，记录四个参考仓库的 README 与许可证；建立审计和架构文档。
- Phase 1：统一 `NavigationSnapshot`、能力、错误、`NavigationProvider` 与 Mock Provider。
- Phase 2–3：iPhone `WatchSyncCoordinator` 与 Watch 客户端通信；Mock 驱动 Watch 页面。
- Phase 4 本轮：Mock 以约 1 Hz 运行约 6 分钟；实时 `sendMessage`、最新 `updateApplicationContext`、Watch 激活/重连主动 pull；会话与序号拒绝、过期状态隐藏；Debug 双端诊断、结构化日志、延迟分位数和乱序/旧会话探针。
- `docs/DEVICE_TEST_PLAN.md` 和 `docs/DEVICE_TEST_RESULTS.md` 已建立。
- Apple Watch 模拟器联测发现并修复 WCSession 请求回调的线程隔离崩溃；双端 Mock 导航更新和停止同步已验证，详见 `docs/SIMULATOR_TEST_RESULTS.md`。

# In Progress

Phase 5A/6 已按限定范围完成；Logo 已交付。实体 Watch 中断/延迟作为独立后续任务仍在进行，最新恢复修复版已经安装到双端，但**安装后的真实高德同步尚未复测**。移动中 maneuver/距离变化、车道与路况仍未验证，不自动进入 Phase 7。早期九项实体 Watch 计划仍未逐项完成，不能把配对、安装或短时更新等同于完整真机验收。

# 历史设备发现限制（已解除，仅供追溯）

以下条目是当时的设备状态，不代表 2026-10-06 最新状态；当前实体 Series 10 已可由 `devicectl` 识别、安装和启动，见 `WATCH_DEVICE_SYNC_RESULTS.md`。

- 设备服务在默认沙盒内初始化超时；直接访问后确认一部 iPhone Air（iOS 26.6）通过有线连接、开发者模式开启且已解锁。未发现 Apple Watch 真机运行目标，因此无法进行配对联测。CoreSimulatorService/simdiskimaged 在默认环境仍不可用。
- 两个 Target 已选择 Personal Team，实体 iPhone Air 的 Debug 构建（含 Watch App）签名成功。用户移除 FormulationLearning 后，NavigationWatch 已安装到 iPhone；初次命令行启动遇到暂时的设备调试服务 XPC 错误，后续重试成功。此为早期设备准备记录；随后高德 iPhone 导航已有用户真机回报。
- 用户报告 Apple Watch 已配对 iPhone，但 `devicectl`、`xctrace`、Device Hub 和 Watch scheme 运行目标中均未出现该实体 Watch。Device Hub 的附近设备配对界面显示 `Waiting to pair`；用户反馈 Watch 的“隐私与安全性”中没有开发者模式选项。待检查设备信任与本地连接。
- iPhone 系统 Watch 应用能列出配套 App，但用户点安装返回 `This app could not be installed at this time`。当前 Watch App 描述文件的 `ProvisionedDevices` 只包含 iPhone 与 Mac，不含 Watch；与设备未被 Xcode 识别一致。需先完成 Watch 开发设备发现，再刷新签名重试安装；泛化安装提示不能单独确定唯一根因。
- 用户重启手表并确认了“信任此电脑”，但“开发者模式”仍未出现。复查 Device Hub、Watch scheme 和 CoreDevice，实体 Watch 仍不可见。用户确认型号为 Series 10（GPS）、watchOS 26.6（23U67），满足 watchOS 11 最低要求；iPhone 开发连接与 Developer Disk Image 可用，故阻碍集中在手表的开发设备发现/配对环节。
- 用户确认三端网络检查后仍无变化；`xcdevice`、`devicectl`、Watch scheme 和 Device Hub 均未列出实体 Series 10。Device Hub 中的 Series 12 是模拟器。本机设备发现日志未提供明确错误码。Watch 配对/开发者模式问题尚未定位到唯一根因。
- 经用户明确允许，已在 Device Hub 取消并重新建立实体 iPhone 与 Mac 的开发配对；iPhone 恢复 `connected`。等待并复查后实体 Watch 仍未出现在 CoreDevice 或 Watch scheme；用户确认手表没有新信任提示或开发者模式。
- 当前主机为 macOS 27.0.1、Xcode 27.0（27A266a）；Apple 官方系统要求确认 Xcode 27 支持 watchOS 26.6 真机，Xcode 26.6 只支持 macOS 26.x，因此不把降级 Xcode 作为当前主机的受支持方案。手表设备发现未解决，真机联测继续阻塞。
- 原 ChatGPT 同步镜像没有 Git 且禁止在镜像内创建 `.git`。本 Phase 5 副本尚未初始化 Git；不应把原镜像当作可编辑仓库。
- 用户已在本机配置绑定 iPhone Bundle ID `dev.local.NavigationWatch` 的高德 iOS 导航 Key，且实体 iPhone 构建产物中为非空；用户随后回报同一坐标算路成功。没有独立抓取鉴权/路线详情，不能把整个导航链路写成 PASS。
- 2026-10-06 首次真机点击“同意并继续”时，临时手动链接构建因缺少高德资源包在导航管理器初始化处崩溃。已将 `AMapNavi.bundle`、`AMap.bundle` 加入该真机验证构建的 iPhone 资源阶段，重新构建、安装并启动；用户复测回报不再闪退且出现导航指令。随后正式 Pod 版构建产物也已核对包含两个资源包；前台连续序号获得用户回报，Watch 联测未验证。
- 2026-10-06 随后的用户截图显示纬度 `31`、经度 `120` 算路未成功，旧版只展示通用错误。已在算路前检查位置及精确位置权限，并保留高德 SDK 错误码；诊断版安装后，用户用相同坐标复测回报导航成功。旧版具体失败码未记录，不能确定原始原因；移动中的 GPS 引导和 Watch 联测仍待验收。
- 2026-10-06 CocoaPods 1.15.2 已在任务目录内运行。初次下载高德导航包时，域名默认命中的 CDN 地址在 TLS ClientHello 后报 `SSL_ERROR_SYSCALL`；抽查另外三个同域名地址均返回 HTTP 200，直接重试后 `pod install` 成功。正式 Pod 的默认 iOS 9 模拟器目标低于 Xcode 27 支持范围，已在 `Podfile` 中设为项目 iOS 18；随后 `.xcworkspace` 模拟器和实体 iPhone 构建通过，iPhone 安装、启动并确认进程仍在运行。未关闭证书校验，未改业务代码。
- 2026-10-06 Apple Watch 再查：`xcdevice` 和 Device Hub 均只列出实体 iPhone，Series 12 为模拟器；Device Hub 的“Pair Nearby Device”停在 `Waiting to pair`，用户在该状态下再次确认 Series 10 的“开发者模式”没有出现。Xcode 27 按 Apple 官方兼容表支持 watchOS 10 及以上设备，当前 watchOS 26.6 不低于最低范围；具体设备发现原因仍未知。

# Important Decisions

- iPhone `NavigationCore` 负责导航状态，Watch 只消费统一快照；通信层不持有 SwiftUI View。
- WatchConnectivity 是系统调度的通信框架，不保证硬实时。应用使用实时消息、最新状态 context、主动 pull 和过期提示组成降级方案。
- Debug 日志不写位置或完整轨迹；Release 不显示诊断页，也不记录 Debug 结构化日志。
- 当前 Watch stale 阈值为可配置的 90 秒（2026-10-07 定向调整），源时间不因重复接收而刷新；最新真机功能回归待完成。延迟使用两设备时钟，需注意时钟偏差；UI apply 指应用层页面更新回调。

# Verified

- 高德数据映射定向测试通过；无 SDK 的 iPhone+Watch Debug 模拟器构建通过。正式 11.2.100 Pod 版在隔离副本完成模拟器与实体 iPhone 构建、iPhone 安装启动；SDK 两个资源包存在。此前使用官方 11.3.100 手动开发包的实体 iPhone 构建、安装、启动通过，用户回报可算路并两次启动导航，详见 `PHASE5_INTEGRATION_RESULTS.md`。
- Swift 6 编译与核心自动测试：通过；详见 Test Results。
- 快照编码、序号和旧会话拒绝、Mock 重启新会话、延迟分位和 stale 策略：已由单元测试验证。
- iPhone Air 与 Apple Watch Series 12 配对模拟器：两端 Debug 构建、安装和启动成功；前台 Mock 导航显示并持续更新，停止后 Watch 回到等待画面。
- 设备准备层面：实体 iPhone Air 已识别为 connected，且具备开发者模式；这不构成 App 功能验证。

# Not Verified

- 正式 Pod 11.2.100 静止导航中 remainingDistance / duration 已有本地数值记录，尚未验证移动时数值准确变化、maneuver 变化、车道和路况。实体 Watch 曾收到真实高德指令；首次持续同步失败，第二次诊断复测用户报告持续更新，最新版修复后仍待复测。
- **NOT YET VERIFIED ON PHYSICAL WATCH**：真实高德稳定同步、长时间连接稳定性、Watch 熄屏/重开、断连重连、Debug 探针经真实 WCSession 的表现、精确延迟分布、功耗及触觉。实体 Watch 的前台 Mock 约 1 分钟更新已由用户确认。iPhone 长时间后台/锁屏、移动、弱网、GPS 功耗和 Task 泄漏也未独立验收。
- iPhone 锁屏后 Mock 是否持续：UNKNOWN / 尚未验证；本轮验证的是正式高德导航的实体 iPhone 后台路径。

# Known Issues

- 单向延迟由 iPhone 与 Watch 的 Date 相减，时钟偏差可能影响数值；屏幕物理显示时间无法由 SwiftUI 回调直接证实。
- 新 session 的判定仍依赖 iPhone 快照时间；系统时间回拨待验证，未来可增加持久化 generation。
- `sequenceGaps` 可能来自 context 合并或传输变化，不是可靠的丢包计数。
- 当前测试 UI 未经真机检查深浅色、小屏和 Dynamic Type。

# Performance Baseline

- UI apply count/median/P95/P99/max：UNKNOWN / 尚未验证。
- Receive latency count/median/P95/P99/max：UNKNOWN / 尚未验证。
- Reconnect recovery time：UNKNOWN / 尚未验证。

# Next Phase Gate

Phase 5A AMap Provider 基础集成：**PASS**。Phase 6 实体 iPhone Home 后台、锁屏持续产生快照及停止后直接清理路径：**PASS**，见 `PHASE6_BACKGROUND_RESULTS.md`。实体 Watch 的一次真实高德持续同步失败、一次诊断复测持续更新；发现安装识别暂态错误 7006。恢复修复已构建并安装到双端，但其功能待真机复测，稳定性不标 PASS。

# Next Steps

当前只处理用户新提出的实体 Watch 中断/延迟与 Logo：图标已交付；Watch 安装识别恢复时重发最新状态的修复已装到实体 iPhone，Watch App 已重新安装启动，待双端复测。每次 iPhone 更新后核对 Watch App 是否仍安装。不自行进入 Phase 7；移动场景应另测 maneuver、距离、车道和路况。

# Test Results

- 2026-10-06 Phase 5 副本：高德数据映射 2/2 定向测试通过；本轮修正环岛图标映射的定向测试 1/1 通过；官方 11.3.100 手动 SDK 的实体 iPhone Debug 构建、安装及启动通过。用户回报真实导航两次启动、停止后再次启动均正常；前台静止约 1 分钟时序号持续增加。
- 2026-10-06 正式 Pod 11.2.100：隔离副本 `pod install` 成功，模拟器 Debug 构建和实体 iPhone 签名构建均 `BUILD SUCCEEDED`；iPhone 安装及启动成功。正式 Pod 静止导航已获用户复测。
- 2026-10-06 Phase 5A 正式 Pod 静止复测：用户回报约 1–2 分钟内出现导航指令且序号持续增加，未报告错误或闪退。
- 2026-10-06 Phase 6 真机诊断：前台序号 0–5、Home 后台 7–9、锁屏后台 22–28 均有 SDK 回调与快照时间戳；停止后约 1 分钟无新回调/快照。详见 `PHASE6_BACKGROUND_RESULTS.md`。
- 2026-10-06 本轮 Watch 最小回归：配对 iPhone Air / Apple Watch Series 12 模拟器中，Mock 指令同步显示，序号至少到 13，停止后 Watch 回等待状态。
- 2026-10-06 实体 Watch 后续验证：Series 10 已被识别、安装、启动；Mock 前台约 1 分钟用户确认连续更新。真实高德一次过期不恢复；诊断复测用户确认持续更新。iPhone 记录序号 0–277，前 67 个 context 因 WCError 7006 失败，后 211 个被接受。随后最新版恢复修复已完成真机构建、双端安装和启动，功能复测尚未收到结果。详见 `WATCH_DEVICE_SYNC_RESULTS.md`。
- `swift test --disable-sandbox`：7 项通过，2026-10-05。
- iPhone scheme：Debug generic iOS Simulator 与 generic iOS device，禁用签名，BUILD SUCCEEDED；这是构建，不是安装/运行验证。
- 独立 Watch scheme：Debug generic watchOS Simulator，禁用签名，BUILD SUCCEEDED。
- iPhone scheme：Release generic iOS Simulator（含 Watch 目标），禁用签名，BUILD SUCCEEDED。
- 早期真机 9 项计划在该历史记录建立时全部 NOT TESTED；后续只完成了上述特定 Mock/高德场景，九项计划仍未逐项验收，详见 `DEVICE_TEST_RESULTS.md` 与 `WATCH_DEVICE_SYNC_RESULTS.md`。
- 配对模拟器最小联测：启动、持续更新、停止同步通过；详见 `SIMULATOR_TEST_RESULTS.md`。未执行扩展测试。
- 早期实体 iPhone 签名构建（含 Watch App）：BUILD SUCCEEDED；该条保留原始历史证据。实体 Watch 后来已安装、启动并完成有限功能验证，当前状态见上一条和 `WATCH_DEVICE_SYNC_RESULTS.md`。

# Environment

- Xcode 27.0 (27A266a)，Swift 6.4，iOS/watchOS SDK 27.0。
- 部署目标：iOS 18，watchOS 11；Bundle ID 为 `dev.local.NavigationWatch` 与 `dev.local.NavigationWatch.watchkitapp` 临时开发值。
- `sources/` 是只读镜像且当前为空；交付副本不含高德 SDK。任务工作区的隔离 `work/NavigationWatch-PodCheck/` 已安装正式 Pod，供本机真机构建；新窗口使用前需确认该目录仍存在。本机 Key 位于未打包的 `Config.local.xcconfig`，不得打印或加入交付包。

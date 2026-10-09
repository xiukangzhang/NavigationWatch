# Phase 10 — Navigation Enrichment Layer

更新：2026-10-07。Implementation PASS（专项测试及 Watch Debug fixture 范围）；本轮真实导航反馈已收取：定位提示偶发降级自动恢复、用户报告 Watch 退出；整体 PARTIAL，不记最终 PASS。

## SDK 事实与能力边界

安装依赖仍为 AMapNavi-NO-IDFA 11.2.100。以隔离 Pod 工程当前 Headers 为准，证据摘录见 work/phase10/sdk-public-api-evidence.txt。

- AMapNaviInfo.routeRemainTrafficLightCount：当前路线剩余信号灯数。统一 TrafficLightInfo.remainingCount，distance / state / countdown 均 nil；不把路线数量伪装成“最近交通灯距离”。负数为未知，0 为零个；UI 仅正数显示“路线剩余 X 个信号灯”。
- AMapNaviRoute 有 routeTrafficLights 坐标、路线/segment/link 灯数或标记，但未接入最近灯距离推导。
- 交通灯灯态：当前已核实公开普通驾车回调未提供本项目可读取的可靠灯态，supportsTrafficLightState=false。模型允许 nil，不把 unknown 或 Camera redLight 当真实红灯状态。
- Countdown：头文件有 setIsOpenTrafficLight:，AMapNaviDriveView.showTrafficLightView 为付费权限下 SDK 自带显示功能；没有核实可让本项目统一 Snapshot 读取 remainingSeconds 的公开数据回调，未开通/调用付费显示开关。不能把显示开关等同于可读数据。
- **Traffic-light countdown not available through currently verified public driving SDK API.** supportsTrafficLightCountdown=false，countdown=nil；这是正常能力边界，不计 Phase 10 FAIL。
- AMapNaviLocation.accuracy / timestamp / isNetworkNavi / isMatchNaviPath，AMapNaviDriveManager.gpsSignalStrength 及 delegate updateGPSSignalStrength 提供定位质量依据。未添加不存在的卫星数量或伪造精度。
- Camera SDK 无业务 event ID，提供固定电子眼 coordinate/type。Provider 将 routeID+type+微度量化坐标做 SHA-256，身份不使用动态 distance、speed、timestamp；原坐标不传入 Shared / Watch / 日志。缺有效坐标时退化为稳定 route/type slot，可能保守合并同类未知坐标事件，此限制不伪称全事件唯一。
- Road 身份采用 routeID、type、start/end segment/link；无精确剩余距离时保持 nil。

官方辅助参考：[AMapNaviCameraInfo](https://a.amap.com/lbs/static/unzip/iOS_Navi_Doc/interface_a_map_navi_camera_info.html)、[DriveManager delegate](https://a.amap.com/lbs/static/unzip/iOS_Navi_Doc/protocol_a_map_navi_drive_manager_delegate-p.html)。版本敏感结论以本机已安装 Headers / 实际编译结果为准。

## 架构与实现

NavigationCore / NavigationSnapshot 保持唯一状态源；Core、WatchConnectivity 和 session/sequence gate 未修改。AMap callbacks 只复制标量后切回 MainActor，SDK 对象不跨 actor。

- NavigationCapabilities 新增 supportsTrafficLightState，旧 payload 缺字段默认 false。高德已实现路径支持 lane/traffic/speedLimit/camera/roadEvents/trafficLight（仅 count），state/countdown false。Mock 未自动声称支持这些新能力。
- NavigationSnapshot version 1 增量可选 trafficLightInfo、locationQuality、speedLimitInfo、navigationEvents，CameraEvent/RoadEvent 可选 id；原 Phase 8 typed 模型和 legacy 字段保留。旧 payload 缺新字段安全解码；stopped 清理新字段。
- LocationQuality good/weak/stale/unavailable；保留 SDK 实际 accuracy/source timestamp/GPS signal/network/matched/providerAvailable。默认精度分类阈值 50、过期 15 秒；这是可配置项目策略，不声称 SDK 官方最优，也不把阈值写成测量值。无有效测量/无 source time/无 provider sample/明显未来源时间为 unavailable；弱信号、smart positioning、network、未匹配路线或精度超阈值为 weak；source age >15 秒为 stale。GPS raw enum 1/2/3 对应 strong/weak/smart，其他 unknown，不把 unknown 冒充 strong。
- 同一源 timestamp 不因 camera/light/road 辅助回调刷新；UI 有无后续 callback 都会检查 source age。weak 显示“GPS 信号较弱”，stale/unavailable 隐藏旧转向和距离；stale 显示“定位信息暂未更新”，unavailable 显示“定位暂不可用”。旧 payload/Mock 没有测量时不凭空给 GPS 评级。
- NavigationEventLifecycle 为轻量 route-scoped ledger，统一 camera/road/speedLimit 的 firstSeen/updated、removed/passed/expired。原模型未全部重写。相同身份只产生一次 firstSeen，callback 不随机生成 UUID；空列表立即 removed、距离 <=0 passed、道路 segment/link 越过后 removed；过期不被普通 guidance 回调续命。默认 maxAge 90 秒可配置，已 passed 身份同一路线不复活。丢失后重现保留首次出现时间，不重复 firstSeen；换 route/stop/reset 清理 ledger。
- SpeedLimitInfo 为 typed 生命周期源，legacy snapshot.speedLimit 从它派生，避免同一限速双份独立状态。
- Watch 优先级：turn → distance → lane → temporary camera/road → traffic → ETA。普通信号灯数仅无临时安全事件时作为补充提示，不抢车道。
- 本轮未加入 Haptic：现有 Watch 源码没有稳定 Haptic 路径；不为可选提示另建复杂震动架构。
- Phase 9 LiveActivity/Widgets 源码未修改，增强事件不进入 ContentState。因 Shared Codable 增量，仅额外执行一项既有 Activity mapping/encoding 测试，不重跑完整 Phase 9 lifecycle。
- 用户追加图标请求：iPhone/Watch AppIcon 均替换为用户蓝色方向盘 PNG，只做 1254→1024 方形缩放，不改画面；源图无 alpha，输出 AppIcon PNG 无透明通道。

## 最小测试与 UI 证据

21 项 Phase10Tests PASS + 1 项 Phase8 Snapshot/envelope 编码兼容 PASS + 1 项 Phase9 mapping/encoding PASS，总计 23，0 failures。未执行 Lane / Traffic / WatchConnectivity / session gate / Mock 或 Live Activity 全量回归。
覆盖 traffic count/unknown、四种定位状态与静默过期、GPS enum、camera stable identity、重复 callback firstSeen 仅一次、passed/empty/expired/route reset、road identity/越过过滤、event text appear/update/disappear、质量降级隐藏旧引导、旧 payload / stopped 清理 / capabilities。

实体 iPhone/Watch Debug build PASS，高德 AMap.bundle / AMapNavi.bundle 和既有 Widget 保留；双端新版本及新图标安装、启动 PASS。Watch simulator target build PASS。

Watch Series 12 42mm / watchOS 27 模拟器，DEBUG -phase10-lifecycle 同一 fixture session 依次 camera450→camera300→road→empty，间隔 8 秒。截图确认：测速文字、300 m 更新、路线施工、消失后恢复无事件布局；主转向/150 m/车道仍是独立核心信息。初次取图过早或转换过程中存在部分文字未稳定绘制，已补取稳定施工画面（road-stable.png），不拿中间不完整帧证明布局通过。weak.png 显示轻量弱信号提示；stale.png 隐藏旧转向与距离，仅提示定位暂不可用。
这属于 Debug fixture UI 证据，不宣称 SDK 真实产生施工事件，也不宣称已做新 WatchConnectivity 回归。

证据目录：<LOCAL_PROJECT_PATH>
直接证据 tests.log、device-build.log、watch-sim-build.log、camera450.png、camera300.png、road-stable.png、empty.png、weak.png、stale.png、双端 install/launch.json。设备日志与 Key 不入源码包。

## 当前结果

| 项目 | 结果 |
|---|---|
| Traffic Light | PASS：count Mapper/实现；真实 Snapshot count=13；无最近距离 |
| Traffic Light State | NOT SUPPORTED THROUGH CURRENTLY VERIFIED DATA API |
| Traffic Light Countdown | NOT SUPPORTED THROUGH CURRENTLY VERIFIED DATA API；付费 SDK view 开关不是可读数据 |
| Location Quality | PASS：实现、四状态测试、weak/stale Watch fixture |
| Camera Lifecycle | PASS：身份/更新/通过/空回调/过期专项测试；本轮真实 redLight 307→302 m，stable ID、firstSeen 一次；真实通过消失未独立证明 |
| Event Dedup | PASS：同一事件 firstSeen 仅一次，无重复震动路径 |
| Watch Event Text | PASS：Debug fixture 显示、更新、移除恢复与截图 |
| Real Speed Limit | NOT OBSERVED ON CURRENT ROUTE |
| Real Road Event | NOT OBSERVED ON CURRENT ROUTE |

## 本轮真机观察与用户问题

用户在短正常导航后反馈：“有时候会跳出来定位暂不可用（一会自动会恢复），watch会闪退，其他正常”。其他正常包含图标反馈；不将泛化反馈当作真实限速/非空 Road Event 的观察证明。

- iPhone 当前缓存覆盖北京时间 21:31:39–21:32:25、session A2CE00B2-E997-4FF7-B614-A6EC8FAD27C5。真实 TrafficLight count=13；Camera redLight 307→302 m，身份一致，event_firstSeen 一次；Road SDK 两次空列表，未见真实限速。STOP sequence=62。该缓存仅覆盖这一小段，不能替代用户整段体验。
- 34 个 location_quality 样本全部 weak，accuracy 约 5.9–7.4 m、gpsSignal=weak、source age 约 0.07–1.14 秒；未记录 unavailable。UI 无新测量超过 15 秒会按策略 stale 并隐藏旧引导，但未将用户看到提示的时刻与源测量精确关联，所以定位降级原因仍 UNKNOWN，不能宣称已修复。
- 初次取 Watch 诊断失败为 CoreDevice tunnel timeout，不能当 App crash。重试成功：Watch 当前 PID 982 / run 870E2E15-0E11-4CAD-80AE-1631DFBFCD34，自 21:27:36 启动到 21:32:30 日志连续，无新 app_launch；当前 process 查询仍 PID 982。正常记录多次 scene_inactive / scene_background / scene_active，Watch 在 21:32:04 应用本段 sequence61，21:32:30 应用停止 sequence62。
- 当前 Watch systemCrashLogs 完整列表未发现 NavigationWatch IPS 或 Jetsam 报告。用户“闪退”报告保留为 USER REPORTED WATCH EXIT / ROOT CAUSE UNKNOWN；同 PID 仅说明此次取证没有进程重启证据，不否定用户看到回到表盘，也不能伪称 ROOT CAUSE FIXED。用户后续反馈“4.会偶然发生，又会恢复正常。15.目前还未出现”：定位提示仍偶发并自行恢复，Watch 退出目前未再次出现；未提供退出时机及重开行为，不能改写为已修复或证明是系统正常返回表盘。
- iPhone crash list 本轮最新仍为 18:10:24，早于 Phase10 安装/本段导航；无本段新增 iPhone IPS。
- 历史 Phase7.5 定向测试结果保留为历史证据，不覆盖此次用户退出报告。

直接证据 real-observation-summary.json、navigation-snapshots.jsonl、watch-diagnostics-current.jsonl、watch-crash-list-retry.json、watch-all-crash-list.json、watch-processes.json 和 phone-crash-list.json。日志不包含坐标/道路名/Key，不打入源码交付包。

## Gate

Implementation PASS 仅限专项测试/fixture 范围。真实验收 PARTIAL / WATCH EXIT REPORTED；定位降级提示与 Watch 退出体验尚未收口，不记 Phase10 最终 PASS。当前没有新复现可用于确定 Watch 退出原因；保留历史及本轮报告。定位偶发降级的具体触发原因仍 UNKNOWN。后续仅在正常使用再次发生时记录时间与前后台行为，按对应证据做最小修复及验证；不追加专门道路测试。不得为测速/道路事件绕路，不进入第二地图 Provider、倒计时逆向或 CarPlay。

## 本轮继续：区分定位过期与不可用

2026-10-07，用户要求继续后完成如下直接相关改动：

- 原 stale/unavailable 都显示“定位暂不可用”，现双端使用统一 warning：stale 为“定位信息暂未更新”，unavailable 保留“定位暂不可用”；weak 不变。15秒过期阈值、源 timestamp、旧引导隐藏规则不变。此为显示含义修正，不是定位中断根因修复。
- 双端 DEBUG 在定位有效状态变化/视图首次出现时记录 location_quality_display / quality_display，包含源状态、显示状态、定位源年龄、快照年龄和 session/sequence，不含坐标/道路名。Watch 复用有界 journal；Release 不写该记录。未修改 WatchConnectivity、Core、ActivityKit 或 SDK 取样逻辑。
- 当前 Phase10Tests 21项全部 PASS；只执行 Phase10专项，无全量项目或其他阶段回归。实体双端 build PASS，签名产物本地配置及两个高德 bundle核对通过；双端安装成功，iPhone启动成功。Watch实体启动因系统 Locked拒绝，随后用户解锁打开并反馈“完成”，实体Watch手动启动PASS（用户反馈）；Locked拒绝不计应用崩溃。
- Watch simulator build PASS。第一次系统Carousel启动失败，重启该模拟器后成功启动fixture；followup-stale.png显示新提示、旧转向/距离隐藏，followup-quality-display.json确认effective=stale/source=stale/sourceAge=20.05/snapshotAge=0.05。系统shell失败不作为导航App crash证据。
- 不追加道路导航测试。用户最新反馈 Watch退出目前未再次出现；既往退出及定位偶发降级原因继续UNKNOWN。整体Phase10保持PARTIAL，不记ROOT CAUSE FIXED。

本次证据：followup-tests.log、followup-device-build-config.log、followup-watch-sim-build.log、followup-stale.png、followup-quality-display.json、followup-phone/watch-install.json、followup-phone/watch-launch.json。实体Watch随后由用户解锁打开确认完成；本轮未重新开展道路导航。

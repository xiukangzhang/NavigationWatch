# Phase 7 — Lane Guidance + Traffic

日期：2026-10-07，北京时间。正式 SDK：AMapNavi-NO-IDFA 11.2.100。本轮只做车道与路况，不进入其他功能或 Provider。


## 最后一次短时复测结论（2026-10-07）

用户按提示复现熄屏返回/通信诊断后回复“已正常”。console 捕获期间没有取得 Watch 崩溃退出记录；捕获后设备进程列表仍为 PID 900，结束本地捕获客户端后同一 Watch PID 900 继续存在。终止的是本机 devicectl 捕获进程（其 exit 137），不是 Watch App，不把该退出码写成 Watch crash。

**本次短时复测：正常 / 未复现。此前闪退报告根因：UNKNOWN / 尚未定位。** 未新增代码修复，不声称已经消除所有间歇性闪退；不增加复杂压力测试，暂停进一步功能扩展并按用户本轮范围停止。

最终手机日志为北京时间 16:48:57–16:56:11，真实非空 traffic_raw 10 次，congestion 数据已映射 slow，快照至少到 114；lane_raw 0 次，真实车道仍 NOT OBSERVED ON CURRENT ROUTE。最后提取时本次 Phase 7 导航仍运行，未取得 stop_completed，需要用户在 iPhone 点击停止。此前 Step 1 的停止验收已经通过，不和本次新路线混淆。

## 先前 Watch 稳定性失败报告

**FAIL（用户报告，尚未定位退出原因）**。Phase 7 最终安装版在“熄屏返回或打开通信诊断时”被用户报告闪退。前一阈值修复版 A–D PASS 保留为历史限定证据，不能替代此新版稳定性验收。暂停 Phase 7 验收与新功能扩展，仅定位并修复失败链路。

实体 Watch systemCrashLogs 本次没有返回 NavigationWatchWatch 崩溃报告，手机日志中也没有最新 Watch 崩溃报告；复查时 Watch 进程仍在运行。上述结果不能否认用户报告，也不能单独判定为系统返回表盘。已启动 Watch console 捕获，等待一次同场景复现。

## Physical Watch real navigation sync（Phase 7 前已测版本）

**PASS（本轮 A–D 已测范围）**。实体 iPhone Air → 实体 Apple Watch Series 10。5 秒源时间阈值与已观察最长 52 秒导航回调间隔不匹配；默认可配置阈值已调整为 90 秒，超过阈值继续隐藏旧引导。用户确认恢复版持续显示、熄屏返回、停止回等待均正常，无闪退。16:29:50 手机 stop_completed 后采集日志没有新活跃快照。见 WATCH_DEVICE_SYNC_RESULTS.md。

未确认实际移动；不将结果推广为移动精度、长期稳定性或精确延迟验收。Phase 7 双端安装不替代同步复测结论。

## Lane mapper

**PASS**。复用 LaneGuidance / Lane / LaneDirection，新增独立纯数据 AMapLaneMapper；旧 AMapSnapshotMapper.lanes 入口委托到新 mapper。官方 lane code 输入经过明确映射，Shared 与 Watch 不导入高德类型。

- 0/13 straight；1 left；2 straightLeft；3 right；4 straightRight。
- 5/8 为单一左/右掉头，统一为 uTurn（模型不区分掉头左右手性），不再误作“转弯加掉头”。
- 6 left+right；7 straight+left+right；9/10 straight+uTurn；11/14 leftUTurn；12 rightUTurn。
- 16 straight+leftUTurn；17 right+uTurn；18 leftUTurn+right；19 straightRight+uTurn；20 left+uTurn。
- 21 busOnly、23 variable，方向 unknown。15/22/未来未定义或无效值保持 unknown，不猜测。
- selected=255 表示当前路线不可选该车道，restricted=true；已知 background/selected 才标 recommended。畸形值不伪造成明确限制或推荐；空或数量不符的输入返回 nil。
- show/hide 回调立即更新统一快照；补充事件推进 sequence，但沿用最近导航引导的原始 timestamp，不凭车道/路况刷新旧转向有效期。开始、停止、路线切换清除旧补充状态。

## Real lane callback

**NOT OBSERVED ON CURRENT ROUTE**。最新正式高德导航日志为北京时间 16:48:57–16:51:07，未记录 lane_raw / lane_mapped。此结论只表示本次路线未观察到，不是 FAIL；没有用 fixture 替代真实道路回调。

## Traffic mapper

**PASS**。复用 TrafficState / TrafficStatus。SDK 状态 1/6→smooth、2→slow、3→congested、4→已有 severe；0/5/未定义→unknown。未新增 wire enum，保持版本 1。

- updateTrafficStatus 可靠保存路线状态；均匀路况映射对应统一状态，混合路段保持 unknown，不把最严重一段伪作当前位置路况。
- updateCongestionInfo 转为最近拥堵状态。SDK remainDistance 映射 congestionLength（已进入时为剩余长度）；没有前方拥堵起点距离就保持 congestionDistance=nil。明确已在区域内时 distance=0。
- SDK remainTime 是穿过拥堵段的时长，不是额外延误，estimatedDelay 始终 nil。没有从 ETA 差值推测延误。
- 拥堵 nil 回调清除旧拥堵状态；算路阶段提前返回的路况被保留至 GPS 导航开始。路线切换清除旧数据。
- Swift 正式导入的拥堵回调名称为 driveManager(_:update:)；最终正式 Pod 编译验证通过。

## Real traffic callback

**PASS（真实回调进入统一模型，未完成 Watch 新版稳定性验收）**。北京时间 16:49:07，traffic_raw 数组 [0,1,2,3,4,3,2,3,2,1,2,1,0] 映射 unknown（混合路段不猜当前位置）；congestion_raw 的 statusCode=2、remainingLength=3334、inArea=false 映射为 slow。16:50:06、16:51:05 继续收到拥堵回调并更新映射，长度 3757 m。该字段是拥堵段长度，不是到拥堵起点距离或估算延误。手机快照序号在这次导航中至少到 17；Watch 回调显示/稳定性仍被闪退报告阻塞。

## UI、能力与日志

- 普通 Watch 导航继续保持原结构；有车道且路口距离为 0–500 m 时显示，各车道使用组合方向符号；推荐车道有蓝色箭头和圆点。多车道可横向滚动，空车道数组/nil不显示空行。SDK hide 回调清除车道。
- 路况只显示一行，例如“前方拥堵”；unknown/nil不展示。当前区域内使用“当前拥堵”。不把拥堵长度写成前方起点距离。
- iPhone 加入同一统一模型的最小车道与路况文本，不重设计地图或页面。
- 正式 Provider 与所产快照已启用 supportsLaneGuidance / supportsTraffic：公开 API 已确认、回调及映射已实现、正式 SDK 构建通过。不暗示当前路线一定会触发。
- Debug 记录 lane_raw、lane_mapped、lane_hidden、traffic_raw、traffic_mapped、congestion_raw、congestion_mapped；本地日志保留编码/计数，系统 Debug 日志保留完整统一映射。无坐标、道路名、Key 或完整轨迹。Release 不执行这些记录，也不包含 fixture 启动参数分支。

## 最小测试

| 检查 | 结果 | 边界 |
|---|---|---|
| Lane / Traffic mapper、Snapshot 字段传播及 UI 显示条件 | PASS，5/5 定向测试 | 全部官方已定义方向、unknown、推荐与标志、畸形输入、路况状态、nil/非法距离、未推测延误、近/远/空车道 |
| Snapshot Coding | NOT REQUIRED | Snapshot / Lane / Traffic 的 Codable 字段及 version 1 未改，只增加纯函数和展示计算属性 |
| 正式 Pod 双端设备签名构建 | PASS | 最终 build exit 0，包含 AMap 11.2.100 回调实现 |
| Watch 42mm 模拟器有车道 fixture | PASS | 视觉核对 ↑ ↑ ↑→ →、推荐圆点与“前方拥堵”可读 |
| Watch 42mm 模拟器无车道 fixture | PASS | 普通导航保持，无空车道或路况行 |
| 最终 Phase 7 双端安装 | PASS | iPhone 安装并启动；Watch 同一构建配套 App 直接安装，之后手机最终更新后 Watch 安装清单仍有 App |
| Phase 7 Watch 远程启动 | 设备锁屏拒绝 | 需要用户解锁手动打开；不记为 App crash |
| 当前道路真实回调 | 车道 NOT OBSERVED / 路况 PASS | 新版 Watch 稳定性因用户闪退报告未通过 |

未运行无关全量测试。两端源码与正式 Pod 构建副本 7 个相关源文件逐字一致，Shared/Watch 无 SDK imports。构建临时 Key 已清理；交付包必须排除 Config.local.xcconfig、Pods 和构建产物。

## 公开 API 依据

以本机正式 11.2.100 Headers/AMapNaviDriveDataRepresentable.h、AMapNaviCommonObj.h 为版本依据。在线手册显示 11.3.100，已和安装头文件逐项核对，只用 11.2.100 存在的字段：

- [官方车道、路况及拥堵回调](https://a.amap.com/lbs/static/unzip/iOS_Navi_Doc/protocol_a_map_navi_drive_data_representable-p.html)
- [官方路线交通状态对象](https://a.amap.com/lbs/static/unzip/iOS_Navi_Doc/interface_a_map_navi_traffic_status.html)

## 当前边界

Mapper 与最小显示已完成；真实路况回调进入统一模型已观察，真实车道回调本次路线未观察。当前只定位最新 Watch 闪退报告，未通过新版稳定性回归。不扩展红绿灯、Live Activity、其他地图 Provider 或其他功能。


## 本轮已结束（2026-10-07）

用户确认导航已经结束。实体 iPhone 日志记录北京时间 16:58:00 stop_completed，结束后采集日志无新活跃 snapshot。本次 Phase 7 路线停止已确认，不再等待用户停止；本轮任务结束，不继续功能开发或追加测试。真实车道 NOT OBSERVED ON CURRENT ROUTE，真实路况 callback PASS；此前退出报告本次复测未复现，根因仍 UNKNOWN。

## 2026-10-07 后续最小实测自然观察

18:11:44 真实高德 lane_raw background=2|3、selected=1|255，lane_mapped laneCount=2、recommendedLanes=[0]。Real lane callback 现为 PASS（SDK → Mapper → 统一模型）；此前路线 NOT OBSERVED 保留为历史。不扩大为本次实体 Watch 车道 UI 验收。证据 work/phase8/iphone-final.jsonl。

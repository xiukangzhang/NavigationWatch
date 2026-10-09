# 新窗口接续：NavigationWatch

更新：2026-10-07，北京时间。先读本页，再按所选任务读 `PROJECT_STATUS.md` 与对应结果记录。可编辑交付副本是本文件所在项目根目录 `outputs/NavigationWatch-Phase5/`；原 ChatGPT 同步镜像是只读参考，不要回写。该副本没有 Git，不要为本任务创建 `.git`。

## 本轮结束状态

用户已确认导航结束；手机日志北京时间 16:58:00 stop_completed，之后无新活跃 snapshot。本轮任务结束，不再等待用户停止，不自动继续测试或其他功能。其余结论以 PHASE7_LANE_TRAFFIC_RESULTS.md 最新记录为准；以下保留此前诊断过程。

## 最新用户反馈：同场景已正常

用户按提示再次复现熄屏返回/通信诊断，回复“已正常”。console 期间未捕获崩溃，同一 Watch PID 900 在结束本机捕获后仍运行。本次短时复测正常，早前闪退根因 UNKNOWN，不新增猜测性修复、不宣称全部已消除。Phase 7 的 mapper/最小展示已完成；真实 lane callback NOT OBSERVED ON CURRENT ROUTE，traffic callback 进入统一模型 PASS，最终手机序号至少 114。本次新路线提取时仍导航，需用户停止。用户本轮任务结束，不自动继续其他功能。

## 此前优先事项：新版 Watch 闪退报告

Phase 7 版被用户报告在熄屏返回或打开通信诊断时闪退，稳定性回归 FAIL；先仅定位修复。已知设备崩溃目录未取得对应 Watch 报告，查询时进程仍在，console 捕获已启动，待用户同场景复现。真实路况 callback 已进入统一 mapper（slow，拥堵长度 3334→3757 m）；真实车道本次路线 NOT OBSERVED。此前 A–D PASS 属于 Phase 7 前阈值修复版，不替代新版验收。文档详细证据见 PHASE7_LANE_TRAFFIC_RESULTS.md 最新回归。

## Phase 7 此前接续（2026-10-07）

Lane / Traffic mapper 与最小双端显示已经完成，5 项定向测试、正式 Pod 双端构建、42mm Watch 有/无车道显示检查通过。最终版已安装到双端，iPhone 已启动，Watch App 安装清单已确认存在；远程启动被锁屏拒绝，待用户手动打开。真实 lane/traffic callback 当前 UNKNOWN：最新提取日志仍是 16:24–16:29 的同步验收，最终 Phase 7 导航尚无新开始事件，不能把旧日志无事件当成“本次路线没有触发”。

下一步仅完成已请求的当前路线短时导航（约 1 分钟后停止），提取 Debug lane_raw/mapped、traffic_raw/mapped、congestion_raw/mapped，更新 PHASE7_LANE_TRAFFIC_RESULTS.md。若该次路线确实未触发，标 NOT OBSERVED ON CURRENT ROUTE，不标 FAIL，不专门长距离驾驶。本轮除此之外停止，不进入其他功能。

## 当前最新门槛（2026-10-07）

真实同步 A–D 阈值修复后已由用户确认正常，无闪退，已测范围 PASS；PROJECT_STATUS.md 已标 Physical iPhone → Physical Apple Watch real navigation sync verified。Phase 7 开始，仅 Lane Guidance + Traffic。移动/长期/精确延迟仍未验证。以下为修复前接续记录，不再阻止 Phase 7。

## 修复前最小接续（2026-10-07）

先完成用户指定的真实导航 A–D，不进入 Phase 7。A 已由用户确认正常，Applied 序号已观察 12→16→23→30，无闪退；熄屏返回仍显示过期，C FAIL，D 未测。本轮总体 FAIL / 未完成验收，见 WATCH_DEVICE_SYNC_RESULTS.md 最新记录。

旧 5 秒源时间阈值小于本次 SDK 回调间隔（最大已观察 52 秒）。已仅调整 Watch 默认阈值为 90 秒，源时间、sequence 及旧会话拒绝不变；2 项定向测试和 Watch 真机构建通过。新版 Watch 安装启动成功，iPhone 未更新。下一步请用户返回导航主页面，观察约 1 分钟并熄屏返回一次，确认 B/C；随后 Stop Navigation 验证 D。安装启动不能替代功能 PASS，移动场景仍未验证。A–D 全部通过后，才按用户新任务进入 Phase 7。

## 此前结论（历史阶段证据）

| 范围 | 状态 | 已有证据 / 边界 |
|---|---|---|
| Phase 5A 高德驾车基础接入 | PASS（实体 iPhone 静止导航） | 正式 `AMapNavi-NO-IDFA` 11.2.100 Pod 构建、安装、算路、指令和新增快照已验证；移动中的转向、距离、车道、路况未验证。见 `PHASE5_INTEGRATION_RESULTS.md`。 |
| Phase 6 iPhone 后台导航 | PASS（已测范围） | 实体 iPhone 前台、Home 后台、锁屏期间有 SDK 回调和新增快照；停止后约 1 分钟无新回调/快照。见 `PHASE6_BACKGROUND_RESULTS.md`。 |
| 实体 Watch 同步 | PARTIAL / NOT COMPLETE | Series 10 已被设备工具识别。Mock 前台约 1 分钟由用户确认正常；真实高德一次出现过期且不自行恢复，诊断复测一次由用户确认持续更新。稳定性、熄屏恢复和最新修复版仍未通过完整真机验收。见 `WATCH_DEVICE_SYNC_RESULTS.md`。 |
| Logo | 已交付 | iPhone 与 Watch 均为蓝底白色导航箭头 App Icon；构建产物已核对。 |

## 最后一次设备操作与待做事项

1. 2026-10-06 约 16:37，实体 iPhone Air（iOS 26.6）已安装并启动最新版 Debug App；实体 Apple Watch Series 10（watchOS 26.6）在 iPhone 更新后曾失去配套 App，已从同一次构建的 `NavigationWatch.app/Watch/NavigationWatchWatch.app` 单独重装并启动，Watch 截图显示“等待 iPhone 导航”。安装/启动是已验证；**该修复版的双端真实导航功能尚未得到用户复测回复**。
2. 下一项最小验收：在两端打开 App，用此前成功的终点启动高德驾车，Watch 保持前台约 1 分钟；记录 Watch 是否持续显示真实指令、是否再次出现“导航信息暂未更新”且不恢复。完成后停止导航。测试时须处于安全静止状态。
3. 如果再次失败，先读取 iPhone 本机 `Library/Caches/navigation-snapshots.jsonl` 的 `wc_state_*`、`wc_context_*`、`wc_message_error_*` 与 `snapshot` 事件，再看 Watch 诊断页；不要先改高德业务代码。调试记录不含坐标、道路名或 Key。
4. 如果本次通过，只能记为这一次前台短时 PASS；Watch 熄屏/抬腕恢复、断连重连、长期延迟和移动导航仍为 `UNKNOWN / 尚未验证`。是否继续这些用例由新任务范围决定，不自动进入 Phase 7。

## 已发现的中断原因与修复

- 诊断复测中，iPhone 的前 67 个真实高德快照对应 `watchAppInstalled=false`、`reachable=false`，`updateApplicationContext` 返回 WCError 7006（Watch App 未安装）；约 1 分钟后系统识别恢复，后续 211 次 context 被接受，用户确认 Watch 持续显示真实指令。这证明该次初期延迟与系统安装识别有关，不能证明此前不恢复问题的唯一根因。
- 最新代码在 iPhone `WatchSyncCoordinator.sessionWatchStateDidChange` 发现 Watch App 从未安装变为已安装时立即重发最新快照；正式 Pod 真机构建通过、iPhone 已安装。恢复行为仍待真机复测。
- 本轮直接更新 iPhone App 后，Watch 的开发 App 安装清单确实为空。已经重装恢复。**今后每次更新 iPhone App 后，先检查 Watch 上的 App 是否仍安装，再测试通信**；不能把 `WCError 7006` 一概认作通信代码故障。
- Watch 页面已区分“导航状态过期”和实时通道不可用，回到前台会重新激活、读取 context、主动拉取；这些改动已构建并经此前 Mock 真机短时验证。

## 开发环境与保密边界

- Xcode 27.0；Bundle ID：iPhone `dev.local.NavigationWatch`，Watch `dev.local.NavigationWatch.watchkitapp`。真机：iPhone Air `<LOCAL_DEVICE_ID>`，Watch Series 10 `<LOCAL_DEVICE_ID>`。设备当前能否连接需新窗口实时确认。
- 正式 Pod 的隔离构建目录为任务工作区 `work/NavigationWatch-PodCheck/`，其中有 `.xcworkspace`、Pods 和锁定的依赖；交付目录本身不含 SDK。新窗口先检查路径是否仍存在。实际 Key 只在本机 `Config.local.xcconfig`，不要打印、提交或加入压缩包。临时复制到 Pod 构建目录后必须清理。
- 交付包 `outputs/NavigationWatch-Phase5.zip` 应包含源码、图标和文档，不包含 `Config.local.xcconfig`。更新文档或源码后重新打包，并检查排除项。
- 各阶段旧的“Watch 未被识别”和“真机 9 项未测试”记录是当时的历史基线；当前设备发现与本轮小范围真机结果以 `WATCH_DEVICE_SYNC_RESULTS.md` 和本页为准，不得把历史状态当成现状，也不得把少量已测场景推广为全部 9 项通过。

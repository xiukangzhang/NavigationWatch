# 实体 Watch 同步稳定性跟进

日期：2026-10-06。设备：实体 iPhone Air（iOS 26.6）与 Apple Watch Series 10（watchOS 26.6）。此任务发生在 Phase 5A/6 静止 iPhone 验收之后，不改变两阶段原有结论。

## 用户报告与当前边界

- 用户报告实体 Watch 已可连接，但与 iPhone 的通信会中断，导航信息有延迟；尚未给出可复现的停顿时长或场景。
- `devicectl list devices` 现已识别实体 Series 10，状态 `available (paired)`。Watch App 已安装且进程曾运行。不能以设备配对、安装或启动作为同步稳定性 PASS。
- Apple 官方将 `WCSession.isReachable` 定义为对端当前可接收**实时消息**；`false` 不等于物理配对断开。`updateApplicationContext` 只保留最新状态，后台交付可延迟。[Apple WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity/wcsession/isreachable)；[数据传输说明](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity)。
- Phase 6 真机记录显示手机静止时高德 SDK 可能近 1 分钟没有新的导航信息回调；原 Watch UI 的 5 秒过期判断会很快隐藏旧转向并错误显示“正在重新连接”，即使传输没有断开。此问题会造成中断观感，但不能解释全部真实传输延迟。

## 最小修复

- Watch 回到前台时重新激活会话（若有必要），读取最新 context 并主动 pull 最新快照。
- Watch 将快照过期与实时消息不可用分开表述；过期后仍隐藏旧转向，避免误导，不把 `isReachable == false` 写成“物理连接中断”。
- Watch Debug 配置补齐 `DEBUG`，诊断页可以编译；移除 watchOS 不支持的文字选择修饰符。
- 新增 iPhone 和 Watch 共用的蓝底白色导航箭头 App Icon，1024 × 1024，构建产物两端均声明 `AppIcon`。
- iPhone Debug 本地记录每次快照的会话激活、配对、Watch App 安装识别、实时可达状态、context 接受或错误码，以及实时消息错误码；不记坐标、道路名或 Key。
- iPhone 收到 Watch App 安装识别从 false 恢复为 true 的系统通知时，立即重发当前最新快照；代码和正式 Pod 真机构建通过，双端功能复测待完成。

## 本次证据

| 检查 | 状态 | 证据 |
|---|---|---|
| 正式 Pod 11.2.100 双端真机构建 | PASS（构建） | 更新后的 `.xcworkspace` iPhone 设备签名构建 exit 0；两个 App 产物包含图标资源 |
| 实体 iPhone 安装 | PASS（安装） | `devicectl` 返回 `App installed`；远程启动因设备锁屏被系统拒绝，需用户解锁后操作 |
| 实体 Watch 安装/启动 | PASS（安装/启动） | `devicectl` 对实体 Series 10 返回 `App installed`、`Launched application` |
| 配对模拟器 Mock 最小回归 | PASS（模拟器） | 当前源码无 Pod 模拟器构建，iPhone Mock 序号至少升到 86；Watch 显示导航指令，停止后回到等待页。首次同步曾短暂等待，未计量精确延迟 |
| 实体 Watch Mock 连续更新 | PASS（用户观察，前台约 1 分钟） | 用户解锁并在 iPhone 启动模拟导航，让 Watch App 保持前台，确认“Watch 指令正常更新，没有中断或延迟”。未独立提取 Watch 端序号/时间日志；Watch 休眠恢复仍未测试 |
| 实体 iPhone 高德 → 实体 Watch | FAIL（本次前台静止联测） | 用户使用同一终点，确认 Watch 初始出现真实高德指令，但显示“导航信息暂未更新”后没有自行恢复。iPhone 本地诊断显示 15:57:29–15:58:39（北京时间）SDK 回调继续产生序号 0–7；15:59 的 iPhone 截图序号已到 23，Watch 同时截图显示“实时通道暂不可用”。因此至少在这次条件下，新的手机快照没有及时到 Watch；不能归因于高德静止回调稀疏。用户 16:13 提供的 iPhone 通信诊断截图显示 Activation rawValue 2（已激活）、Paired Yes、Watch app installed Yes、Reachable No；这是截图当时的状态，不能单凭它判断整个导航时段的实时通道状态。 |
| 实体 iPhone 高德 → 实体 Watch 诊断复测 | PASS（本次前台连续更新，非长期稳定性） | 用户回报 Watch 真实高德指令持续更新。iPhone 记录 16:21:29–16:26:38（北京时间）产生序号 0–277。前 67 个快照时系统暂报 Watch app installed false、reachable false，context 均返回 WCError 7006（Watch App 未安装）；16:22:37 起识别恢复，随后 211 次 context 接受，实时通道大部分时段 reachable true。16:24 的双端截图显示同一条“2号枢纽”直行引导。此证据解释了本次初期延迟，但不能证明前一次不恢复的唯一根因。 |
| 更新 iPhone App 后 Watch App 消失 | 已确认并恢复 | 安装新 iPhone 构建后，用户报告 Watch 找不到应用。`devicectl device info apps` 在实体 Series 10 返回空的开发 App 清单；从 iPhone 构建产物内的 `Watch/NavigationWatchWatch.app` 直接安装后，清单列出 `dev.local.NavigationWatch.watchkitapp`，远程启动成功，截图显示“等待 iPhone 导航”。这一部署过程会导致 Watch 暂时无法收状态；每次 iPhone 更新后需核对手表安装并按需恢复。不能由此推断此前所有 7006 均由同一原因造成。 |

当前实体 Watch 同步稳定性：**PARTIAL / NOT COMPLETE**。Mock 前台约 1 分钟通过；真实高德第一次持续同步失败，第二次 iPhone 导航约 8 分钟，用户在其中报告 Watch 连续更新，16:24 双端截图的指令一致。诊断明确看到系统开始时暂报 Watch App 未安装并拒绝 context，随后安装识别自行恢复；后续一次 iPhone 更新确实让 Watch App 从安装清单消失，已单独重新安装恢复。已新增安装识别从 false 变 true 时重发最新快照的定向修复，正式 Pod 真机构建、实体 iPhone 安装和启动通过，修复版双端运行待复测。Watch 休眠/唤醒、长期稳定性仍未验证，不声称已经消除全部延迟。


## 2026-10-07 最新修复版真实导航 A–D 复测

本次实体 iPhone Air → 实体 Series 10，正式 Pod 高德真实导航。用户未确认是否实际移动，因此移动场景为 UNKNOWN / 尚未验证。

- 设备工具再次识别两台实体设备；Watch 开发 App 清单为空，用户确认找不到 App。恢复上一轮正式 Pod 构建中的 Watch App 后，安装及启动成功。
- A 导航开始：PASS（用户观察）。Watch 从等待页进入导航、显示所需字段，无闪退。
- B 持续同步：PARTIAL / NOT COMPLETE。用户报告 Applied 12 → 16 → 23；截图显示 Applied 30。证明部分持续接收应用，但导航主页面仍显示“导航信息暂未更新”，未通过完整连续显示验收。没有观察证据证明或否定全部旧状态覆盖问题。
- C 熄屏返回：FAIL（本版页面恢复表现）。用户唤醒返回后仍显示“导航信息暂未更新”，Applied 23，无闪退。不将此单独认定为通信断连。
- D 停止导航：NOT TESTED，本次尚未取得停止结果。
- 本次真实导航同步整体：FAIL（A–D 未全部通过；存在 C 页面恢复失败）。Phase 7 NOT STARTED。

### 定向诊断

手机本地日志（北京时间 16:15:06–16:21:59）快照序号 0–27，context 被系统接受，未记录 wc 错误；这不能证明 Watch 全部及时收到。16:15:19→16:16:05 间隔 46 秒，16:18:10→16:19:02 间隔 52 秒。用户 Watch 截图 Applied 30、Last update 9.9 s、Snapshot age 23.6 s：接收消息时间与源快照时间不同；重复 pull/context 不会刷新源时间。

原 Watch 5 秒源时间阈值小于本次 SDK 回调间隔，已确认可导致正常收到最新状态后页面仍被隐藏。尚未排除其他通信延迟；不以手机 context 接受作为双端同步 PASS。

### 本次最小修复及验收边界

Watch 默认可配置源时间阈值由 5 秒调整为 90 秒。统一为 StaleStatePolicy.watchDefaultThreshold，快照源时间、session/sequence 过滤、MainActor 回调路径不变；重复旧快照不会刷新有效期。超过 90 秒继续隐藏旧引导。该值用于本次设备回归，不代表移动导航延迟或长期可靠性已经验收。

- 定向策略测试：PASS，2/2。覆盖 23.6/52/60 秒源间隔、90 秒边界、超时隐藏、编码后的旧快照仍过期、停止态不显示过期提示；未执行无关全量测试。
- Watch 单目标实体签名构建：PASS。
- 仅 Watch 修复版安装及启动：PASS；未重新安装 iPhone。
- 阈值修复后的 B/C 与 D 真机复测：UNKNOWN / 尚未验证。等待用户复测，不提前标 PASS。


## 2026-10-07 阈值修复后的 A–D 验收结论

Physical iPhone → Physical Apple Watch real navigation sync：**PASS（本轮已测范围，用户观察 + 手机日志）**。

A 导航开始、所需字段显示已由用户确认；Watch 阈值修复版安装启动后，用户确认保持导航约 1 分钟及熄屏约 15 秒返回均正常（B/C），再确认 iPhone 停止后 Watch 回等待页、无旧路线及活跃更新（D）。用户明确确认无闪退。手机日志记录北京时间 16:29:50 stop_requested / stop_completed，停止后采集到的日志没有新活跃 snapshot。手机最后活跃序号 53；Watch 独立应用序号截图 30，后续恢复与停止以用户观察为依据，不虚构后续 Watch 序号或精确延迟。

此前 A–D 失败记录属于修复前证据，保留追溯。90 秒阈值不代表 90 秒以内所有延迟均被验收。未确认实际移动，移动转向/距离准确性、长期连接、弱网、精确延迟分布仍 UNKNOWN / 尚未验证。本轮完整同步验收门槛已满足，允许进入用户限定的 Phase 7 Lane Guidance + Traffic。


## 2026-10-07 Phase 7 版稳定性回归失败报告

用户报告新版 Watch 在熄屏返回或打开通信诊断时闪退。**最新版本稳定性 FAIL（用户报告，根因待定位）**；前一阈值修复版 A–D 的 PASS 保留为历史限定结果。设备崩溃目录尚未取得匹配的 Watch 报告；查询时进程仍在，不能据此否认用户报告或直接认定为正常熄屏。当前正捕获一次重现，仅修复该失败链路。真实路况数据已在手机进入统一 mapper；不把该结果扩大为 Watch 显示稳定性 PASS。

## 最后一次短时复测结论（2026-10-07）

用户按提示复现熄屏返回/通信诊断后回复“已正常”。console 捕获期间没有取得 Watch 崩溃退出记录；捕获后设备进程列表仍为 PID 900，结束本地捕获客户端后同一 Watch PID 900 继续存在。终止的是本机 devicectl 捕获进程（其 exit 137），不是 Watch App，不把该退出码写成 Watch crash。

**本次短时复测：正常 / 未复现。此前闪退报告根因：UNKNOWN / 尚未定位。** 未新增代码修复，不声称已经消除所有间歇性闪退；不增加复杂压力测试，暂停进一步功能扩展并按用户本轮范围停止。

最终手机日志为北京时间 16:48:57–16:56:11，真实非空 traffic_raw 10 次，congestion 数据已映射 slow，快照至少到 114；lane_raw 0 次，真实车道仍 NOT OBSERVED ON CURRENT ROUTE。最后提取时本次 Phase 7 导航仍运行，未取得 stop_completed，需要用户在 iPhone 点击停止。此前 Step 1 的停止验收已经通过，不和本次新路线混淆。


## 本轮已结束（2026-10-07）

用户确认导航已经结束。实体 iPhone 日志记录北京时间 16:58:00 stop_completed，结束后采集日志无新活跃 snapshot。本次 Phase 7 路线停止已确认，不再等待用户停止；本轮任务结束，不继续功能开发或追加测试。真实车道 NOT OBSERVED ON CURRENT ROUTE，真实路况 callback PASS；此前退出报告本次复测未复现，根因仍 UNKNOWN。

## 2026-10-07 后续稳定性验收

修复后真实导航 17:29:48–17:46:44 共 16 分 56 秒，iPhone 后台，Watch 三次熄屏/离开/返回正常 Applied 39→125→162，同一进程，停止回等待页。同步 PASS，Phase 7.5 PASS WITH KNOWN HISTORICAL ISSUE。历史 Watch 退出根因 UNKNOWN，本次 NOT REPRODUCED AFTER TARGETED SOAK；详情 PHASE75_WATCH_STABILITY_RESULTS.md。

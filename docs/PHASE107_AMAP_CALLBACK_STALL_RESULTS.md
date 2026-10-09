# Phase 10.7 — AMap Callback Stall Diagnostics

更新：2026-10-08（北京时间）。本轮真实导航复现定位stale，边界分类 **amapRawCallbackStalled**；Phase10.5 **PARTIAL — AMap callback stall**。导航与对照已停止，不进入SDK版本实验或下一功能。

## Reproduction

- reproduced：YES，本轮新证据，非历史复用。
- 2026-10-08 08:44:30–08:46:25 北京时间，约115秒。
- 静止、实体iPhone前台：用户明确确认；日志appState active与SDK GPS naviMode=1、有效route、delegateAttached=true一致。
- 首次远程启动timeout，进程查询未发现主App；一次重试launch success，arguments包含-phase107-pipeline，日志pipeline_observer_started确认180秒对照已开启。前一次timeout不当作崩溃。
- CoreLocation多次提供新样本，总16次；独立manager静止时更新有约15秒间隔，并非每秒连续输出。判定AMap停顿只使用同时具有新CoreLocation证据的节点；样本超过5秒时保留unknown，不据旧样本猜上游健康。
- 定位源15秒过期后一直stale，没有pipeline_recovered。首轮位置callback停顿60.005秒、导航信息callback停顿59.732秒；约08:45:30原始callback恢复到达，但位置源timestamp仍停留08:44:30（sourceProgress=repeated），随后又有断档。
- 最后诊断源年龄108.496秒，停止日志确认Stop并停止独立observer。用户两次明确“已经停止”；没有继续测试。

## Pipeline ages

08:45:26.610附近的保存节点（stall-snapshot.json，Date日志精度以原始数值为准）：

| Layer | callback/generation age | count |
|---|---:|---:|
| CoreLocation | 2.523秒，源样本2.534秒，精度9.289米 | 13 |
| AMap location raw | 56.499秒 | 1 |
| AMap navigation raw | 56.208秒 | 4 |
| Provider location mapping | 56.499秒 | 1 |
| Provider navigation mapping | 56.206秒 | 4 |
| Provider Snapshot yield | 51.462秒 | 11 |
| Snapshot generation | 51.463秒 | 11 |
| Core consumption | 51.462秒 | 10 |

same session=9FD4AD8D-65DD-4363-99FD-1EDC079873C1，generated/consumed seq10一致。Provider/Snapshot没有持续新数据，因为上游原始数据没有到；不是原始callback仍到而转发丢失。约08:45:30callback返回后，最终location raw/provider counts=2/2，navigation raw/provider counts=6/6，Snapshot/yield=17/17，Core消费15（bufferingNewest合法合并）。最终生成/消费seq16、同session，未发生序号回退或自动会话重建。

新增 DEBUG NavigationPipelineDiagnosticSnapshot 含各层 Date 时间戳、独立计数及 ContinuousClock 间隔：

| 层 | 精确测量点 |
|---|---|
| coreLocation | 独立 CLLocationManager.didUpdateLocations 入口，源 timestamp、age、accuracy；不是 SDK 内部输入 |
| amapLocation | AMapNaviLocation 回调刚进入，字段复制、MainActor hop 和 mapper 之前；nil 也计数 |
| amapNavigation | AMapNaviInfo 回调刚进入，nil 也计数并单独标注无可转发数据 |
| amapStatus | 当前实际 route success/failure/change、SDK error、didStartNavi/didStopNavi 入口 |
| providerLocation | LocationQuality 映射后，统一定位字段真正接收处 |
| providerNavigation | 导航信息在 MainActor 内接受、建立统一 frame 的位置 |
| snapshot | AMapSnapshotMapper 真正生成 NavigationSnapshot 后，记录 session/sequence |
| providerSnapshot | AsyncStream.yield 返回 enqueued/dropped；terminated/missing 另记事件 |
| coreConsumed | NavigationCore 的真实 for-await 消费处，另记消费 session/sequence |

当前架构在 Provider 中先生成统一 Snapshot，再 yield 给 NavigationCore；Core 保存 latest 并通知上层，没有第二个 Snapshot 生成器。故单独保留生成、yield、Core 消费三条证据，不能用 Core 消费停顿冒充 Snapshot 未生成。bufferingNewest(1) 合法丢弃旧项，yield dropped 仍代表接收新项，不能比较消费次数与生产次数判定丢失。

同份 stall snapshot 记录 lifecycle、权限、独立/SDK 精度、SDK 源时间、SDK 公开 naviMode、路线是否存在、delegate 是否仍连接、后台定位/自动暂停、GPS、已有 Watch connectivity。screen lock 无可靠公开观测，保持 unknown。没有制造 paused/calculating/rerouting 私有状态。

间隔和 stale duration 用 ContinuousClock；源 Date 初始年龄在 callback 处计算，之后加单调经过时间，未修改实际源 timestamp 或业务 freshness。SDK 的源 Date 与系统墙钟仍为初始对照边界，不把诊断年龄当作 SDK 私有时钟。

## Classification

- none：源时间新、映射/生成/消费全新，freshness 一致。
- coreLocationStalled：持续对照仍 active，已有 CoreLocation callback 超过 15 秒未更新；仅断言独立 observer，不断言 SDK 私有定位器。
- amapRawCallbackStalled：独立 observer active、callback/source age ≤5秒且有效精度，而 AMap 自车定位 callback age >15秒。AMap 导航信息仍可继续，分类只指定位出口。
- providerForwardingStalled：原始有效输入计数领先转发，后者 >2秒不推进；或已生成 Snapshot 没有 yield。nil 导航回调不误判为漏转发。
- snapshotGenerationStalled：统一导航 frame 持续转发，但 Snapshot 生成 >2秒不推进。
- coreConsumptionStalled：额外诊断分支；Snapshot 已 yield，而 Core 同 session/sequence 未跟进且消费 >2秒不推进。
- freshnessClassificationMismatch：新定位、映射、生成和实际同序号消费均正常，单调源年龄对应的预期 freshness 与展示层 freshness 不一致。
- unknown：缺证据、对照未开启/已结束、数据仍到但源 Date 停留、短暂队列空隙、无有效路线等。不猜因果。

连续对照已截止时，不能据最后一笔旧样本分类为 coreLocationStalled 或 amapRawCallbackStalled。5/15秒原业务阈值和90秒 Watch snapshot 阈值没有放宽。

## Recovery

fresh→delayed/stale 自动写 pipeline_stall_snapshot；stale→fresh 自动写 pipeline_recovered，包含单调 stale duration、首次恢复的此前静默层、sameSession、sequenceContinued、sessionRebuilt。仍在持续输出的层不当作“先恢复”；缺少证据则 firstRecoveredLayer=unknown。

本轮定位freshness自动恢复：NO OBSERVED RECOVERY，stale到停止约100秒，最后诊断覆盖约92.94秒stale。原始callback自然返回：YES（位置gap60.005秒），但源时间未推进，不算定位恢复。callback返回后仍同session，Core生成/消费seq10→16，未自动重启导航。pipeline_recovered因未发生stale→fresh而没有生成，恢复持续时间不适用；不能把callback重新到达写成定位已恢复。

## Delegate、Stream 与定位器关系审查

AMapNavigationProvider 的 manager 为 private let 强引用，PhoneModel 与 NavigationCore 强引用 Provider；SDK delegate/data representative 为 weak（当前安装头文件明确说明），但现有强引用覆盖导航期间生命周期。delegate 只在 init 赋值、显式 stop 解除，没有发现中途替换。manager 为 SDK sharedInstance，只有显式 stop 调 destroyInstance；没有自动重建/自动 stop-start。

navigationUpdates 创建新订阅时结束旧 continuation；当前 PhoneModel 对 isStarting/isNavigating 防重入，每次启动仅创建一次 Core，Core 先订阅再 startGPSNavi。Core 的 Task 只在新 start、stop、启动失败时取消；Provider 流只在替换订阅、stop、arrived 时 finish。没有发现能确认解释本轮 stall 的 continuation 覆盖、取消或 actor 丢弃问题，因此没有修改这些业务规则。非隔离 delegate 仍复制公开标量后 hop MainActor；新锁保护 recorder 在 hop 前计数，不依赖 Actor 能否及时运行。

App 自己的 CLLocationManager 原职责为权限/精确定位检查，Phase10.6 追加了两次一次性 requestLocation。AMap Navigation SDK 使用它自己的定位机制；公开 API 不暴露它内部 manager 和 callback。不能证明两套 manager 在系统资源层完全独立。

本轮仅在 DEBUG 且启动参数 -phase107-pipeline 开启时，复用 App 权限 manager startUpdatingLocation，最多180秒。期间替代旧两次一次性请求；结束/Stop/到达后 stopUpdatingLocation。它不调用高德 stop/pause/start，不给 Mapper/Core/Snapshot 提供位置。独立定位服务可能影响系统定位调度、SDK恢复节奏和功耗，因此任何对照期间恢复只记诊断条件下恢复，不声称已生产修复。默认未带参数与 Release 保持原路径。

## Lifecycle 与 SDK 状态

复用 active/inactive/background scene 记录；每秒诊断复制已有状态，stall/recovery 关联 sameSession 和 sequence。本轮整个定向导航前台/静止即可发生stall，不支持必须锁屏/后台才触发；单次运行不能证明所有生命周期都无关联。锁屏直接状态仍不可观测。记录 SDK 公开 naviMode、GPS、route、delegate、后台定位/自动暂停配置；不可观测内部 SDK 暂停/输入保持 UNKNOWN。

## 最小测试与设备版本

10 项 Phase107PipelineTests，0 failures，最终日志 tests-final-verified.log。覆盖用户 Case1–6、旧源不误判 freshness bug、证据不足/停止、恢复同session/新session、单调时钟不受日志Date回拨影响、旧Provider callback拒绝、nil callback与yield/Core消费边界。

首次编译受 sandbox 缓存权限限制，升级至允许的编译环境后运行成功。补充 yield 边界后的中间复核暴露测试fixture漏记持续yield/Core消费，已修正fixture，最终10项PASS；不把中间失败计为通过，也没有扩大业务回归。
本轮首次实体日志在约5秒delayed节点出现诊断误报snapshotGenerationStalled：当时providerNavigation比snapshot更旧，实际无待生成输入。最终分类追加“必须有较Snapshot更新的Provider导航输入”的条件，已补正常无输入fixture复核；原始实体日志误报保留并标明无效，不视为业务Core问题。另修正日志recordedAt被编码Date数值覆盖（保留ISO外层时间）、旧Provider owner上下文更新过滤，添加消费session/sequence到完整snapshot。修正均仅DEBUG诊断；修正后不重复真实导航。

- AMapNavi-NO-IDFA：11.2.100，AMapFoundation-NO-IDFA：1.9.1（当前 Podfile.lock）。没有 pod update。
- iPhone：iPhone Air，iOS26.6（本轮 device inventory）。
- Xcode27.0 (27A266a)，iOS/watchOS SDK27.0（构建）。
- 模式/前后台：GPS驾车导航，静止/前台（用户确认及本轮SDK naviMode/appState证据）。
- 签名 Debug 双端构建 PASS（build-verified.log；实际复测版本为build-final.log）；AMap.bundle/AMapNavi.bundle 完整、显式 Watch launch type 保留（artifact-check.json）。
- 实体iPhone install success（phone-install.json）；一次重试launch success（phone-launch-retry.json），本轮真实导航及Stop均已日志确认。最终诊断修正版build PASS、iPhone install success（final-install.json）；未再次启动导航，不以安装成功替代新导航测试。
- 现有 iPhone 通信诊断页只加 Pipeline 一组系统 List/LabeledContent，未新建页面。新增显示尚无独立视觉验收证据。

## Conclusion

**AMap raw callback stall**：在独立CoreLocation仍多次给出新样本的条件下，AMap最原始自车位置及导航信息delegate先停顿；第一次位置间隔60.005秒，导航信息59.732秒。上游无新输入时Provider/生成/消费一起等待；原始callback返回后Provider、Snapshot与Core能继续，同session、seq10→16，但AMap源Date仍旧，freshness未恢复。

排除本轮“原始callback正常而Provider漏转发”“Provider输入更新而Snapshot停生成”“已生成新Snapshot却Core未消费”作为此次持续stale的解释。早期D误报已纠正，不把它当根因。SDK内部是否收到系统新位置、为何静止时停顿/重复旧源、是否存在配置或SDK实现行为仍UNKNOWN。

Phase10.5 **PARTIAL — AMap callback stall**。真正blocker：AMap公开出口持续断档/重复旧源、自然定位恢复未成立；需要之后另行授权的SDK使用方式/配置或版本对比证据，本轮不启动这些工作。业务代码没有修复：仅DEBUG诊断，Release导航策略、源时间、阈值和UI规则不变。未修改Smart Stack、Live Activity、Watch UI，没有自动重启SDK、版本升级或第二Provider。

证据：work/phase107/phone-stopped.jsonl、stall-snapshot.json、summary.json、tests-final-verified.log、build-verified.log、artifact-check.json、phone-install.json、phone-launch-retry.json及最终安装JSON。新诊断误报修正完成并保留，但本轮实体数据来自修正前诊断版；真实AMap原始入口计数、时间戳和同session证据不受这项分类条件修正影响。没有重复长观察或道路测试。

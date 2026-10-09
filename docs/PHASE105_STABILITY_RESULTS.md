# Phase 10.5 — Stability Closure

更新：2026-10-07（北京时间）。总体 PARTIAL：Implementation专项验证PASS；Location源过期反复复现且能自动恢复，底层原因未收口；Watch本次定向soak通过，历史根因仍UNKNOWN。不套用Phase7.5历史soak。

## Location interruption

复用 NavigationSnapshotTrace，本地 DEBUG timeline 包含 lastRawLocationAt、lastAMapNavigationCallbackAt、lastSnapshotGeneratedAt、lastSnapshotAppliedAt、accuracy/source age、provider state、lifecycle、authorization、session/sequence。lastRawLocationAt 明确定义为可观测 AMapNaviLocation callback，不声称 SDK 底层 CoreLocation 原始回调；不另开 CLLocation 定位服务改变测试条件。不可观测的底层暂停、系统 suspend 和 SDK 内部因果关系保持 unknown；生命周期变化与 SDK error code 单独记录，不据此强行推断根因。无坐标、道路名或Key，无新增诊断上传/第三方 Crash SDK。

NavigationFreshnessPolicy 统一现有源位置 stale=15秒、Watch快照stale=90秒默认来源，新增 delayed=5秒可配置分类；两者为不同数据时钟的明确预算，未放宽原阈值。Phase9更新策略和所有系统布局未修改。LocationInterruptionReason 表示观察到的层级/条件（回调时间间隔、源时间过期、精度、权限、provider状态）；noNavigationCallback不自动等于SDK故障，静止时引导回调稀疏也可能正常。

现有UI仅核对切换规则：delayed不伪装没有定位；stale隐藏旧引导、提示“定位信息暂未更新”；无可用测量时提示“定位暂不可用”；fresh恢复警告消失。DEBUG timer每秒检查，仅状态变化或每10秒记录，不刷新源timestamp。诊断模型不进入业务Snapshot，也不结束导航session。

专项fixture覆盖正常→delayed→stale→recovery，raw位置回调暂停、导航回调暂停但位置仍新、源时间老而precision仍存在、权限受限、provider inactive、unknown。通过实际NavigationCore+SnapshotGate测试，同session sequence1→2→3、旧序号拒绝、恢复无旧警告，只start一次。新增一项Activity adapter测试确认定位恢复后同session仅start一次、继续update，无提前end；这不是实际系统Live Activity视觉验收。

本轮真实静止导航已捕获反复定位源过期及恢复，不写NOT REPRODUCED或FIXED。首会话22:10:35开始，22:11:08手机显示stale（源年龄18.10秒），22:11:12自动恢复good（0.12秒）；Watch22:11:21重新进入先见旧源年龄32.15秒，随后应用新状态恢复good。用户22:13:56手动停止，22:14:02手动重启（已确认），期间还使用现有诊断probe seq100/102/103；这些会话切换不误计为异常自动重启。
新真实会话1538AF90-3095-4416-8481-9BE808C63E05从22:14:02开始；源时间22:15:39在若干SDK回调中保持不变，记录过53.84秒/120.88秒源年龄；期间AMap位置/导航回调有间隔或收到旧源，provider仍navigating，权限whenInUse，前台/后台均有记录，无已记录SDK internal error。22:17:41 Watch自动恢复新源（0.18秒），同会话继续；之后还记录多轮stale→新定位恢复。定位质量good/weak与freshness独立，不将精度仍存在但时间老的数据误写为没有定位。
已定位到AMap位置回调/源时间边界，Core和Watch仍继续处理sequence；SDK底层CoreLocation为何没有新测量、静止节流或弱GPS影响尚无法区分，原因unknown。当前不放宽阈值或用接收时间伪造source freshness。反复源过期现象尚未消除，按用户稳定复现时不标PASS的约束，Location结论暂PARTIAL。
同会话Activity ID30B4B995-BEEB-4E74-BD10-E2E4D25E2407至22:23记录start一次、update39次、未提前end；支持恢复后继续本地更新，系统展示未重新扩大测试。

## Watch exit

沿用已有launch/active/inactive/background/foreground、activation/reachability、receive/apply、stale entered/recovered日志。PreviousRunState增量可选lastConnectivityState、lastReceivedAt、lastAppliedAt，保留原launch/active/background/session/sequence/clean marker。旧编码可读；仅Debug保存。缺少clean marker仍只记录possibleUnexpectedTermination线索，terminationCause=unknown；普通background不是crash，公开API不能可靠判断userExit或processReclaimed时不归因。

本轮soak从22:10:35开始，最后真实导航会话22:14:02→22:29:39连续15分37秒，整个观察22:10:35→22:29:39共19分04秒（含用户手动停止/诊断probe/重启的短间隔）；不借用历史soak。中段Watch一直PID1302/runBCD70436-2FC5-4766-B297-1D454BF5E776，同真实会话已应用到253，无回退。
用户反馈熄屏后回主页/解锁再点击App，重新进入自动恢复导航，无需重启iPhone；这次行为未有进程重启或崩溃证据，保持生命周期观察，不将锁屏/回主页判crash。用户约22:19手动关闭睡眠专注，作为测试条件变化记录；不据此证明它是历史退出根因。当前watch.previousRunState实际磁盘数据已读取：有连接状态、lastReceivedAt、lastAppliedAt、session/sequence，cleanExitMarker=false仍仅为线索。持久化LastKnown字段可能落后于实时journal，以journal核对实际最新序号。
中途一次Watch进程查询CoreDevice4000连接失败，不当作无进程或App退出。最终Watch停止序号412于22:29:39应用；用户确认已停止并回到等待页。同PID1302、单run贯穿本次观察，最后真实会话applied8→412无回退。22:25:30有一次快照stale_entered/stale_recovered同秒，不残留；位置source stale多次恢复为weak/good，日志区别于Watch通信stale。
用户最终反馈关闭睡眠专注后仍需点击App进入，进入后自动恢复，没有突然退出。本轮Watch记NOT REPRODUCED AFTER TARGETED SOAK，PASS WITH HISTORICAL UNKNOWN ROOT CAUSE；不记ROOT CAUSE FIXED，也不推定睡眠模式是历史根因。停止后的iPhone final与Watch final-retry查询均success，与baseline差集未见新增报告。Watch首次停止后查询CoreDevice4000失败，保留失败JSON；retry成功后才作报告差集结论，不将查询失败当crash。

## 最小验证

7项Phase105StabilityTests + 1项Activity同session恢复专项测试，8项0失败。无Phase5–10全量、Lane/Traffic/Camera业务回归。SDK签名双端build PASS，本地导航配置与AMap.bundle/AMapNavi.bundle核对通过，实体双端install/launch JSON均success。本轮实体静止导航及19分04秒Watch观察已完成，用户确认Stop后回等待页。证据目录：当前ChatGPT项目work/phase105；临时本地配置交付前清理，不打印/打包Key。

## Final conclusion

**PARTIAL** — 本轮Location源过期在静止导航下反复出现，定位到AMap位置回调/源时间边界，Core/Watch/Activity同session自动恢复正常；不按“未复现”或“已修复”收口。Watch本次targeted soak满足范围内条件，单独PASS WITH HISTORICAL UNKNOWN ROOT CAUSE。未见新的已确认App crash、权限丢失、非预期会话重启或sequence回退。
真正未收口项：高德位置源timestamp停留及回调暂停的上游原因。可复现条件为本次静止导航，前台/后台均出现，有GPS weak和保留精度；源年龄最大121.08秒，收到新源后自动继续。当前API证据不能可靠区分SDK静止更新行为、弱信号或其底层CoreLocation暂停。下一项最小工作应核实当前SDK timestamp语义并关联既有GPS/network/matched字段与源时间，不用接收时间顶替源时间，也不直接放宽15秒隐藏阈值。需该层证据后再决定最小修复，不重跑所有业务模块。
最后真实会话Activity仅start一次、update61次、Stop end一次，ID保持30B4B995-BEEB-4E74-BD10-E2E4D25E2407。本轮没有新增LiveActivity/SmartStack视觉测试，没有改布局。
限定的定向导航测试已停止；用户随后要求继续定位提示排查与Smart Stack点击修正，结果见下方，不进入任何新业务功能。

## 文件与证据

代码：Shared/NavigationDiagnostics.swift、NavigationEnrichment.swift、MockNavigationProvider.swift（仅DEBUG phase105-soak注入/默认Mock不变）；AMapNavigationProvider.swift；iOS/NavigationWatchPhoneApp.swift；Watch/WatchConnectivityClient.swift。新增Tests/Phase105StabilityTests.swift，ActivityTests/LiveActivityTests.swift仅增加恢复专项用例。Phase9生产源码与Widget布局均未修改。
文档：本页、PROJECT_STATUS.md、NEXT_SESSION_HANDOFF.md。
本地证据：tests.log（7+1）；device-build.log；双端install/launch JSON；phone-start/final.jsonl；watch-start/final.jsonl；activity-final.jsonl；watch-previous-run-state.json；user-observations.json；双端crash-baseline/final.json；evidence-current.json。原始日志和本地Config不入源码包。因旧trace.reset行为，首会话手机只保留已及时提取片段，首会话完整日志不作证明；末会话完整记录已保存。诊断probe的两个人工session与真实navigation session明确区分。

## 用户追加：定位提示与 Smart Stack 点击

用户报告突然出现“定位信息暂未更新 / 等待新的定位信息，旧转向和距离已隐藏”。该文案来自iPhone展示层；Watch用同一LocationQuality时钟判断。具体触发链为AMapNaviLocation.timestamp → LocationQuality → source age >15秒 → reliableGuidance=false；有效新源到达后自动恢复。不是WatchConnectivity快照90秒过期的同一个判断。
核对本轮已有日志：最后真实会话138条location_quality均weak，无unavailable；已记录的pipeline源timestamp未发现回退。此证据支持源时间停留/回调稀疏，不支持已确认权限丢失、Watch乱序覆盖或App主动停止定位。AMap Manager导航期间pausesLocationUpdatesAutomatically=false、allowsBackgroundLocationUpdates=true，只有Stop/Arrival/启动失败才恢复默认；权限检查用CLLocationManager未启动另一套定位。高德当前11.2.100头文件仅描述timestamp为“时间戳”，官方指南没有保证静止/弱GPS每秒产生新源时间，所以SDK内部原因仍UNKNOWN。
补充DEBUG观测：每个location_quality回调记录sourceTimestamp、sourceProgress(first/advanced/repeated/regressed/future/unavailable)、isNetworkPosition、isMatchedToRoute、callbackQueueDelay和实际SDK后台/自动暂停设置；timeline保留lastSourceAdvancedAt及同组字段。没有记录坐标或改写源时间，没有新增独立定位服务，没有放宽15秒阈值。这批字段尚未经历新的真实导航，因此不能用其宣称已查明底层根因。下一次正常导航机会性读取即可，不重复15–20分钟soak或专门绕路。

Smart Stack点击“Open on iPhone”已定位为Watch target缺少WKSupportsLiveActivityLaunchAttributeTypes。新增Watch/Info.plist空数组，Debug/Release两项指定该输入plist，继续GENERATE_INFOPLIST_FILE合并系统键；复用现有Watch App和唯一iPhone Widget Extension。签名产物中确认数组存在且为空、companion bundle匹配，因此按公开API声明所有本App Live Activity可启动Watch。无新增AppIntent或Widget target。点击实际系统行为仍待用户最小反馈，不提前写PASS。
用户还报告Watch中出现Smart Stack按钮。源码不存在该文案按钮，仅DEBUG通信诊断入口；已询问具体位置。Apple文档描述前台App可收到系统Live Activity底部横幅，目前只能作为可能解释，不能直接认定该按钮的来源或声称已移除；此项待澄清。

追加最小验证：8项Phase105StabilityTests PASS（原7项加1项重复旧源/恢复/时间回退检测与diagnostic编码；Activity此前1项恢复测试未重复跑）。本阶段累计9项不同专项用例PASS。追加实体双端签名build PASS；Watch签名Info.plist启动声明与AMap资源检查PASS。追加实体双端install JSON均success、iPhone launch success；Watch launch被系统Locked拒绝，不计App crash，需用户解锁后打开。点击与新增GPS字段真实覆盖未确认。证据followup-tests.log、followup-build.log、followup-artifact-check.json；没有新道路/全量业务测试。

公开依据：[Apple Live Activity启动声明](https://developer.apple.com/documentation/bundleresources/information-property-list/wksupportsliveactivitylaunchattributetypes)、[Apple Watch Live Activity呈现](https://developer.apple.com/videos/play/wwdc2024/10068/)、[高德定位配置与回调](https://developer.amap.com/api/ios-navi-sdk/guide/location-info/location-setting-callback)。Xcode27当前CoreBuildSystem.xcspec确认该启动键为StringList；以实际签名plist检查空数组，未照搬未知版本教程。

## 2026-10-07 进度同步

当前整体PARTIAL；定位触发链已复现、恢复机制通过，上游源时间停留原因UNKNOWN。追加版本双端build/install PASS、iPhone launch PASS；Watch自动launch因Locked被拒，解锁后启动与Smart Stack实际点击UNKNOWN / 尚未验证。Watch内Smart Stack按钮来源仍待用户说明。首轮7+1及追加8项定位专项均通过，累计9项不同用例；不重复计算为16项不同用例。
本次只更新进度文档，未执行新代码修改、构建、导航或真机测试，没有新增用户验收反馈。Smart Stack原出现/更新/结束PASS仍是历史展示证据，不证明本次点击入口修复已验收。最新入口NEXT_SESSION_HANDOFF.md和输出HANDOFF_PROMPT.md均以此状态为准。

## 最新复现：用户报告11:01（日志对应2026-10-07 23:01北京时间）

用户条件：静止、iPhone前台，iPhone提示“定位信息暂未更新 / 等待新的定位信息，旧转向”且Watch同步出现。已提取追加诊断版本手机日志22:52:40–23:03:01，session323B4A36-3AC6-44CC-BD57-F673339028FA；未启动/停止用户导航、未重装或扩展测试。
39条location_quality中38条SDK报告strong、1条unknown；22条sourceProgress=repeated、16条advanced、1条first，无记录regressed/future。23:00:37回调到达，源timestamp仍为22:56:54，源年龄223.27秒，accuracy约14.25m，matched=true/network=false，后台定位true/自动暂停false，MainActor队列延迟约0.041ms。同一时段前台active、provider=navigating、whenInUse权限保持；timeline最大源年龄269.65秒（23:01:23），这是本次新增观测，不改写首轮121.08秒。
23:01:29新源到达，手机显示自动恢复good；23:01:50再出现stale，源年龄18.15秒。定位源过期反复出现得到新诊断字段验证，之前“弱GPS可能相关”不能当作本次解释。已有样本中的App回调队列延迟最大0.058ms，不支持由MainActor长时间排队导致；没有源时间回退，不支持该段旧回调倒序覆盖。SDK reported strong不等于已证明其底层CoreLocation正在提供新测量；目前仍无法区分底层系统更新稀疏与SDK内部静止处理，根因UNKNOWN，不伪造freshness或直接延长阈值。
Watch23:02:35新run55AA201F-BB2D-42F1-A9D1-0C57CC1E4B03/PID1423启动，收到当前session seq150并应用；显示sourceAge63.96秒而snapshotAge0.81秒，证明该条源定位过期与传输快照过期不同。11:01双端同时提示以用户反馈为依据，Watch日志未独立记录23:01那一刻，不能声称有同刻双端自动取证。当前run启动正常已有journal证据；历史run更换发生在追加安装及长间隔后，previousRun仅为clue，不归为新crash。Smart Stack点击入口和按钮来源仍未验收。

当前PARTIAL。诊断实现和源码→Snapshot→UI触发链已确认，SDK输入或内部静止行为的原因尚未查明。本次仅提取当前用户导航日志并更新记录，没有新代码/build/安装/测试；证据work/phase105/recurrence-1101/phone.jsonl、watch.jsonl、copy JSON和summary.json。下一项应针对原始CoreLocation与SDK自车位置输出的源时间做最小对照；当前SDK公共接口未暴露内部原始回调，不臆测原因或无证据改动生产定位策略。

## Phase10.6收口口径（用户最新授权）

用户明确仅要求诊断分层、Smart Stack点击目标和系统按钮来源；三项完成后，即使底层仍属高德/CoreLocation偶发行为，只要自动恢复、提示正确、session不破坏，可收口为PASS WITH KNOWN INTERMITTENT LOCATION STALENESS。本轮已实现诊断/入口，最小实体反馈待取得；当前保持PARTIAL。后续以PHASE106_DIAGNOSTIC_CLOSURE_RESULTS.md为最新验收依据，不再把底层私有根因完全修复作为唯一收口前提。

## Phase10.6后续真实结果（2026-10-07）

新增分层对照实测amapCallbackGap：独立CoreLocation新样本、AMap自车定位输出43.7秒断档，Core仍消费同session seq62。底层输入仍UNKNOWN。23:21:51仅短暂恢复、23:21:56再stale；用户反馈未恢复，稳定恢复不满足。截图确认Smart Stack仍系统wrapper/Open on iPhone，按钮来源系统且未消失；明确类型声明修正仅build/安装不能当点击PASS。当前总体PARTIAL，不能按候选状态收口。详见PHASE106_DIAGNOSTIC_CLOSURE_RESULTS.md。

Phase10.6最新点击复核：显式NavigationActivityAttributes启动声明双端安装后，用户确认直接进入Watch导航App；23:33:45/49 journal live_activity_open验证现有导航根页/session/seq14，点击PASS。三项诊断确认完成，但稳定定位自动恢复仍不满足，整体PARTIAL不变。

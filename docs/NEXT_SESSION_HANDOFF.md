# NavigationWatch 下一会话入口

## 全程路线图1.0(10)当前入口（2026-10-08）

每条规划路线可点“查看全程路线图”，以高德内置地图显示完整蓝色路线、起终点和路况底图；支持缩放拖动/全览，附现有规划信息。只读SDK路线lookup，无选路/启动导航/额外定位。不新增Provider或更改Watch/LiveActivity/freshness。详情读RC9_ROUTE_OVERVIEW_RESULTS.md。最终签名构建与产物核查PASS；Phone安装success，Watch安装success。实际地图加载/全览与手势待用户确认。


## 首页搜索交互与路线规划1.0(9)当前入口（2026-10-08）

点击空白收键盘、点击搜索展开其下方最近目的地、首页再下移24pt。路线规划新增全程红绿灯、分段缓行/拥堵、高速判断和SDK预计通行费；未知数据不假装畅通或免费。可选RoutePlanningInfo仅规划使用，不改实时Snapshot。先读RC8_SEARCH_ROUTE_DETAILS_RESULTS.md。3项相关测试与最终签名Release PASS（首次链接因磁盘不足失败，清测试缓存后成功）；Phone安装success，Watch安装success，真机交互/路线字段待用户确认。偏航由SDK自动重算；当前无专门偏航声音/文字/振动，实际偏航尚未验证，本次只答复不新增功能。


## Watch单位分行与首页下移1.0(8)当前入口（2026-10-08）

Watch剩余距离与时间数字在上、km/m/min单位在下，左右等宽、车道居中；iPhone首页内容增加32pt顶部留白，标题位置保留。先读RC7_WATCH_UNITS_RESULTS.md。最终签名Release及产物核查PASS；Phone安装success，Watch安装success。本次真机显示待确认，不重跑历史道路测试。


## 胶囊搜索框1.0(7)当前入口（2026-10-08）

用户新增IMG_0927参考：浅灰胶囊、左侧放大镜、左对齐目的地输入，键盘搜索提交；移除原大搜索卡。导入在下、折叠最近目的地、白底居中导航保留。只调整搜索视图和版本号，详情读RC6_SEARCH_FIELD_RESULTS.md。签名Release构建与产物核查PASS，iPhone安装success；手机Locked导致自动启动被拒绝，需手动打开。Watch配套安装遇连接中断，尚未验证1.0(7)手表安装，1.0(6)曾双端安装成功。搜索框视觉/键盘搜索及历史操作待用户确认。

## iPhone与最近目的地1.0(6)当前入口（2026-10-08）

按用户追加要求搜索上/导入下、删除首页来源页脚（设置页保留），导航信息居中且白底铺满。用户确认最近目的地：默认折叠、可复用、逐条删除/清空，本机最多20个，规划成功后记录，不保存行驶轨迹。先读RC5_PHONE_HISTORY_RESULTS.md。本轮Watch/Widget不改，1.0(5)Watch布局未收到明确视觉PASS，仍保留该验证边界。3项最小存储测试与最终签名Release PASS，双端安装及手机启动success，手机UI与历史操作待用户确认。


## 参考图UI调整1.0(5)当前入口（2026-10-08）

本轮按用户新图从已恢复1.0(3)继续：iPhone原生首页/设置标签、白卡蓝色导入按钮和搜索卡；Watch距离/车道/时间一排，车道居中，右上角信号图标据真实数据及quality分绿橙红，unknown/stale不假装强弱。Core/freshness/Provider/传输/Widget未改。先读RC4_REFERENCE_UI_RESULTS.md，最终签名Release构建、双端安装、手机启动及保护源码核查均PASS，当前等待本次用户显示确认。1.0(4)仍为REVERTED历史，不重新启用其布局。


## 当前版本：恢复1.0(3)（2026-10-08）

用户明确要求“返回上一版”，本轮1.0(4)首页居中/搜索区下移与Watch布局调整已全部撤回（REVERTED），不保留为正式新布局。Phone、Watch、Widget三处视图及build号恢复1.0(3)，保留已验收的高德路线/地点分享导入、Launch Screen黑边修复、Smart Stack深背景清晰配色和Watch Stop。已将两端恢复为已验证的原签名1.0(3)产物，双端安装及手机启动success；源码与旧版一致检查通过，不新增构建/道路测试。

下一会话以RC2_SHARE_UI_RESULTS.md及本入口为正式当前版本；RC3_LAYOUT_RESULTS.md仅记录已撤回尝试。Core/freshness/Provider/传输未改。用户要求已落实到源码及双端安装，本轮结束。

## 以下为历史记录

## 1.0(4) 布局调整当前入口（2026-10-08）

首页标题居中、搜索区下移；Watch按屏幕安全宽度约束、长文本换行、剩余信息分行，并同步调整Smart Stack小family。正式AMap-only，导航/freshness/Provider/Watch同步逻辑未改。Release build及产物核查PASS，双端安装及手机启动success，当前等待用户布局反馈。先读RC3_LAYOUT_RESULTS.md；此前RC1/RC2验收保留历史依据，不作为新布局全部场景PASS。


## RC2 分享与UI修正当前入口（2026-10-08）

用户请求高德路线/地点分享导入、Smart Stack白底文字不可读、iPhone上下黑边。1.0(3)新增首页粘贴导入/自定义URL入口、真实短链接302解析、POIID查询；从当前位置算路并由用户开始，无系统Share Extension。成对深背景/白文字修正Activity，补UILaunchScreen。6项限定测试及签名Release build PASS，Core/freshness/AMapNavigationProvider未改。

**本批PASS — 用户确认三项都正常，最终已停止；正式1.0(3)。** 先读RC2_SHARE_UI_RESULTS.md；RC1核心COMPLETE仍为已验收历史，本次UI验收另有用户明确反馈。用户两条链接真实resolver已PASS，具体私有wb分享schema有后续变化风险。用户本次确认两种链接导入正确、上下黑边消失和Watch Smart Stack清晰。6项限定测试、Release build、双端安装PASS。正式AMap-only核心COMPLETE / Release Candidate保持，不重跑全历史实验；下一步仅用户新授权任务或上架待办。


## RC1 当前入口（2026-10-08，已完成）

**Project Core Implementation：COMPLETE / Release Candidate，AMap-only，1.0 (2)。** 搜索→地点→真实路线选择→导航→锁屏/Watch/Live Activity→停止/再开始闭环。本轮用户最终确认“全部正常，无崩溃；最终已停止”。十项核心smoke PASS，依据本次用户反馈及最小代码/构建证据，详见RELEASE_CANDIDATE_RESULTS.md。Smart Stack点击未独立逐项记录、长期GPS/能耗未仪器测量、权限/网络失败及完整Accessibility覆盖保留边界，不隐去这些限制。

初始Watch无Stop按钮由用户发现，已补齐按钮、已有stopNavigation消息发送、10秒等待终态/失败说明与iPhone session gate；修复Release build及双端安装PASS，用户复验PASS。iPhone/Watch最终crash列表无新增；短验收不承诺所有场景无崩溃。5项直接相关测试PASS，Core/freshness文件未变，AMap资源和本机Key配置核查通过。

生产唯一AMap，Apple Route-only源码只作架构实验、不编入正式iPhone target；无Provider selector、fallback或AMap workaround。现有AMap导航Pods11.2.100、Foundation1.9.1，官方Search9.8.1手动Vendor链接（Podfile/lock未改）。正式工程NavigationWatch-Phase5与Pods镜像均已同步。

下一会话先读本入口，再按需读RELEASE_CANDIDATE_RESULTS、KNOWN_ISSUES、APP_STORE_RISKS、PRIVACY_POLICY_DRAFT。实际核心blocker无；上架待办含商业授权/Watch转发范围、SDK隐私清单及App Privacy、正式版权/审图号适用要求、政策公开URL、正式ID/分发Archive与商店材料。独立AMap静止callback等待vendor clarification，支持包READY未提交；增强道路coverage未全覆盖。不将这些写成核心未完成或伪造上架许可。

正式源码：`<LOCAL_PROJECT_PATH>`；Pods镜像：`<LOCAL_PROJECT_PATH>`。当前工作区根工程为Phase0–4历史源码，work/rc1为证据/暂存，sources只读。不创建Git或含Key交付包。本轮已停止，不自动启动下一阶段。

## 历史阶段记录（不作为当前产品策略）

## Phase 11 当前入口（2026-10-08）

**PARTIAL — AMap real SDK instantiation contract not verified**。本轮架构审计、矩阵、选型和Apple Route-only真实search/route最小Spike已完成；7项契约PASS，2项明确SKIP，另1项真实MapKit服务PASS（2搜索/1路线）。AMap真实实例创建与算路契约尚未验证，不把macOS SDK-unavailable边界当成功；AMap unsigned generic iOS Pods build与资源结果见work/phase11/amap-build.log/integrity.json。

正式工程仍为NavigationWatch-Phase5，Pods镜像为NavigationWatch-PodCheck；根目录早期工程未改。生产来源默认改为AMap（原代码实际初始为Mock）；Apple只在独立实验Provider/测试中构造，无选择UI/自动fallback。新增4能力、optional坐标来源、public Place/Route init与unsupportedOperation，旧wire兼容。Watch/LiveActivity/Core/freshness未改，无高德workaround。

下一次先读本入口，再按需读PHASE11_MULTI_PROVIDER_RESULTS.md、PROVIDER_CAPABILITY_MATRIX.md、SECOND_PROVIDER_DECISION.md、APP_STORE_RISKS.md。Phase10.9及下方内容是历史范围；其中“不引入第二Provider”已由本轮用户明确Phase11授权覆盖。AMap callback问题继续独立PARTIAL、支持包READY未提交；不自动开始任何下一阶段。

待办仅在新授权下安排最小iPhone AMap创建/路线契约验证；Apple正式展示须先确认对应地图要求，腾讯官方状态待外部核实。本轮没有设备安装/启动或真实导航功能验收，不能将build/MapKit服务数据说成真机导航PASS。


## 新窗口工作区定位（2026-10-08）

当前 ChatGPT 工作区的 `docs/` 已同步最新交接与进度，直接从 `docs/NEXT_SESSION_HANDOFF.md` 接续，不需要当前聊天历史。根目录 `NavigationWatch.xcodeproj`、`NavigationWatch/` 和 Swift Package 保留的是 Phase 0–4 早期代码，不代表目前正式 App；后续开发或构建使用下方列出的正式工程 / Pods 镜像。`work/phase109/Source`、A-Destroy、B-Retain 是实验副本，不作为正常 App 工程。

本次只更新文档；没有新增导航测试、业务代码或部署。旧工作区入口与进度已保存在 `docs/archive/phase04-workspace-entry-20261008/`。`sources/` 为只读同步参考，不修改；不在本工作区创建 Git 仓库。

## Phase 10.9 Manager Lifecycle A/B（当前入口）

交接更新：2026-10-08（北京时间）。本轮已结束，六个Session均完成并停止；不继续实验。Phase10.5 = **PARTIAL — AMap callback behavior pending vendor clarification**。

已完成阶段：Phase10.7定位到AMap raw callback/source边界；Phase10.8相同路线对比11.2.100/11.2.000均复现；Phase10.9固定11.2.100，Destroy与Retain各3个75秒Session、组内同进程、同完整路线/本地固定起点、静止/iPhone前台。Result A：**No meaningful lifecycle-policy difference observed.** A三次销毁true、旧weak均释放；B三次同一singleton。六次raw位置/导航计数均2/6，位置gap约60秒（A最大60.098秒、B60.083秒），Session内source推进均0次、stale且无自然fresh恢复。每次正式导航首源时间均更新。

不能省略的边界：B2/B3预导航idle阶段收到前Session旧源，应用未转发，startGPSNavi后首源更新；不等于所有raw行为完全相同。A1/B2/B3启动“全部字段为空”合并标志false，前序已有本次算路traffic回调，不能据此判旧状态污染；SDK辅助缓存来源尚未独立证明。无B注册/回调翻倍、新导航后旧owner/旧session输出证据；全部非空lane/road场景NOT OBSERVED。只是一组每策略3-Session的定向观测，不写根因已修复或全场景排除。

代码与部署：正式Swift业务源码、SDK11.2.100、Podfile及默认生命周期策略未改；17份正式Swift文件与实验前基线核对一致。实验仅在work/phase109隔离DEBUG工程。2个直接相关测试PASS，A/B签名build/install/launch及3+3真实窗口完成。最后正常11.2.100安装与启动success（restore-normal.json、launch-restored-normal.json）；本轮其后未开始新的导航测试。临时自动Session序列与固定路线模式不进入正常App。strong引用下destroy=false的清理语义已有验证，释放后可成功，但两策略均stall，不作为本轮根因修复。

## 下一会话读取顺序与文件位置

第一步只读取本文件，不从头规划。按需读取同目录PHASE109_AMAP_LIFECYCLE_AB_RESULTS.md与AMAP_SUPPORT_REQUEST.md；仅为核对历史证据再读PHASE107/108结果。不扫描全仓库、不重跑已完成六Session。

- 正式可编辑工程：<LOCAL_PROJECT_PATH>
- 已集成Pods镜像：<LOCAL_PROJECT_PATH>
- 当前项目证据根：<LOCAL_PROJECT_PATH>
- 最终生命周期证据：work/phase109/phone-A.jsonl、phone-B.jsonl、summary-A/B.json、comparison.json、matched-source-manifest.json，以及build/安装/启动/恢复JSON。首次旧路线hash拦截样本phone-A-excluded-old-route.jsonl排除，设备不可用为已解决历史准备问题。
- 单一最终支持包：work/phase108/AMap-Support-Materials.zip；已含Phase10.7系统定位/Provider/Core、Phase10.8版本对照、Phase10.9有效结果及六个Session日志。完整路线起点坐标仅设备私有缓存，不导出；临时Config已移除，正式本机配置保留，禁止打印Key。

## 未闭环与下一步范围

**SUPPORT PACKAGE READY FOR SUBMISSION，未提交。** 六个具体问题见AMAP_SUPPORT_REQUEST.md。真正blocker是高德对静止timestamp语义、约60秒location/navigation回调机制、freshness判断依据、推荐配置/API及singleton复用规则的澄清。独立CoreLocation新样本来自Phase10.7，Phase10.8/10.9关闭了该对照，不能混写为同轮同时证据。

下一入口：按用户新授权提交现有材料，或读取并核实高德回复；无账号/权限时由用户提交，不声称已提交。只有官方建议或新证据明确要求时再安排最小配置/生命周期验证。当前不再改生命周期，不加stale自动stop/start、watchdog recreate、自动重算、源时间改写或阈值放宽，不扩SDK矩阵，不引入第二Provider，不改Watch/Live Activity/Smart Stack UI。

下方Phase10.8及更早内容全部为历史记录；与本节矛盾时以本节、Phase10.9结果和最终comparison.json为准。

## Phase 10.8 AMap SDK Behavior Validation（历史阶段）

2026-10-08：受控验证已完成，根因未闭环；Phase10.5仍PARTIAL。11.2.100与相邻11.2.000都在静止/iPhone前台/相同完整路线/各120秒下复现：位置raw callback最大间隔60.096/60.054秒，导航信息59.025/59.043秒；每组2次位置输出、1个源timestamp、0次advance，stale YES、自然fresh恢复NO。完整路线hash一致、37903米/406点；终点/config/源码相同，Foundation二进制固定1.9.1。额外CL observer/requestLocation均关闭，enableExternalLocation=false。最初未受控样本排除，首轮路线不同仅作辅助；最终A2/B2通过SDK公开路线选择接口门控匹配。

不支持11.2.100独有regression解释；App额外诊断定位请求非必要触发条件。官方内部定位/后台配置核对通过，静止timestamp语义与约60秒回调机制仍UNKNOWN。两版Stop时destroyInstance=false，strong manager未释放的当时干净生命周期处理待验证；后续结果见Phase10.9，不能认定为运行期stall原因。

详情PHASE108_SDK_BEHAVIOR_RESULTS.md；证据位于当前ChatGPT项目work/phase108；AMap-Support-Materials.zip仅含复现步骤、实际调用片段、同路线日志和元数据，已准备、未发送，不声称独立最小App编译通过。下一步先向高德核实timestamp/静止机制及官方配置，另外单独验证强引用释放与singleton销毁。没有自动SDK重启、伪造源时间、放宽stale阈值或新增功能。

1项直接相关最大间隔测试PASS，隔离A/B及同路线门控签名构建PASS，实体同路线窗口与自动停止已取证。验证源码只在work/phase108隔离工程，正式SDK/业务源码/Podfile保持原样；已恢复验证前正常11.2.100应用，临时120秒结束与路线门控不用于日常使用。本轮没有新的Watch/Smart Stack功能验收。下方Phase10.7及更早条目为历史，矛盾处以本节为准。

## Phase 10.7 AMap Callback Stall（历史阶段）

2026-10-08：真实静止/前台GPS导航08:44:30–08:46:25（115秒）复现stale，分类amapRawCallbackStalled；Phase10.5 **PARTIAL — AMap callback stall**。CoreLocation独立对照共16次，在08:45:26节点源样本年龄2.534秒，AMap原始位置callback56.499秒/导航信息56.208秒未到；第一次实际callback返回间隔位置60.005秒/导航信息59.732秒。返回时仍携带08:44:30旧源，不算定位恢复；同session seq10→16、生成/消费匹配。导航与observer已停止，用户确认。

本轮DEBUG分层独立计数/ContinuousClock时间戳、stall snapshot和自然恢复记录完成。10项专项最终PASS，签名双端build及iPhone安装/启动成功。早期delayed阶段无新上游输入误报D已修正，并保留原始日志；最终诊断修正后未重复真实导航。详情PHASE107_AMAP_CALLBACK_STALL_RESULTS.md，证据work/phase107。仅诊断代码变更，业务源时间/15秒阈值与SDK11.2.100不变。

Smart Stack点击PASS、系统wrapper来源已确认，本轮不修改。SDK内部输入/停顿原因仍UNKNOWN，定位自然恢复未成立；不能标FIXED或Phase10.5 PASS。独立对照可能影响系统定位节奏，不当生产修复；只有具有新CoreLocation同时证据时分类B，样本过旧时unknown。

本轮已结束。下一步仅按用户新的授权决定SDK使用方式/定位配置检查或版本实验，不自动开展；禁止第二Provider、Live Activity/Watch UI/Smart Stack修改或道路扩测。下方Phase10.6及更早内容为历史，矛盾处以本节和Phase107结果为准。

更新：2026-10-07（北京时间）。最新进度已同步：Phase 10.5 总体PARTIAL，定向导航已停止；定位源过期上游原因未收口，Smart Stack首轮点击仍进入系统wrapper，按钮来源已确认；明确类型启动声明修正后的点击已通过，定位稳定恢复未确认。先读本页，再按需读引用；不要从头规划，不自动进入后续功能。

## Phase 10.6 Diagnostic Closure（最新）

当前PARTIAL。三项诊断确认已完成，分层诊断及按钮来源已有真实证据，6项不同专项测试PASS，修正后4项诊断复核PASS；双端签名build/install完成，未改Live Activity UI、未扩道路。
原地导航23:20:34–23:22:49（2分15秒）中，23:21:34独立Core Location样本年龄0.738秒/精度4.67米，而AMap自车位置回调已43.692秒无新输出、SDK源年龄44.739秒；AMap导航信息仍到，Provider/Core同session seq62匹配，消费延迟13.7毫秒。实测amapCallbackGap，缩小至AMap定位输出边界；SDK内部输入仍UNKNOWN。用户定位恢复答“否”，日志仅约5秒恢复后又stale，不能称稳定恢复。
用户截图确认点击仍进入系统Live Activity全屏wrapper，底部Open on iPhone，白底浅色文字难辨认；Watch journal没有live_activity_open，不能写已打开Watch导航页或按钮已移除。按钮来源已确认是系统wrapper。最新明确类型NavigationActivityAttributes声明修正双端build/install成功；用户确认直接进入Watch导航App，23:33:45/49 journal live_activity_open验证target=watch_navigation_root、同session/seq14。点击目标PASS，首轮系统wrapper截图保留为历史问题证据。最新显示配色没有独立复核。
Phone Stop有日志；当前复制Watch journal结束早于Stop，本轮Watch等待页未独立确认。诊断对照最多2次/首120秒，只记时间与精度，不供给Snapshot；一次性请求可能影响系统定位节奏，不是生产修复。
Phase10.5仍PARTIAL，稳定自动恢复条件未满足（点击条件已通过），不标PASS WITH KNOWN INTERMITTENT LOCATION STALENESS。历史Watch退出根因UNKNOWN。下一步仅按用户授权处理定位稳定恢复剩余问题，不进新Provider、不扩道路、不改UI。详情PHASE106_DIAGNOSTIC_CLOSURE_RESULTS.md，证据work/phase106。

## 最新定位复现与取证

最新定位复现（2026-10-07 23:01，用户描述“11:01”）：静止/iPhone前台，双端提示以用户反馈确认。追加诊断已取到真实数据：SDK报告strong且matched=true/network=false，但源timestamp停留、回调repeated；本次timeline最大源年龄269.65秒，队列延迟最大0.058ms。23:01:29新源自动恢复，23:01:50源18.15秒又stale。当前证据不支持弱GPS/权限丢失/MainActor长排队作为已确认原因，SDK内部或底层静止处理仍UNKNOWN。Watch23:02:35正常启动，seq150源63.96秒/快照0.81秒；Smart Stack实际点击仍待确认。本次仅读取用户当前导航日志，没有操作导航或重复测试。证据work/phase105/recurrence-1101；保持PARTIAL。

## Phase 10.5 最新结论

本轮Stability Closure已完成限定诊断与定向测试，**总体PARTIAL**，先读PHASE105_STABILITY_RESULTS.md；不要从头规划。
- 定位：本次静止导航反复源过期，最大121.08秒；AMap位置回调/源timestamp边界已定位，SDK底层CoreLocation、静止节流或弱GPS原因仍UNKNOWN。同会话自动恢复、sequence继续、警告消失，无需重启；用户22:13:56/22:14:02手动Stop/Start和既有诊断probe单独记录，不算异常会话重建。
- Watch：22:10:35–22:29:39共19分04秒观察，末真实session1538AF90-3095-4416-8481-9BE808C63E05连续15分37秒。PID1302/runBCD70436-2FC5-4766-B297-1D454BF5E776不变，applied8→412，Stop回等待页已确认。22:25:30一次快照stale同秒恢复；未复现退出/无回退/无新增系统报告。Watch单项PASS WITH HISTORICAL UNKNOWN ROOT CAUSE，不写ROOT CAUSE FIXED。
- 用户约22:19手动关闭睡眠专注；随后仍需点App进入，但自动恢复、无突然退出。记录条件变化，不将其推定为历史根因。
- 首轮7项稳定性+1项Activity恢复测试PASS；追加8项定位专项PASS（累计9项不同用例）。首轮实体双端build/install/launch成功；追加双端build/install成功、iPhone启动成功，Watch因Locked拒绝自动启动、当前Watch已于23:02:35正常启动（journal证据），Smart Stack点击仍待确认。同一Activity start一次/update61/Stop end一次；Phase9生产源码与布局未改。
- 复用NavigationSnapshotTrace/Watch journal/PreviousRunState，新增timeline及连接/接收/应用时间。lastRawLocationAt是AMap位置callback，非不可观测的SDK底层CoreLocation。统一默认5秒delayed、15秒位置stale、90秒Watch快照stale，不放宽旧源阈值。
- 证据work/phase105，测试与导航已停止。当前未收口项是SDK源时间停留/回调暂停原因；若继续，仅核实timestamp语义并关联已有GPS/network/matched字段，依据证据选最小修复。禁止用接收时间伪造源freshness。不追加业务全量/测速/道路事件专门测试。

## Phase 10.5 追加问题（历史，最新结果以Phase10.6为准）

- 用户明确要求排查突然“定位信息暂未更新 / 等待新的定位信息，旧转向和距离已隐藏”；触发链已确认是AMap源timestamp过15秒，现有记录无源回退、location_quality均weak而非unavailable。上游原因仍UNKNOWN，不能延长阈值或以接收时间伪造fresh。
- 已补DEBUG每回调sourceProgress/sourceTimestamp、GPS/network/matched、callbackQueueDelay、实际SDK后台/暂停设置，timeline保留source最后推进时间；源码导航期间已有后台定位true/自动暂停false。新增字段已取得23:01静止前台复现数据（见最新段落），后续正常使用机会性取证，不追加长soak或专门道路测试。
- Smart Stack点击只出现Open on iPhone：确认Watch target缺少启动声明，新增Watch/Info.plist空数组WKSupportsLiveActivityLaunchAttributeTypes、两配置输入路径，签名双端build和plist检查PASS；双端安装success、iPhone启动success；Watch因Locked拒绝自动启动，已请用户解锁并最小点击确认。实际点击待用户反馈。不得写已真机PASS，不新增target。
- Watch内Smart Stack按钮：源码无此按钮，已请求说明位置；可能是系统前台横幅但未确认，不能声称已移除。
- 追加8项定位专项PASS（原7项+新增1项；阶段累计9项不同用例含此前Activity1项）。首轮soak仍以19:04/15:37为准；追加无新导航测试。Watch停止后系统报告重试success，无新增报告，首次失败JSON保留。

## Phase 10 当前工作

Implementation PASS（专项测试/fixture）/ 整体 PARTIAL（用户报告 Watch 退出）。23 项直接相关测试 PASS；实体双端与 Watch simulator build PASS；Watch Debug fixture 的 camera/road text 出现、更新、移除恢复，weak/stale 定位提示通过。双端新版本及用户追加蓝色方向盘图标已安装、启动。
新增 Shared/NavigationEnrichment.swift（TrafficLightInfo / LocationQuality / SpeedLimitInfo / NavigationEventLifecycle），Provider 读取 SDK count/GPS 公共字段，Snapshot version 1 增量 optional 字段，Capabilities 新增 supportsTrafficLightState。仅 count 支持；灯态/countdown=nil，支持 flags=false；头文件的付费 countdown view 开关不是本项目可读取的数据能力。Core、session/sequence gate、WatchConnectivity、Phase9 LiveActivity/Widgets 源码未修改。
用户报告定位暂不可用后恢复及 Watch 闪退，其他正常。当前 Watch PID982 全段一致且仍运行，未发现对应 IPS；用户最新反馈定位提示偶发但自行恢复，Watch 退出目前未再次出现；退出原因 UNKNOWN，不能写已修复。当前手机源定位 34 条均 weak，无 unavailable；UI 15秒源过期策略可能相关，但没有精确关联。真实 count=13、Camera redLight；限速/非空道路仍未观察。

最新专项结果读 PHASE10_NAVIGATION_ENRICHMENT_RESULTS.md；证据在当前 ChatGPT 项目 work/phase10。Phase 8 Watch event text 缺项现为 fixture UI PASS；真实限速和非空 Road Event 仍只正常导航机会性观察。
短真机结果与新图标反馈已记录，整体保持 PARTIAL；不追加专门道路测试。若正常使用再次退出，仅记录时间、抬腕/操作/前后台行为并据此取证；不能把 Phase 9 历史日志当本轮观测。不要额外跑全量回归，也不进入第二 Provider。

## 最新继续改动

双端 stale 现在显示“定位信息暂未更新”，unavailable 仍为“定位暂不可用”，15秒阈值及旧引导隐藏不变。增加 DEBUG 显示状态变化记录，含源状态/有效状态、sourceAge和snapshotAge，便于区分源数据过期与同步延迟；不宣称修复定位中断根因。
Phase10专项21项PASS，双端build及安装PASS，iPhone启动PASS。Watch实体初次因Locked启动被拒绝，随后用户解锁打开并确认“完成”；手动启动PASS（用户反馈），Locked不计crash。Watch模拟器重启系统shell后fixture成功，新提示截图与源年龄20秒/快照0秒日志已核对。
新证据 work/phase10/followup-*；当前整体仍PARTIAL，用户反馈Watch退出未再出现、原因UNKNOWN。不要追加道路测试。

## 最新历史结论

- Phase 9：PASS；Implementation PASS；本轮最小 Real-device Coverage PASS。16 项 Live Activity 专项测试 0 failures；实体签名 Debug build、安装、启动 PASS。
- iPhone Air / Apple Watch Series 10，系统均为 26.6；Xcode 27.0 (27A266a)，iOS / watchOS SDK 27.0。
- 2026-10-07 北京时间 18:44:07–18:45:58 约 2 分钟正常导航。Activity 18:44:17 创建、18:45:58 Stop end；唯一 ID，7 次更新，dedup 49 / throttle 10。用户对锁屏出现/更新、Dynamic Island、Stop 消失、Smart Stack 出现/更新/结束及闪退问题回答“都正常”。视觉 PASS 依据为用户反馈，未伪称有截图。Smart Stack 本次已观察 PASS。
- Session A→B / Stop A→Start B、Arrival、异常 end、stale、dedup/throttle 均有专项 fixture 测试；此次道路只有一个 session，不宣称所有 lifecycle 都已真机覆盖。
- 本轮未发现新增 Watch 退出/crash；同会话 Watch PID 924，停止 sequence 66 应用。iPhone crash 列表未见本次新增 IPS；短测试不替代长时稳定性验证。历史 Watch 退出根因仍 UNKNOWN，不写 ROOT CAUSE FIXED。
- Phase 8：Implementation PASS / Real-road Coverage PARTIAL。真实 Camera 已 PASS，本轮 redLight 再次观察；真实限速与非空 Road Event 仍 NOT OBSERVED ON CURRENT ROUTE，Road 仍空列表；Watch event text 仍未独立确认。只允许正常导航 opportunistic verification，不为此绕路。
- Phase 5A / 6 已测范围 PASS；实体双端真实导航同步 PASS。Phase 7 真实 Traffic/Lane 已观察；Phase 7.5 PASS WITH KNOWN HISTORICAL ISSUE，16 分 56 秒定向 soak 未复现历史退出。

## Phase 9 架构与实现

NavigationCore → NavigationSnapshot → LiveActivityCoordinator → 本地 ActivityKit；WatchSyncCoordinator 分支保持不变。Shared、Provider、Watch UI 未修改。
NavigationWatch/LiveActivity 中含 NavigationActivityAttributes、NavigationActivityStateMapper、LiveActivityCoordinator、ActivityKitNavigationDriver。
静态属性只放 session UUID；动态状态为最小导航展示字段，无坐标、完整路线、车道、电子眼、道路事件或供应商类型。
成功 startNavigation 后才 enable；串行 start/update/end，session gate 拒绝旧会话；stop/arrived/idle/异常终止和新 session 替换结束旧 Activity。默认远 50 m/5 s、近 100 m 内 10 m/2 s、15 s staleDate、10 s freshness refresh，配置可调；maneuver/nextRoad/status 立即更新。
唯一 NavigationWidgets iPhone Widget Extension，覆盖 Lock Screen、Dynamic Island 四种布局，supplementalActivityFamilies([.small]) 提供 Smart Stack 布局。当前 SDK 的该 API 位于 iOS WidgetKit，watchOS unavailable；系统负责 Watch Live Activity 呈现，无独立 Watch ActivityKit Target。
仅 pushType=nil 本地更新，不做远程 Push。DEBUG 日志 Library/Caches/live-activity-diagnostics.jsonl 含 Activity/session ID 和事件，不含道路名、路线或坐标；Release 不写。

## 路径与构建原则

正式可编辑源码与本页位于：
<LOCAL_PROJECT_PATH>
正式隔离 Pod 工程：../../work/NavigationWatch-PodCheck，打开 .xcworkspace。两处均已同步截至Phase10.5的源码、工程及结果文档；工程保留 [CP] Copy Pods Resources。不能用无 Pods 集成的 project.pbxproj 覆盖隔离工程。AMapNavi-NO-IDFA 11.2.100；构建后仍检查 AMap.bundle / AMapNavi.bundle。
最新证据：<LOCAL_PROJECT_PATH>；Phase9历史证据为同项目work/phase9。
原 sources 同步镜像只读，不创建 Git。Config.local.xcconfig 不输出、不入源码包；本轮临时副本在交付前清理。旧 Phase5 压缩包不是 Phase9 最新源码，使用以上正式目录。
实体 Phone：<LOCAL_DEVICE_ID> / dev.local.NavigationWatch；Watch：<LOCAL_DEVICE_ID> / dev.local.NavigationWatch.watchkitapp。两端当前可识别，不把早期设备发现问题当 blocker。

## 已知故障保留

WCSession 错误回调 MainActor 断言：两处 @Sendable 已修复并有针对性验证；SDK resource missing SIGABRT：已恢复 Pod 资源脚本，正式产物资源完整。历史 Watch 退出未再次复现，根因 UNKNOWN。本轮无新增已确认启动crash；定位源停留原因仍未收口。
系统 Activity 展示受设置、系统选择、后台调度和更新预算影响，本轮未扩展长时间、多设备测试。未来未观察 Smart Stack 时仍须记 NOT OBSERVED ON CURRENT WATCH TEST，不能套用本次 PASS。

## 下一窗口

已取得追加版本Watch正常启动和当前定位复现日志；Smart Stack点击与按钮位置反馈尚未收到。本次仅同步文档，无新测试；下一步只处理上述待确认项或新的用户请求。定向导航已停止，不进入红绿灯倒计时、多地图 Provider、CarPlay、完整地图 Widget、完整 lane UI 或服务器 Push。
优先阅读 PHASE105_STABILITY_RESULTS.md；Phase10必要时读 PHASE10_NAVIGATION_ENRICHMENT_RESULTS.md；Phase 9 仅需时读 PHASE9_LIVE_ACTIVITY_RESULTS.md；仅处理 Phase 8 缺项时再读 PHASE8_SPEED_CAMERA_EVENT_RESULTS.md；若再发生 Watch 退出才读 PHASE75_WATCH_STABILITY_RESULTS.md。每次只做直接相关最小测试，不重复 Lane/Traffic/Camera/WatchConnectivity/Mock 全量回归。

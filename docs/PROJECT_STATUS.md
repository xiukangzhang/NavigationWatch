# NavigationWatch 项目状态

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

更新：2026-10-07（北京时间）。已同步 Phase 10.5 定向观察及后续定位排查、Smart Stack 启动配置修正；总体 PARTIAL，待确认项见下表。

| 范围 | 最新有效结果 |
|---|---|
| Phase 5A / 6 | 已测范围 PASS |
| 实体双端真实同步 | PASS：Physical iPhone → Physical Apple Watch real navigation sync verified |
| Phase 7 Lane + Traffic | Implementation PASS；真实 Lane 本次自然触发并映射 PASS，既有真实 Traffic callback PASS。未宣称全部道路 UI 覆盖。 |
| Phase 7.5 | PASS WITH KNOWN HISTORICAL ISSUE；修复后 16 分 56 秒真实导航、手机后台、三次 Watch 恢复及停止回等待页通过。 |
| Phase 8 | Implementation PASS / Real coverage PARTIAL；限速、Camera、Road Mapper PASS，真实 Camera PASS；Real Speed 和非空 Road Event 为 NOT OBSERVED ON CURRENT ROUTE。 |
| Phase 9 Live Activity | 原最小展示验收 PASS；后续 Smart Stack 点击打开 Watch App 的修正已安装，实际点击待确认。原展示 PASS 不覆盖点击入口。 |
| Phase 10 Enrichment | Implementation PASS / 整体 PARTIAL；Watch 退出历史根因 UNKNOWN，定位源过期由 Phase 10.5 继续排查。 |
| Phase 10.5 Stability | PARTIAL — AMap callback behavior pending vendor clarification；Phase10.7–10.9定向结果见顶部。 |

## Phase 10.6 Diagnostic Closure（最新）

当前PARTIAL。三项诊断确认已完成，分层诊断及按钮来源已有真实证据，6项不同专项测试PASS，修正后4项诊断复核PASS；双端签名build/install完成，未改Live Activity UI、未扩道路。
原地导航23:20:34–23:22:49（2分15秒）中，23:21:34独立Core Location样本年龄0.738秒/精度4.67米，而AMap自车位置回调已43.692秒无新输出、SDK源年龄44.739秒；AMap导航信息仍到，Provider/Core同session seq62匹配，消费延迟13.7毫秒。实测amapCallbackGap，缩小至AMap定位输出边界；SDK内部输入仍UNKNOWN。用户定位恢复答“否”，日志仅约5秒恢复后又stale，不能称稳定恢复。
用户截图确认点击仍进入系统Live Activity全屏wrapper，底部Open on iPhone，白底浅色文字难辨认；Watch journal没有live_activity_open，不能写已打开Watch导航页或按钮已移除。按钮来源已确认是系统wrapper。最新明确类型NavigationActivityAttributes声明修正双端build/install成功；用户确认直接进入Watch导航App，23:33:45/49 journal live_activity_open验证target=watch_navigation_root、同session/seq14。点击目标PASS，首轮系统wrapper截图保留为历史问题证据。最新显示配色没有独立复核。
Phone Stop有日志；当前复制Watch journal结束早于Stop，本轮Watch等待页未独立确认。诊断对照最多2次/首120秒，只记时间与精度，不供给Snapshot；一次性请求可能影响系统定位节奏，不是生产修复。
Phase10.5仍PARTIAL，稳定自动恢复条件未满足（点击条件已通过），不标PASS WITH KNOWN INTERMITTENT LOCATION STALENESS。历史Watch退出根因UNKNOWN。下一步仅按用户授权处理定位稳定恢复剩余问题，不进新Provider、不扩道路、不改UI。详情PHASE106_DIAGNOSTIC_CLOSURE_RESULTS.md，证据work/phase106。

## 最新定位复现与取证

最新定位复现（2026-10-07 23:01，用户描述“11:01”）：静止/iPhone前台，双端提示以用户反馈确认。追加诊断已取到真实数据：SDK报告strong且matched=true/network=false，但源timestamp停留、回调repeated；本次timeline最大源年龄269.65秒，队列延迟最大0.058ms。23:01:29新源自动恢复，23:01:50源18.15秒又stale。当前证据不支持弱GPS/权限丢失/MainActor长排队作为已确认原因，SDK内部或底层静止处理仍UNKNOWN。Watch23:02:35正常启动，seq150源63.96秒/快照0.81秒；Smart Stack实际点击仍待确认。本次仅读取用户当前导航日志，没有操作导航或重复测试。证据work/phase105/recurrence-1101；保持PARTIAL。

## Phase 10.5 当前进度

**PARTIAL**。Implementation专项验证PASS，首轮8项测试0失败；追加定位诊断专项8项通过（阶段累计9项不同用例），首轮双端签名build/install/launch成功；追加版本双端build/install成功、iPhone启动成功；初次Watch因Locked拒绝自动启动，随后23:02:35正常启动，当前Watch已于23:02:35正常启动（journal证据），Smart Stack点击仍待确认。定位源过期在本次静止导航反复复现，最大年龄121.08秒，已定位AMap位置回调/源timestamp边界，上游原因UNKNOWN；自动恢复，同session继续，未以接收时间伪造新源。Watch19分04秒本轮观察（最后会话连续15分37秒）未复现异常退出，单PID1302/run，停止序号412已应用，无回退；Watch单项PASS WITH HISTORICAL UNKNOWN ROOT CAUSE。用户确认重新打开自动恢复、关闭睡眠专注后无突然退出，Stop后回等待页。双端报告差集未见新增异常；历史Watch根因仍UNKNOWN。详见PHASE105_STABILITY_RESULTS.md。当前真正未收口项为SDK位置源停留/回调暂停的原因及最小修复，不扩任何新业务。

历史追加问题（最新结果以Phase10.6为准）：定位提示确认由SDK源时间超过15秒触发，源恢复后自动继续；当前原因仍UNKNOWN。已补DEBUG网络/匹配/信号、重复或回退源、回调队列延迟、SDK自动暂停/后台设置关联记录；未放宽阈值或引入第二套定位。Smart Stack点击Open on iPhone缺少Watch启动声明，已补WKSupportsLiveActivityLaunchAttributeTypes空数组，双端build与签名plist检查PASS；双端安装success、iPhone启动success；Watch因Locked拒绝自动启动，Watch正常启动已有日志，实际点击仍待用户反馈。Watch中Smart Stack按钮来源待用户澄清，不能写已移除。追加结果详见PHASE105_STABILITY_RESULTS.md。

## Phase 10 当前进度

Implementation PASS（专项测试/fixture）/ 真机 PARTIAL，USER REPORTED WATCH EXIT：定位质量、交通灯剩余计数、稳定事件身份及统一生命周期已完成，23 项直接相关测试 PASS，Watch fixture 文字及清除恢复通过。灯态/countdown 没有已核实可读数据 API，保持 nil/false；SDK 付费显示开关不等同可读能力。双端新图标与版本已构建、安装、启动，用户确认其他正常；但反馈定位暂不可用后恢复、Watch 闪退。实测 count=13、Camera redLight；限速/非空道路仍未观察。Watch PID982 连续且仍运行，未取到对应 IPS，用户最新反馈：定位提示偶发后自行恢复，Watch 退出目前未再次出现。退出及定位提示原因 UNKNOWN，不能写最终 PASS。详情 PHASE10_NAVIGATION_ENRICHMENT_RESULTS.md。后续已修正 stale 提示为“定位信息暂未更新”，补充双端源年龄/快照年龄 DEBUG 诊断；阈值和取样不变。21项 Phase10专项测试及双端build通过；新版本双端已安装，iPhone启动成功，实体Watch初次因锁定被拒绝，随后用户解锁打开确认完成。Phase 9 源码保持不变，不扩地图 Provider。

## Phase 9 当前进度

PASS：本地 ActivityKit adapter、唯一 Widget Extension、Lock Screen / Dynamic Island / Smart Stack small 布局完成。16 项专项测试 PASS；实体签名 Debug build、安装/启动 PASS，高德资源完整。
2026-10-07 18:44:07–18:45:58 正常导航约 2 分钟：唯一 Activity 创建、7 次更新、Stop end 均有真实日志；用户确认锁屏、灵动岛、Smart Stack 出现/更新/结束“都正常”，无新闪退。视觉结论依据用户反馈，无独立截图。Session A→B / Arrival 为 fixture lifecycle PASS，未单独扩大真机验收。
上述为原 Phase 9 最小展示验收结论；后续发现 Smart Stack 点击仅出现 Open on iPhone，原验收未覆盖点击打开 Watch App。首轮声明修正后的Phase10.6截图仍为系统wrapper/Open on iPhone，点击未通过，按钮来源已确认；最新显式类型声明已通过点击复核。NavigationCore / NavigationSnapshot 仍为 single source of truth，使用本地 ActivityKit 更新。详情 [PHASE9_LIVE_ACTIVITY_RESULTS.md](PHASE9_LIVE_ACTIVITY_RESULTS.md)。
本轮 Phase 8 未补齐真实限速/非空道路事件；Watch event text 未独立确认，Camera redLight 再次观察。

## 故障与验证

iPhone 后台 WCSession 错误回调 MainActor 断言已有 IPS；两处 errorHandler 改为 @Sendable，最小 worker-thread harness 及后续真实后台错误回调通过。历史 Watch 间歇退出本次未复现、同一进程，根因仍 UNKNOWN；熄屏返回正常不等于 crash。

Phase 8 首轮隔离 Pod 工程丢失资源复制步骤，造成 SDK 初始化 SIGABRT；恢复锁定 Pods 的资源脚本，并初始化前检查两个 Bundle。修复产物资源完整，18:11:39–18:12:42 真实导航成功，用户确认开始、停止无闪退，系统列表未见该成功会话新增 IPS。

真实电子眼进入统一快照；路段限速未触发，道路事件仅空列表。本次真实车道回调两车道、推荐 [0]。实体 Watch 本轮事件 UI 未独立取得证据；最终道路事件/限速展示微调构建、安装、启动成功；已提取 Watch 应用活跃 sequence 57→72 及停止 73 的日志，事件文字视觉观察仍未独立确认。

## 最小测试

Phase 7.5：5 项定向测试、Watch Debug/Release 构建、worker-thread harness、真机目标构建与上述 soak。Phase 8：16 项直接相关 Mapper/编码/序号测试，格式化微调仅重跑 1 项；正式 Pod 双端 Debug、Watch simulator 与最终 Watch 真机目标构建；42mm 有/无事件、车道组合、道路事件 fixture 视觉检查；修复后约 1 分钟真实导航。未跑无关全量回归。

详情按需读 PHASE75_WATCH_STABILITY_RESULTS.md、PHASE8_SPEED_CAMERA_EVENT_RESULTS.md、PHASE7_LANE_TRAFFIC_RESULTS.md。旧状态保存 PROJECT_STATUS_HISTORY_20261007.md，不把早期 Watch 未识别当作当前 blocker。

## 架构与交付

Watch 只消费统一 Codable / Sendable / Equatable Snapshot；SDK 与 Mapper 在 Providers/AMap。version 1 新增可选字段保持旧 payload 兼容，缺失能力默认 false。Debug 不记录坐标、道路名、Key；Release 不记录 Debug 轨迹。

可编辑源 outputs/NavigationWatch-Phase5；原同步镜像只读、不创建 Git，Config.local.xcconfig 不入包。正式构建使用隔离 Pod .xcworkspace；不能整体覆盖已集成 Pods 的 project.pbxproj，改动后除构建还须检查 AMap.bundle / AMapNavi.bundle。每次只执行直接相关最小测试。

## 本次文档交接

交接于 2026-10-07：本轮定向真机导航已停止，追加定位提示与Smart Stack排查继续，当前没有已确认的未修复启动 blocker。Phase10 当前待收口为定位偶发降级触发原因与用户报告的 Watch 退出（当前未再次出现）；真实路段限速和非空道路事件仍仅机会性观察，Watch 事件文字已有 fixture PASS。历史 Watch 退出根因仍 UNKNOWN。Phase10.5 最新结果见上文；下一会话先读 NEXT_SESSION_HANDOFF.md，不默认开展其他功能。

## 当前待确认与下一步

| 待确认项 | 当前结论 | 下一步范围 |
|---|---|---|
| 定位源时间停留 | 已复现；最大源年龄121.08秒，触发15秒过期提示；新源到达自动恢复。上游原因UNKNOWN。 | 已安装新增DEBUG关联诊断，已捕获strong/重复旧源；后续正常导航机会性收集，不专门绕路，不重复长soak。 |
| Smart Stack点击入口 | Watch启动声明已补，产物检查/build/install PASS；实际点击UNKNOWN / 尚未验证。 | 解锁Watch后最小确认卡片是否直接进入Watch App，确认后停止。 |
| Watch内Smart Stack按钮 | 来源UNKNOWN / 尚未验证；尚无位置说明或截图，不记已移除。 | 等待用户说明位置，判断是否系统横幅或其他入口。 |
| 历史Watch退出 | 本次19分04秒观察未复现，末会话连续15分37秒；根因UNKNOWN。 | 后续异常若再出现，按实际时间和生命周期取证，不用历史PASS替代新证据。 |

本次只同步文档进度，没有新增代码、构建、测试或设备操作；后续已取得追加版本Watch启动和新定位诊断数据（见最新复现段落）；实际点击与按钮位置尚未确认。Phase8真实限速和非空道路事件维持机会性观察，不进入倒计时、其他Provider或CarPlay。

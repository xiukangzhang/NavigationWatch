# Phase 11 — Multi-Provider Architecture Validation Results

日期：2026-10-08（北京时间）。状态：**PARTIAL — AMap real SDK instantiation contract not verified**。架构审计、能力矩阵、选型、Apple真实服务Spike完成；不把macOS fallback测试当作AMap真实实例通过。

## Architecture Audit

正式对象：NavigationWatch-Phase5；根目录早期Phase0–4工程未用作审计/构建。所有路径下表相对于正式工程的NavigationWatch/。

| file | assumption / finding | severity | 是否必须修 / 本轮结果 |
|---|---|---|---|
| Shared/NavigationModels.swift: NavigationCapabilities；Shared/NavigationEngine.swift: NavigationProvider | 协议默认具备实时导航方法，但缺少turn-by-turn/background/search/route能力声明；route-only无法在调用前区分 | HIGH | 必须：新增4个默认false且向后兼容的能力；unsupportedOperation明确拒绝不支持的操作 |
| Shared/NavigationModels.swift: NavigationPlace | 坐标无来源，iPhone输入明确高德坐标；直接传给另一Provider会误用 | HIGH | 必须：新增optional coordinateReference；Apple只接受MapKit来源，旧输入仍兼容；不猜测或转换坐标 |
| Shared/NavigationModels.swift: NavigationPlace/NavigationRoute | public类型没有public构造方法，独立Provider模块无法构造统一数据；第一次专项编译实际暴露 | HIGH | 必须：加入public init，无SDK类型泄漏 |
| Providers/AMap/AMapNavigationProvider.swift: route result/start | route.id等于destination.id、distance/duration=0，仅映射当前manager已算路线；不是真正多路线选路模型 | MEDIUM | 本Spike不必改AMap行为：Apple自己生成opaque UUID并持有原生路线；完整多路线产品化前必须处理 |
| Providers/AMap/AMapNavigationProvider.swift 与 AMapSnapshotMapper.swift | 能力重复声明，supportsRerouting对应SDK自动重算而非公开手动reroute方法；后者仍不可用 | MEDIUM | 本轮复用同一AMapCapabilityProfile消除重复；手动/自动能力细分留待有真实消费者时处理 |
| Shared/NavigationEnrichment.swift: LocationQuality | matched/network使用Bool，无法区分未知；good判定依赖matched；smartPositioning受当前GPS语义影响 | MEDIUM | 当前Apple不输出定位/导航，未触及；未来实时Provider必须给出可验证源语义，不能伪造good |
| Shared/NavigationDiagnostics.swift 与 iOS/NavigationWatchPhoneApp.swift: DEBUG timeline | 诊断含lastAMap...等供应商字段；不是Snapshot业务类型，仍有诊断命名耦合 | LOW | 非本Spike阻塞；未改诊断/freshness；未来多引擎诊断另立范围 |
| iOS/NavigationWatchPhoneApp.swift | AMap专用创建、密钥、权限与同意流；默认useAMap实际为false（模拟） | MEDIUM | 本轮初始值改true满足用户明确AMap默认要求；Apple保持独立实验构造，无共享Key/DI框架 |

立即必须修复的抽象问题 **3项，已修复**。另有AMap能力重复声明的关联修正。不是为了美观重构：独立模块编译和Route-only实际能力差异直接要求这些改动。

NavigationProvider无AMap SDK类型；Shared/Watch/LiveActivity没有AMap import或SDK枚举。AMap转向/lane code保留在Providers/AMap标量Mapper。统一Maneuver/LaneGuidance/TrafficState/CameraEvent/RoadEvent/TrafficLightInfo均是项目类型，辅助字段optional；事件ID、lane index和单位归一化由Provider负责。Snapshot业务status非SDK enum，Core只消费统一流，不使用AMap源timestamp来判fresh。snapshot.timestamp是本机生成时间，locationTimestamp是实际位置样本时间，不得替换。SnapshotGate的跨session墙钟规则是共同假设，非高德格式约束；未修改。

WatchSync只编码统一Envelope/Snapshot；Watch按optional/时间降级。LiveActivityMapper只使用统一maneuver、距离、nextRoad、ETA、状态和traffic。Apple Route-only不发导航快照，所以无需供应商分支或Watch/Activity状态机。通用空字段fixture证明mapper/gate/编码可接收缺项，不代表Apple已有实时导航或所有能力组合均真机覆盖。当前legacy camera/roadEvent字符串仍保留，第二Provider不写SDK字符串。

## 最小实现

- NavigationWatch/Providers/Apple/AppleRouteProvider.swift：NavigationProvider实现，真实search/route，显式MapKit来源origin；不使用当前位置/后台权限；有35秒限时服务测试及stop取消/短期缓存清理。
- AppleRouteMapper.swift：MKMapItem→NavigationPlace；MKRoute→NavigationRoute。原生对象不进入Shared/Watch，route UUID不复用POI ID。
- Shared模型：supportsSearch、supportsRoutePlanning、supportsTurnByTurn、supportsBackgroundNavigation，旧payload缺字段默认false；坐标来源optional，旧Place缺字段可解码；unsupportedOperation；public init。
- AMap只改能力声明与Package条件import，完整navigation callback/生命周期/source/freshness不变。supportsRerouting仍指原自动重算；搜索仍仅坐标解析所以supportsSearch=false。
- Mock声明其已有模拟search/route/turn-by-turn，background=false；不把Mock当真实引擎。
- Package.swift增加AppleProvider/ProviderContractTests独立目标，AMap target编译SDK-unavailable分支用于错误边界测试；iPhone project只添加两个Apple源码引用，PodCheck自身Pods资源脚本保留。
- 不增加生产Registry/UI/自动切换。实验入口为AppleRouteProvider(origin:)，通过any NavigationProvider和NavigationCore挂载；Core.start明确失败无假Snapshot。

## 验证与证据

最终ProviderContractTests：9个用例，**7 PASS、2 SKIP、0 failures**。跳过1=AMap真实iOS SDK创建（macOS不可用）；跳过2=需显式开启的实时服务探测。实时服务另行单独运行：**1 PASS**，2个MKLocalSearch结果、1条MKDirections路线进入统一Place/Route；仅输出数量，不导出路线/地标坐标。
AMap配置声明、统一Session、缺能力、optional wire/Activity mapper、Route-only拒绝start、坐标边界、公有模型构造和旧payload均有直接契约检查。AMap返回Route映射当前是零值占位，未以Apple测试冒充其真实算路契约。没有AMap真实创建/路线测试，因此总体不标完整PASS。

AMap Pods集成最终generic iOS Debug build：以amap-build.log最终结果为准，CODE_SIGNING_ALLOWED=NO；不是签名build/安装/启动/真机功能验收。检查AMap.bundle/AMapNavi.bundle存在。仅执行ProviderContractTests过滤用例及单次Apple实时服务探测，未运行Phase7/8/9/10/10.8回归或导航实验。

证据：work/phase11/tests.log、live-mapkit.log、amap-build.log、integrity.json、changed-files.json。

完整性：Watch、Widgets、LiveActivity、NavigationEngine、NavigationEnrichment和WatchSync与Phase10.9 manifest逐文件hash相同。NavigationDiagnostics当前hash与该历史manifest不同；本轮没有写该文件，不冒称所有历史hash完全一致，不自行恢复该已有差异。正式与Pods所有本轮修改源码一致。

## 七个明确答案

1. 有高德行为假设/诊断命名耦合，无SDK业务类型泄漏。
2. optional字段与capabilities可表达现有展示能力差异；新增turnByTurn/background补足Route-only分类；未知matched仍有未来边界。
3. 第二实验实现选择Apple MapKit Route-only。
4. 官方搜索/Route API、差异足够大、系统框架、隔离成本小；完整导航候选百度保留。
5. 必要公共改动为上述4能力标志、optional坐标来源/public init/明确unsupportedOperation，无供应商Snapshot必需字段。
6. 需要有限必要重构，不需要重写Core/Watch/LiveActivity或复杂工厂。
7. 来自真实模块编译失败与Route-only能力差异，非美化。

## Blocker / Stop

当前阻塞：AMap真实SDK实例/算路契约没有在本轮iPhone测试环境验证；Apple纯文字Watch展示与对应地图条款未闭环，Apple仍只在实验服务/模型层。腾讯当前官方API状态待外部核实。Phase10.5仍PARTIAL — AMap callback behavior pending vendor clarification，支持包READY、未提交，独立且不阻塞本轮完成的架构工作。
本轮完成后停止；不产品化第二地图、不加workaround/fallback，不部署设备，不继续AMap实验。

# Phase 11 Provider Capability Matrix

核对日期：2026-10-08（北京时间）。VERIFIED=当前官方文档明确支持或本项目现有有效证据；不等于本轮真机测试通过。PARTIAL=功能存在但不能直接映射/尚有访问或产品边界；NOT AVAILABLE=本轮所选公开 API 不提供该导航能力；UNKNOWN=当前官方证据不足。AMap 列为正式实现，其余为候选 API 能力。

| Capability | AMap | Apple MapKit | Baidu iOS Navigation | Tencent iOS Navigation |
|---|---|---|---|---|
| Search | PARTIAL：当前仅坐标解析 | VERIFIED：MKLocalSearch [A1] | UNKNOWN：需独立搜索接入核对 | UNKNOWN |
| Route planning | VERIFIED：既有驾车算路 | VERIFIED：MKDirections/MKRoute [A2] | VERIFIED：轻导航算路 [B2] | UNKNOWN |
| Turn-by-turn | VERIFIED：GPS引导回调 | PARTIAL：静态 MKRoute.Step，非实时引擎 [A3] | VERIFIED：实时诱导回调 [B1] | UNKNOWN |
| Background navigation | VERIFIED：既有实体已测范围 | NOT AVAILABLE：MapKit不提供实时导航引擎；Core Location后台需另行实现 | VERIFIED：文档后台定位/语音配置 [B3] | UNKNOWN |
| Reroute | PARTIAL：SDK自动重算，公开reroute方法当前抛不可用 | NOT AVAILABLE：需应用再次请求及自行管理偏航 | VERIFIED：偏航/重算通知 [B1,B2] | UNKNOWN |
| Traffic | VERIFIED：当前统一映射 | PARTIAL：地图交通显示/ETA不等于统一实时TrafficState [A2,A4] | PARTIAL：导航路况功能与统一标量映射需核对 | UNKNOWN |
| Lane | VERIFIED：当前统一映射 | NOT AVAILABLE：已核对Route/Step公开接口无车道数据 | PARTIAL：车道UI回调包含图片/名称，语义映射待头文件确认 [B1] | UNKNOWN |
| Speed limit | VERIFIED：当前映射，真实道路覆盖有限 | NOT AVAILABLE：所选Route/Step接口无此字段 | UNKNOWN：本轮未确认当前可读标量接口 | UNKNOWN |
| Camera | VERIFIED：当前映射及历史真实观测 | NOT AVAILABLE：所选Route/Step接口无此字段 | UNKNOWN：显示能力不等于可读事件API | UNKNOWN |
| Traffic light | PARTIAL：count；state/countdown不支持 | NOT AVAILABLE：所选Route/Step接口无此字段 | PARTIAL：剩余数量回调明确；灯态/倒计时数据授权与读取未核实 [B1] | UNKNOWN |
| Watch suitability | VERIFIED：当前统一传输；授权书面确认仍待办 | PARTIAL：Route-only 无实时快照；对应地图展示条款待解决 [L1] | UNKNOWN：不以原生UI回调证明Watch授权/适配 | UNKNOWN |
| Commercial licensing | UNKNOWN：具体产品授权待书面确认 | PARTIAL：Apple协议允许API使用并附限制，非本产品批准 [L1] | PARTIAL：需AK、商业用途条款核对 [B4] | UNKNOWN |
| China suitability | VERIFIED：当前中国路线既有实测 | PARTIAL：中国服务条款明确，当前本地服务探测另记；非独立数据供应链 [L1] | VERIFIED：当前官方导航产品面向中国道路；本项目未实测 [B4] | UNKNOWN |

## 官方证据

- [A1 MKLocalSearch](https://developer.apple.com/documentation/mapkit/mklocalsearch)
- [A2 MKDirections](https://developer.apple.com/documentation/mapkit/mkdirections)
- [A3 MKRoute.steps](https://developer.apple.com/documentation/mapkit/mkroute/steps)、[WWDC25 MapKit](https://developer.apple.com/videos/play/wwdc2025/204/)。公开steps为路线片段；没有证明MapKit提供应用内实时导航状态机，此分类为基于公开接口的推断。
- [A4 MKMapView](https://developer.apple.com/documentation/mapkit/mkmapview)
- [B1 导航实时数据获取](https://lbsyun.baidu.com/docs/ios?title=ios-navsdk%2Fguide%2Fobtain)：诱导、车道、剩余时间距离、灯数、信号及状态；不将图片型数据自动视为LaneDirection。
- [B2 轻导航](https://lbsyun.baidu.com/docs/ios?title=ios-navsdk%2Fguide%2Flite-nav)：算路/选路、简易诱导、偏航状态。
- [B3 权限配置](https://lbsyun.baidu.com/docs/ios?title=ios-navsdk%2Fguide%2Fpower)
- [B4 当前iOS导航概述](https://lbs.baidu.com/docs/ios?title=ios-navsdk%2Findex)、[8.0.3下载页](https://lbsyun.baidu.com/docs/ios?title=ios-navsdk%2Fsdkios-nav-download)（网页更新时间2026-08-04）。未下载/接入百度SDK，不声称实际许可、安装或运行成功。
- [L1 Apple Developer Program License Agreement Attachment 6](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)：Apple地图数据展示、短期缓存和版权限制；中国服务包含AMap提供的地图服务。
- [腾讯位置服务官方首页](https://lbs.qq.com/)可访问；官方导航GitHub Pages入口与5.2.6文档访问失败。历史搜索索引仅作发现线索，不用于当前支持结论。Tencent列：CURRENT OFFICIAL API STATUS REQUIRES EXTERNAL VERIFICATION。全局网络可用，不能写成全部候选无法联网。

## 关键差异

Full Navigation Provider负责实时引导/进度/偏航；Route-only Provider只负责搜索/算路/静态steps。本轮Apple只声明search/route，turnByTurn/background等false。静态步骤不转换为实时maneuver，不制造camera、lane、traffic、灯态或定位时间。

# 1.0(9)首页交互与路线规划详情

2026-10-08。用户要求点击空白收键盘、首页再下移、最近目的地在点击搜索后下拉，路线规划增加红绿灯/路况/高速/预计费用，并询问偏航提示。

## 实现

- 首页搜索区顶部留白再增加24pt（68pt行顶部内边距），保留导航标题及滚动。
- 搜索FocusState管理键盘；空白点击使用仅作用于首页区域的窗口手势，不取消现有控件触摸，排除文本编辑器和可识别控件；滚动也可交互收键盘。点击搜索自动在其正下方展开最近目的地，失去焦点隐藏，复用/删除/清空功能保留。
- NavigationRoute新增可选RoutePlanningInfo，仅用于规划页面，不加入NavigationSnapshot或Watch同步。旧路线无metadata仍可解码；AMapRouteCatalog仍将SDK ID隔离为UUID。
- SDK 11.2.100的routeTrafficLightCount为全程总数，routeTollCost为路线预计通行费（元）；路线Link roadClass=0判高速，城市快速道6不算高速。道路类型缺失/新未知类型不写成“不经过”。费用来自SDK，不推算油费/总旅行费用，以实际收费为准。
- routeTrafficStatuses普通status及length汇总缓行、拥堵、严重拥堵长度；未知路段和缺失覆盖单独提示，不推算堵车延迟或最近拥堵距离。原实时traffic映射未变，未使用需额外商务权限的trafficFineStatus。
- Watch单位分行、Widget、AMap freshness、manager生命周期、导航核心未改；无fallback或新workaround。

## 偏航核实（问题答复，不新增功能）

本地11.2.100头文件与官方当前文档确认：偏航后SDK内部自动重新规划，driveManagerNeedRecalculateRouteForYaw是可选的额外处理通知。当前App未接该回调，也未接语音播报回调，没有专门偏航文字/声音/振动提示；已有routeID更新会清理旧辅助状态、等待新引导，新引导到达后更新导航。重算失败时已有iPhone错误说明。SDK机制不等于本次偏航真机验收，实际偏航仍尚未验证；不要求用户故意偏航。

## 官方资料

- [AMapNaviRoute V11.2.100](https://amappc.oss-cn-zhangjiakou.aliyuncs.com/lbs/static/unzip/iOS_Navi_Doc/_a_map_navi_route_8h_source.html)
- [AMapNaviDriveManager V11.2.100](https://amappc.oss-cn-zhangjiakou.aliyuncs.com/lbs/static/unzip/iOS_Navi_Doc/_a_map_navi_drive_manager_8h_source.html)

## 最小验证

RoutePlanningTests 3项通过、0失败：混合拥堵与覆盖不足、高速与城市快速道区别、缺失/非法数据、可选metadata编解码与route catalog身份。未重跑历史道路/事件/LiveActivity测试。

首次签名构建编译通过，链接因磁盘空间不足失败；仅清除本轮可再生成的Swift测试编译缓存后重试。重试最终签名Release构建PASS，版本/资源/配置核查PASS，NavigationEngine/Enrichment/Widget未变；Phone安装success，Watch安装success。真机首页交互/显示、真实路线红绿灯/拥堵/高速/收费尚未用户验证。

证据work/rc8。修改Phone UI、NavigationModels、AMapSnapshotMapper中的路线catalog及规划mapper、AMapNavigationProvider的首次算路字段映射、版本号和RCTests/RoutePlanningTests.swift。

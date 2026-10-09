# 1.0(10)全程路线地图

2026-10-08。用户要求路线规划点开可显示路线全长概况的图片。实现为可缩放拖动的高德地图全览，而非保存或分享静态截图。

每条规划路线新增“查看全程路线图”。只读地将统一UUID通过当前AMapRouteCatalog定位到SDK算路结果，读取原始routeCoordinates；不调用selectNaviRoute、startGPSNavi、calculateDriveRoute，不改变正式选路或导航生命周期。未找到当前route时显示暂不可用并让用户重新规划。

地图使用现有AMapNaviKit内置MAMapView，不新增供应商或SDK。高德GCJ02坐标直接绘于高德地图，蓝色折线表示整条所选路线；标记起点与终点。布局完成/屏幕尺寸变化时按折线完整boundingMapRect加边距自动全览；用户可缩放拖动，用“全览”恢复。底图显示高德实时路况，蓝线本身不假称分段拥堵色。地图下方显示现有路线全长、时长、红绿灯、高速及预计收费。保留地图默认Logo/版权与比例尺，信息面板位于地图之外。

仅成功同意并规划后可打开地图；初始化MAMapView前声明地图隐私状态，使用既有Key，不请求地图用户定位、不加入后台定位或额外定位观察。地图坐标不进入统一模型、历史存储、WatchSync或LiveActivity；不自动存截图。

## 最小验证

仅签名Release构建与产物/保护源码检查，不新增低影响视图镜像测试、不重跑历史道路测试。首次编译发现SDK代理方法与Swift6主线程隔离不匹配，明确主线程Coordinator并用SDK协议兼容标记后重试。最终签名Release构建PASS，版本/AMap资源/配置及NavigationEngine/Enrichment/Widget保护源码核查PASS；Phone安装success，Watch配套安装success。地图真实加载、整条路线全览/手势、起终点与关闭后开始导航仍待用户确认，不把构建等同地图PASS。

证据work/rc9；仅Phone UI、AMapNavigationProvider只读lookup、版本号、当前文档/隐私说明更新。

官方当前[地图组件文档](https://amappc.oss-cn-zhangjiakou.aliyuncs.com/lbs/static/unzip/iOS_Navi_Doc/interface_m_a_map_view.html)支持路线overlay、可见矩形与路况显示。

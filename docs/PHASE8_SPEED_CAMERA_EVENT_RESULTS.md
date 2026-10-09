# Phase 8 — 限速、电子眼、道路事件

日期：2026-10-07。当前 **Implementation PASS / Real coverage PARTIAL**：修复后约 1 分钟真实导航成功开始并停止、用户确认没有闪退；真实 Camera PASS，限速及非空道路事件当前路线未观察。

## 进入门槛

Phase 7.5：PASS WITH KNOWN HISTORICAL ISSUE。修复后真实导航 16 分 56 秒、三次 Watch 恢复、手机后台真实 WCSession errorHandler 回调及停止同步完成；历史 Watch 退出 NOT REPRODUCED AFTER TARGETED SOAK，详见 PHASE75_WATCH_STABILITY_RESULTS.md。

## 结果

| 范围 | 状态 | 证据与边界 |
|---|---|---|
| Speed Limit Mapper | PASS | 正整数保留 SDK 整数限速，0 与负哨兵为 nil；复用现有 speedLimit Double 字段，不增加虚构精度。 |
| Real Speed Limit | NOT OBSERVED ON CURRENT ROUTE | 成功会话未收到路段限速回调；Camera 的 0 限速不转换为实际限速。 |
| Camera Mapper | PASS | 0/10 speed、1 surveillance、2 redLight、4 busLane、8/9 intervalSpeed（start/end 单独标记）、3/5/6/11 other；7 及未来未知 code unknown。距离 -1 无数据；限速 0/-1/-2 均不伪造限速。 |
| Real Camera Event | PASS | 15 次回调，redLight 227 m、surveillance 160→158 m 进入统一快照；未独立取得本轮实体 Watch 事件 UI 证据。 |
| Road Event Mapper | PASS | 1 accident、2 construction、3 closure、4 control，其他 unknown；过去的 segment/link 事件被排除，按当前路线筛选。 |
| Real Road Event | NOT OBSERVED ON CURRENT ROUTE | 两次空列表映射 none，未取得非空道路事件。 |

## 实际 SDK 公开接口

已安装 AMapNavi-NO-IDFA 11.2.100，依据本机公开头文件确认：

- AMapNaviDriveManagerDelegate driveManager:onUpdateNaviSpeedLimitSection:，9.6.0 起，0 表示无路段限速。
- AMapNaviDriveDataRepresentable driveManager:updateCameraInfos:；Swift 名 driveManager(_:update:)。AMapNaviCameraInfo 提供 cameraType/cameraSpeed/distance，cameraSpeed 单位 km/h、0 无限速、区间测速 -2 未采集/-1 禁行，distance -1 无剩余距离。
- driveManager:updateIntervalCameraWithPositionState:startInfo:endInfo:；Swift 名 driveManager(_:updateIntervalCameraWith:start:end:)。仅 position state In(2) 映射 AverageSpeedZone，使用 SDK remainDistance、averageSpeed、cameraSpeed；不自行计算“官方平均速度”，缺失字段 nil，离开区间清除。
- driveManager:updateTrafficEvents:，10.0.920 起；AMapNaviRouteTrafficEventInfo routeID/infoList 与 AMapNaviTrafficEventItem type、segment/link 索引。

道路事件没有直接剩余距离/严重度字段；description 也不将来源 labelDesc 误当事件描述，因此 distance/description/severity 为 nil。显示“路线施工”等，不伪造“前方 450 m 施工”，不把管制猜为 checkpoint。

[官方路段限速回调参考](https://a.amap.com/lbs/static/unzip/iOS_Navi_Doc/protocol_a_map_navi_drive_manager_delegate-p.html)。精确 code 与字段以此次安装版本头文件为准。

## 数据边界、兼容与寿命

AMapNavigationProvider、AMapSnapshotMapper、AMapEventMappers 均位于 Providers/AMap。Swift Package 使用独立 AMapMappers target 做纯输入测试；Watch 不编译或导入高德 SDK。回调先复制标量输入，随后 MainActor 更新统一模型与发布快照。

保留 version 1 及 legacy camera/roadEvent String 字段，增量添加 cameraEvent/roadEventInfo/averageSpeedZone 可选字段；旧 payload 缺失这些字段可解码，旧 peer 忽略新增字段，supportsRoadEvents 缺失时默认 false。停止/切路线/重新开始清理辅助状态；路段限速 0 清除、nil/空 camera 回调清除。

CameraEvent 和 RoadEvent 有独立源时间；近处电子眼仅在 0…500 m 且事件年龄不超过 90 秒时显示，过期时隐藏。道路事件按路线和 segment/link 排除经过的事件，并设置 90 秒展示时效。辅助回调不伪造新的转向源时间；仍保留 session/sequence 过滤。

## 最小 UI

现有结构不重做，车道/转向继续优先；仅显示一条电子眼或路线事件提示，加小号“限速 60”。camera 提示优先于 road event，traffic 沿用。没有事件不插入空布局。未修改 Haptic 模块、不增加重复提醒机制。

42mm Watch simulator 有电子眼/限速 fixture 与无事件 fixture 截图已检查，文字可读、无溢出、空状态无占位；仅模拟器视觉证据，道路施工+限速 fixture 也已核对。实体 Watch 本轮实际事件 UI 未独立观察。

## 最小测试

Phase 8 五项：Speed Mapper、Camera/Zone Mapper、Road Mapper/经过清除、Snapshot/Envelope 含新字段与旧 payload 兼容、显示时效与空状态。Provider 目录移动直接影响的既有 AMap/Lane/Traffic Mapper、快照编码与序号筛选一并定向执行，最终 16 项、0 失败；最后格式化边界小改只重跑 1 项显示测试 PASS。未执行无关全量回归。

正式 Pod Debug 双端构建 PASS，Watch simulator 目标构建 PASS。Debug 仅记录原始状态码、距离、限速、映射结果与统一 snapshot 事件字段；不记完整轨迹、坐标、道路名或 Key。Release 不记录这些 Debug 轨迹。

## 当前待办

本轮已停止。限速、非空 Road Event 道路覆盖尚缺，不为触发数据要求专门长距离驾驶，不自动进入下一阶段。

## 首轮启动失败及修复

用户报告点击高德开始导航闪退。18:04:50 IPS（capture 18:04:49.3394）为 SIGABRT / Objective-C exception，栈 NSBundle bundleWithURL → AMapNaviLocalizationUtils.localizedTextWithToken → AMapNaviBaseManager.checkSCTXVaild/init → AMapNavigationProvider.init。仅有 start_requested，没有导航或 Phase 8 业务回调；不能将本次缺少回调标 NOT OBSERVED。

工程目录调整同步时，隔离 Pod 构建副本的 CocoaPods 资源复制步骤丢失，产物中 AMap.bundle/AMapNavi.bundle 均缺失。重新使用锁定依赖执行 pod install --deployment --no-repo-update，恢复 [CP] Copy Pods Resources；初始化前增加 Swift 资源缺失错误，避免缺少 bundle 时调用 SDK 导致 Objective-C exception。依赖版本与功能代码没有为该失败扩展。

后续任何工程修改不得以未安装 Pods 的源工程整体覆盖已集成 Pods 的隔离工程；应分别应用增量改动，或重新 pod install 后再构建。除 BUILD SUCCEEDED，还必须核对产物内两个 bundle 实际存在。修复后启动及真实 Camera 已完成最小复测，见下方新会话证据。

组合小屏展示额外检查：车道/测速/限速/路况同时存在时初版拥挤；已仅合并辅助提示，相同测速限速不重复，事件提示存在时暂时隐藏低优先级 Traffic。42mm 最终组合截图完整、无裁切。未变更普通导航核心结构。

资源修复构建 PASS；产物 AMap.bundle 实际含 186 个文件、AMapNavi.bundle 含 6265 个文件。修复包已安装至实体双端，完成本次真实导航。最后一处 Watch 显示微调真机目标构建通过，最终显示微调版亦已成功安装至实体 Watch（安装目录 5751D75D-C74D-4E0E-9D4E-E96C3468D5A0）；不将安装当作新增道路 UI 验收。

## 修复后真实最小复测（北京时间）

2026-10-07 18:11:31 start_requested，18:11:39 navigation_active，18:12:42 stop_completed，实际导航约 63 秒。session A119AFFA-A05B-4C0C-A613-34C56B39E8F3，活跃 sequence 0→72，stopped 73。停止快照无 camera/road/speed 字段，采集至停止后未见新活跃快照；用户回报“成功开始并已停止，没有闪退”。

18:10:24 另有同栈资源异常 IPS，debug dylib UUID C1B44BB1-5B5C-332A-8713-02250387CCCF 与最终资源修复构建 410C8470-C3E0-37FA-9CE0-0A75A81D89B0 不同，不属于该成功新会话。系统 crash 列表未见成功会话期间新增 IPS。

本次自然观察真实 lane：18:11:44 background=2|3、selected=1|255，mapped laneCount=2、recommendedLanes=[0]。Phase 7 的 Real lane callback 补充为 PASS（进入统一模型），不推断实体 Watch 全部车道展示通过。

证据 work/phase8/iphone-final.jsonl、iphone-crash-final-list.json、iphone-181024.ips、watch-road-final.png 及 mapper/build 日志。Watch 连接恢复后已提取 watch-final.jsonl：同一新会话在 Watch PID 920 应用 sequence 57→72，18:12:42 应用停止 73；对应 MainActor apply 正常。随后最终显示微调版安装并启动，PID 924 恢复停止 73。日志支持收到/应用最新版快照与停止同步，但未记录事件文字截图，不扩大为实体 Watch 电子眼视觉 PASS。

## 交接状态

最终双端安装完成，Watch 最新显示微调版已启动；本轮导航停止。待验证仅为真实限速、非空道路事件及实体 Watch 事件文字视觉确认。当前无已确认未修复的启动 blocker；真实覆盖未完成不记作功能 FAIL。下一轮不自动重跑 soak，也不开展其他 Phase。


## 2026-10-07 Phase 9 正常导航机会性观察

18:44:07–18:45:58（约 2 分钟），未为 Phase 8 改路线或延长测试。Camera redLight 再次进入快照；路段真实限速、非空 Road Event 仍 NOT OBSERVED ON CURRENT ROUTE，Road callback 仍空列表；Watch event text 未独立视觉确认。Phase 8 继续 Implementation PASS / Real-road Coverage PARTIAL，本轮未补齐缺项。


## 2026-10-07 Phase 10 Watch event text 定向补齐

Watch event text：PASS（Debug fixture UI）。42mm Watch 模拟器同一 fixture session 显示“前方 450 m 测速 60”、更新至 300 m、施工文字，移除后恢复核心导航布局；稳定截图见 Phase 10 结果文档。此结论是展示能力，不等于本轮真实道路非空事件已触发，也不替代实体道路文字观察。真实限速、非空 Road Event 仍仅机会性观察；当前本轮真实结果待收取。

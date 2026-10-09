# 高德导航 SDK 回调与源时间行为咨询

状态：SUPPORT PACKAGE READY FOR SUBMISSION，尚未提交。Phase10.9已完成，两策略未观察到有意义差异。描述为 Observed AMap callback behavior；未认定为 SDK bug。

## 问题摘要与已验证边界

实体 iPhone Air，iOS 26.6；Xcode 27.0（27A266a），GPS 驾车导航 active，设备静止、App 前台，无外部位置注入。

Phase 10.7 独立 Core Location 对照持续产生新样本；一个保存节点中，系统样本年龄 2.534 秒，而 AMap 原始定位回调已 56.499 秒、导航信息回调已 56.208 秒未到。定位回调实际间隔 60.005 秒、导航信息间隔 59.732 秒。回调再次到达时仍携带旧 source timestamp，未形成 fresh 恢复。这是独立系统定位器对照，不能证明 SDK 私有定位器收到同一批样本。

AMap 有上游输入时 Provider 正常映射、生成 Snapshot 并 forward；最终 raw/provider 位置计数 2/2、导航信息 6/6，Snapshot/yield 17/17。NavigationCore 使用 bufferingNewest(1)，消费 15 次属于允许合并；同 session 最终生成/消费 sequence=16，未发现序号回退或自动重建。上游无输入期间下游一起等待，不能误归为丢失上游回调。

Phase 10.8 关闭 App 独立 Core Location 诊断请求，分别验证 11.2.100 与相邻 11.2.000；Foundation 固定 1.9.1、同源码、相同完整路线指纹、静止、前台、各约 120 秒。两版本均复现类似回调及源时间行为。本轮没有 Core Location 同时采样，不能与 Phase 10.7 混写为同一轮证据。

| 指标 | 11.2.100 | 11.2.000 |
|---|---:|---:|
| raw location 最大回调间隔 | 60.096 秒 | 60.054 秒 |
| raw navigation 最大回调间隔 | 59.025 秒 | 59.043 秒 |
| 定位输出 / 不同源时间 / 源时间推进 | 2 / 1 / 0 | 2 / 1 / 0 |
| stale / 自然 fresh 恢复 | 出现 / 未恢复 | 出现 / 未恢复 |

上述结果不支持 11.2.100 独有 regression 的简单解释，但不证明所有版本或全部场景必现。尚未确定共同用法或 SDK 内部机制的根因。

## 当前 SDK 使用方式

先声明隐私同意并配置本机 Key，再获取 AMapNaviDriveManager.sharedInstance；注册一个 delegate 和一个 DataRepresentative。起点 nil，驾车策略 10；算路成功后 startGPSNavi。导航期间 allowsBackgroundLocationUpdates=true、pausesLocationUpdatesAutomatically=false，enableExternalLocation=false；不调用 setExternalLocation。

既有 Stop 流程为 stopNavi、removeDataRepresentative、delegate=nil、destroyInstance。Provider 的 private let manager 在调用销毁时仍持有强引用；Phase 10.8 两版本均返回 false。SDK 11.2.100 头文件提示销毁失败时检查强引用。该事实没有被认定为运行中 callback stall 的原因。

Phase 10.9 固定11.2.100，每组同进程3个75秒Session，静止/前台/相同完整路线及本地固定起点。A释放应用strong引用后3次destroy=true且旧weak释放；B三次同一singleton，不调用destroy。六次均raw位置2/导航6、位置约60秒/导航约59秒gap，Session内source不推进并stale；每次新Session首源时间更新，未继承前次末源。无B组注册/回调翻倍或旧owner/旧session输出证据；全部非空lane/road状态未覆盖。Result A：No meaningful lifecycle-policy difference observed，详情见附件。既有销毁false清理语义不能解释本次stall，正式业务未改。

补充边界：B2/B3在新Provider仍为idle的注册/算路阶段，出现过与前Session末源时间相同的raw位置回调；应用状态守卫未将其转发，startGPSNavi后的首源已更新。另有A1/B2/B3启动合并“全部辅助字段为空”标志为false，前序已有本次算路traffic回调；不能仅凭该标志判断污染，SDK辅助缓存来源尚未独立证明。这些事实不等于两组所有预导航行为完全相同，也没有被认定为正式导航中的旧状态覆盖。

## 请求确认的六个具体问题

1. GPS 驾车导航 active 且设备静止时，location 与 navigation info 回调约 60 秒才再次到达，是否为 SDK 的预期策略？分别由什么机制决定？
2. 独立系统 Core Location 已提供新样本，而 AMap 回调携带的 source timestamp 长时间不推进，是否可能是预期的静止缓存或合路定位行为？该字段代表原始采集时间、匹配时间还是其他时间？
3. 静止导航时，官方建议如何判断 location freshness：使用 callback 到达时间，还是 source location timestamp？若源时间重复，接收时间是否足以证明位置仍然有效？
4. 11.2.100 与 11.2.000 均观察到该行为。是否属于设计机制或已知行为？有无对应说明或相关变更记录？
5. 是否有官方推荐配置或公开 API，能在导航期间静止时持续获得更新后的定位 source timestamp？应如何使用，并有什么边界条件？
6. stopNavi 后是否建议每次释放全部强引用并销毁 singleton，还是支持长期保留并跨 Session 复用？这两种方式是否影响 location/navigation callback、源时间缓存、delegate 与 DataRepresentative 的状态隔离？Swift 推荐的完整清理顺序是什么？

## 最小复现与附件

使用自有 Key 和签名工程、完整 SDK 资源及位置权限。先算路，再启动 GPS 导航；静止保持前台，不注入外部位置，不重启、不重新算路、不篡改 timestamp。记录最原始回调入口的单调时间、SDK source timestamp 和 raw/provider/Snapshot/Core 各层计数。版本比较保持 Foundation、源码、路线及时间窗口一致；生命周期比较在同一进程连续完成三个 Session，分开改变 Stop 后的 manager 策略。

附件提供实测 App 的调用片段和脱敏日志，不声明新增独立最小 App 已编译或真机通过。私人终点及精确路线坐标不随包提交；路线一致性以指纹及点数/长度验证。完整路线控制的固定 hash 仅适用于本地原路线，复现者应为自己的路线建立本地基线。

关键证据：Phase 10.7 系统定位对照、raw/provider/Core 边界摘要；Phase 10.8 相同路线两个版本的原始日志与 comparison；Phase 10.9 生命周期结果、实际执行边界与日志（如已执行）。材料不含 Key、签名证书、开发者私钥、私人地址或不必要账号信息。

目前未添加 stale 后自动 stop/start、watchdog recreate、定时强制刷新、源时间改写或 Core Location 替代导航位置。待官方澄清后再评估干净配置或生命周期修复。

官方参考：[GPS 导航与生命周期](https://developer.amap.com/api/ios-navi-sdk/guide/navigation-map/gps-navi)、[定位配置与回调](https://developer.amap.com/api/ios-navi-sdk/guide/location-info/location-setting-callback)、[外部定位模式](https://developer.amap.com/api/ios-navi-sdk/guide/location-info/externallocation)。

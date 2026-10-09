# 开源参考与许可证审计

核对日期：2026-10-05。以下均只参考公开 README 和仓库结构；没有引入第三方文件或代码，因此当前无需随包署名。若后续复制实现或资产，需重新审计具体提交及其依赖。

| 仓库 | URL | License | 研究结论与采用模式 | 使用代码/引入文件 | 商业发布风险 |
|---|---|---|---|---|---|
| WristMap | https://github.com/atomi19/WristMap | MIT | iPhone 导入 GPX，并向 Watch 发送活动路线；参考双端结构。其路线共享内部实现未逐文件核实。 | 无；仅参考设计 | 当前无代码许可风险；未来复制需保留许可。 |
| OG Bike Computer / Computa | https://github.com/Aidan3445/OG-Bike-Computer | MIT | `Shared`、iPhone、Watch、Widget 分层；README 称支持逐向导航、触觉、偏航重接。具体状态机未逐文件核实。 | 无；仅参考设计 | 当前无代码许可风险；其 Strava/RideWithGPS 集成与本项目无关。 |
| Scooter Companion | https://github.com/djensenius/gt3pro | Apache-2.0 | README 明确 iPhone 为中心、Watch 用 WCSession 作为副显示器；借鉴角色划分，不引入其车辆、服务器或轨迹功能。 | 无；仅参考设计 | 当前无代码许可风险；未来复制须检查 NOTICE 与 Apache 条款。 |
| WatchConnectivitySwift | https://github.com/ts95/WatchConnectivitySwift | MIT | README 展示 Swift 6、强类型请求、实时消息与最新 context 兜底、连接诊断；本项目独立实现轻量消息协议。 | 无；仅参考设计 | 当前无代码许可风险；未安装该依赖。 |

没有发现上述仓库属于 GPL、AGPL、LGPL 或无 LICENSE 的情形。README 级调研不能代替引入代码前的逐文件许可证核对。

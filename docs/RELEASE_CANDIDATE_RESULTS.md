# AMap-only NavigationWatch RC1 验收

更新：2026-10-08。**Project Core Implementation：COMPLETE — Release Candidate**。

## 构建与安装

| 项目 | 已核实结果 |
|---|---|
| 产品 | AMap-only NavigationWatch RC1 |
| App / Watch / Widget 版本 | 1.0，build 2 |
| Xcode | 27.0 (27A266a) |
| 最低系统 | iOS 18.0 / watchOS 11.0 |
| 导航 / Foundation SDK | AMapNavi-NO-IDFA 11.2.100 / AMapFoundation-NO-IDFA 1.9.1，现有 Pods |
| 搜索 SDK | 官方 AMapSearch-NO-IDFA 9.8.1，手动 Vendor/AMapSearchKit.framework 链接；Podfile/lock未改 |
| 实体设备 | iPhone Air / Apple Watch Series 10，当前均 OS 26.6 |
| Release build | PASS，签名设备构建；AMap.bundle / AMapNavi.bundle 齐全 |
| 安装 | iPhone 与 Watch success；iPhone launch success |

初次签名产物遗漏私有 xcconfig（Key为空），已停止用它验收，重新用正式 Config.local.xcconfig 构建并覆盖两端安装。最终 artifact-check.json 的 keyConfigured=true。签名构建日志意外含构建参数中的 Key，已按实际凭据替换为 REDACTED；不打印/交付真实Key，不制作含私有配置的ZIP。

证据位于当前项目工作区 work/rc1：signed-release-build.log、artifact-check.json、install-phone.json、install-watch.json、launch-phone.json、devices.json、tests.log。安装/启动不是功能验收。

## 本轮实现

- AMap正式关键词搜索：名称、optional地址、GCJ02来源坐标；隐私同意后初始化。无结果、超时、取消、SDK错误明确提示，搜索不收集当前位置。
- AMap实际 naviRoutes 映射统一 NavigationRoute：真实距离/时间、optional交通；UUID与SDK routeID仅Provider内对应，拒绝旧/变造路线。用户实际选择路线后 startGPSNavi。
- PhoneModel统一 finish：用户停止、到达、终态、启动失败/已退出导航的致命错误；先退役generation，再发布终态、结束Activity、停止Provider/后台定位、清空临时状态。重算失败只提示，不自动重启。
- 生产路径仅AMap；Mock与诊断按钮/序号DEBUG隔离；Apple实验源码保留而不编入正式iPhone target。
- iPhone原生搜索/路线/导航/设置收口，缺数据隐藏；Watch仅滚动容器、下一道路换行及统一距离单位。未重做Watch状态机或Activity/Island/Stack布局。用户随后发现Watch Stop缺失，补齐现有stopNavigation消息入口、10s确认超时/错误提示；iPhone按sessionID拒绝迟到旧Stop请求，收到终态才显示等待。stop-fix-build.log Release PASS，双端安装与手机启动success（stop-fix-install/launch JSON），实际停止及返回等待复验用户确认PASS。
- 自身Phone/Watch Privacy Manifest声明自身不tracking及UserDefaults必要用途；未虚构SDK隐私清单或声称完整App Privacy通过。

## 十项最终核心 smoke

依据用户本次正常路线及修复版最终确认记录PASS；历史成功不替代RC1。最终回复：“全部正常，无崩溃；最终已停止”。证据user-acceptance.json。

| 测试 | RC1结果 |
|---|---|
| 1 启动→搜索→路线→开始 | PASS（用户确认搜索/路线距离时间正常，开始成功） |
| 2 真实导航持续更新 | PASS（用户确认移动时更新正常） |
| 3 iPhone后台/锁屏 | PASS（用户确认） |
| 4 Watch收到导航 | PASS（用户确认） |
| 5 Watch Stop回到等待 | PASS（初版无按钮FAIL；最小修复后用户确认手机结束/Watch等待） |
| 6 Live Activity创建/更新/结束 | PASS（用户确认） |
| 7 Dynamic Island | PASS（用户确认显示/更新/结束） |
| 8 Smart Stack出现/更新/点击/结束 | PASS（用户整体确认卡片正常；点击进入Watch未独立逐项记录） |
| 9 Stop后后台资源清理 | PASS（用户确认结束；代码stopNavi/关闭后台定位/释放会话；长期GPS/能耗未仪器量测） |
| 10 再开始新session无旧数据污染 | PASS（用户确认，且退役stream契约PASS） |

用户确认：开始导航后静止时出现“定位信息暂未更新”，搜索结果/路线距离时间正常显示，开始成功。该场景与既有静止vendor行为相符，仅凭提示不另行判断根因；未调整freshness、未restart。随后修复版用户确认移动更新、锁屏、Watch/卡片、Stop和新会话均正常且最终已停止；静止提示保留Known Vendor Dependency，不写根因修复。

## 最小验证与边界

最小Watch Stop修复仅追加Release构建/双端安装和产物核查，不重跑未受影响的历史测试。stop-fix-artifact-check.json确认按钮进入Watch Release产物、Key已配置及资源/自身manifest齐全。

5个ReleaseCandidateTests：真实路线数据和不透明ID、旧/变造选择拒绝、无效metrics过滤、可选模型往返/单位、Core停止再开始拒绝退役stream，全部PASS（0失败）。其余历史套件没有执行，不把输出中的0 tests称为PASS。真实AMap搜索/路线/导航由本次用户实体反馈确认；权限拒绝/网络失败UI未逐项真机覆盖；没有重跑全部历史实验。

Core NavigationEngine、NavigationEnrichment、NavigationDiagnostics SHA与本轮基线一致，freshness/AMap源时间策略未改；Release开发UI字符串缺失检查通过。上述不是VoiceOver、全部Dynamic Type或实时道路行为的全面验收。

Crash初始列表已保存为crash-phone-before.json/crash-watch-before.json，最终crash-comparison-final.json双端无新增（iPhone15→15，Watch0→0）；用户反馈无崩溃。这是本次短验收，不替代长期稳定性测试。历史Watch退出为not currently reproducible/root cause unknown。

Lane、真实speed limit、非空Road Event本次均NOT OBSERVED，不单独绕路；Traffic/Camera/灯数量保留此前已观察范围，不显示灯态/倒计时。AMap静止callback问题独立Known Vendor Dependency，无新workaround。

## 文件与上架准备

源码/工程修改见 work/rc1/changed-files.json（将列出相对正式工程路径）；文档更新README、ARCHITECTURE、PROJECT_STATUS、NEXT_SESSION_HANDOFF、APP_STORE_RISKS，并新增本页、KNOWN_ISSUES、PRIVACY_POLICY_DRAFT。

商业授权、SDK隐私清单/聚合报告、最终隐私政策URL、地图版权/审图号适用要求、正式bundle IDs与分发签名、元数据/截图/支持联系、Archive验证均TODO，详见APP_STORE_RISKS。此次不提交App Store。

## 最终结论

AMap-only核心用户链路与修复后的十项smoke依据本次用户反馈和构建/源码证据通过，Project Core Implementation COMPLETE / Release Candidate。Stop资源清理证明包含SDK停止/背景标志关闭/会话清空和用户实际终态，不包含长期电量/仪器GPS测试。Smart Stack用户整体确认正常，点击路由沿用既有实现及历史验证，本次未逐项独立确认点击。

实际核心blocker：无。高德静止行为仍待供应商回复，不影响本次用户确认的移动导航；App Store发布仍有合规/材料TODO。用户已停止最终会话，本轮完成并停止，不自行扩大业务或增加Provider。

# Phase 10.8 — AMap SDK Behavior Validation

日期：2026-10-08（北京时间）。独立受控验证；受控验证完成；根因与修复仍UNKNOWN，不新增业务功能，不加自动重启workaround，正式SDK保持11.2.100。

## 官方用法与代码核对

1. 导航SDK内部在AMapNaviDriveManager初始化时调用系统CLLocationManager。官方后台导航示例要求allowsBackgroundLocationUpdates=true、pausesLocationUpdatesAutomatically=false；当前GPS导航前设置正确，Xcode开启location后台模式。前台permission/precise validation用App自己的manager，不等于给高德传入定位。[官方定位配置](https://developer.amap.com/api/ios-navi-sdk/guide/location-info/location-setting-callback)
2. 外部定位驱动必须显式enableExternalLocation=true并setExternalLocation传入完整位置。当前源码无此设置或传入，属于SDK内部定位驱动。运行时开关仍必须在新日志核对，不能只相信默认值。[外部定位模式](https://developer.amap.com/api/ios-navi-sdk/guide/location-info/externallocation)
3. 当前使用sharedInstance，delegate与dataRepresentative注册，算路成功后startGPSNavi；显式Stop调用stopNavi/remove/delegate=nil/destroyInstance，与官方次序一致。Provider与manager强引用覆盖导航期。11.2.100头文件说明destroyInstance若失败需检查强引用；当前private let manager仍在Stop时持有，销毁返回值此前未记录。本轮A实测false，与官方强引用警告一致，但尚未通过释放引用单变量实验确立因果，也不能归为运行中stall原因；正式对比保持当前生命周期不变。[导航生命周期示例](https://developer.amap.com/api/ios-navi-sdk/guide/navigation-map/gps-navi)
4. Phase10.7独立持续CoreLocation observer可能影响系统定位调度；不能假设两套manager在底层完全独立，也不能直接认定模式冲突。Phase10.8 A/B均关闭持续observer和一次性requestLocation，只保留权限检查。若两版此条件下仍stale，额外observer不是必要触发条件；这仍不证明SDK内部根因。
5. 公开文档对AMapNaviLocation.timestamp仅标为时间戳，没有查到静止时每秒推进的承诺。是否静止缓存/定位引擎行为须向高德确认，不由本App伪造freshness。

## 相邻版本与隔离方法

A=11.2.100，B=11.2.000；CocoaPods公开分发列表相邻两版，官方zip与podspec已保存。两版均依赖Foundation>=1.9.0；本轮Foundation实际二进制固定1.9.1并核对SHA256相同。官方网页已有更新版本展示，但本轮使用可核实、仅更换Navigation包的相邻版本对照。

环境无可用pod命令。B使用11.2.000官方完整framework/资源替换到隔离的既有Pods集成路径，非正式pod update；继承的Podfile.lock是11.2.100集成基线，不作为B版本证据。B真实版本由官方zip/头文件11020000/二进制hash和运行时AMapNaviVersion共同核对。资源脚本、链接路径与应用代码两版相同。variant-manifest.json记录来源/校验值。正式两个工程的Podfile/锁文件/SDK不变。

## 固定条件

同一实体iPhone Air/iOS26.6，静止、同位置、前台、同一终点；实际路线首轮未匹配，GPS导航，SDK内部定位，后台配置相同，stale阈值15秒，计划各120秒。新进程启动，消除上一轮singleton遗留影响；没有外部位置注入/独立对照。Foundation、业务源码、DEBUG观测源码保持一致。

同路线以用户同位置同终点确认，加destinationHash和完整routeShapeHash/routeLength/pointCount核对；几何不一致则明确比较限制，不能声称严格同路线或据此确认regression。服务器算路/信号/缓存/温度无法完全锁定；本轮每版一次只是最小筛查，不证明单版本“永远不复现”。

两份临时构建均固定DEBUG PHASE108_VALIDATION；不依赖启动参数，手动打开也保持受控条件。未固定的普通工程可用-phase108-sdk-only标志，仅DEBUG生效，start后120秒单次固定验证截止，调用既有Stop，不再start/recreate/reroute。这是测量结束，不是恢复机制；普通运行和Release无此计时停止。

## 首轮筛查（路线不同，仅作辅助证据）

| 项 | A 11.2.100 | B 11.2.000 |
|---|---|---|
| 完整120秒/静止前台 | PASS，120.212秒，已自动停止 | PASS，已自动停止；准确时长见summary-B |
| 运行时版本/外部定位开关 | 11.2.100 / false；独立CL callback=0 | 11.2.000 / false；独立CL callback=0 |
| AMap location raw最大callback gap | 60.073秒 | 60.040秒 |
| AMap navigation raw最大callback gap | 59.018秒 | 59.002秒 |
| SDK源timestamp推进 | 3次输出、1个源时间，0次advance | 3次输出、1个源时间，0次advance |
| stale与自然恢复 | stale YES、fresh恢复NO；最大源年龄121.18秒 | stale YES、fresh恢复NO；最大源年龄121.07秒 |
| 同路线指纹 | 37903米/406点，hash 38bb1dec… | 35612米；hash不同，严格对照未成立 |
| destroyInstance返回 | false，停止时strong manager尚存，因果待验证 | false，相同生命周期 |

maximumGap用ContinuousClock更新，保留两次回调之间的最大间隔；maximumObservedAge为未返回时已观察到的静默尾段。每秒采样、日志最长10秒一条，结果报告精度/窗口末尾未记录的短区间，不伪造精确最长间隔。

## 最小验证

新增Phase108SDKValidationTests一个用例，单调间隔最大值与回调返回/墙钟变化/乱序验证PASS。不跑全量业务回归。A/B首轮签名build及资源检查PASS；A首笔启动被Locked拒绝，用户手动开启未带参数导致旧一次性请求，该样本排除并保留。随后将相同受控条件固定到两份临时构建，受控版本build及真实运行另记，不把排除样本当正式A结果。

## 判定规则

仅一版复现且条件匹配：SDK版本相关regression可疑，需受控重复或官方确认才能定根因。多版复现：不支持11.2.100独有regression，优先考虑共同使用方式或内部定位行为，准备最小复现包交高德。两版未复现：NOT REPRODUCED DURING THIS TARGETED A/B RUN，不写FIXED；与Phase10.7 observer-on条件不同，不能单凭这次证明冲突。

不改变SDK内部定位配置，不延长freshness阈值，不传入伪造时间，不重启SDK，不改Smart Stack/Live Activity/Watch UI。

## 首轮结论与比较限制

两版本在独立CL observer/requestLocation均关闭时复现约60秒的AMap raw回调间隔、源时间0次推进和stale。额外App诊断定位请求不是本轮现象的必要条件；没有发现外部/内部定位模式混用证据。当前结果不支持仅11.2.100独有的解释，但真实routeLength与完整geometry hash不同，不能当作完全同路线版本对照，首轮严格条件未成立；后续同路线复核已完成，见下文。manager销毁false另记为生命周期待验证问题，运行期因果UNKNOWN。

为闭合同路线条件，隔离DEBUG验证增加从SDK naviRoutes按A首轮完整geometry hash选择的门控；不匹配时算路报错，不调用startGPSNavi，不计入120秒样本。此门控仅存在隔离验证源码，正式业务不变。路线备选指纹与匹配结果保存到route-control日志。

## 同路线追加复核（最终有效对照）

B2：09:13:13–09:15:13，完整120秒并自动Stop，SDK11.2.000；从3条备选中选择首轮A完整hash，routeLength37903/406点、destinationHash及全部geometry hash匹配。位置raw最大gap60.054秒，导航信息59.043秒，2次位置输出/1个源timestamp/0次advance，stale YES、自然fresh恢复NO，源年龄最大120.86秒。独立CL回调0、全程前台，destroyInstance=false。A2采用同门控源码与相同路线，09:16:32–09:18:32完整120秒并自动Stop；全部控制字段已匹配。

| 最终同路线指标 | A2 11.2.100 | B2 11.2.000 |
|---|---|---|
| 实际测量窗口 | 120.178秒 | 120.102秒 |
| 完整路线 | 37903米/406点，hash 38bb1dec… | 完全相同hash/长度/点数 |
| raw location最大callback gap | 60.096秒 | 60.054秒 |
| raw navigation最大callback gap | 59.025秒 | 59.043秒 |
| 位置输出/不同源时间/advance | 2/1/0 | 2/1/0 |
| stale / 自然fresh恢复 | YES / NO | YES / NO |
| 最大源年龄 | 120.892秒 | 120.863秒 |
| 自有CL诊断回调/外部定位开关 | 0 / false | 0 / false |
| 全程前台 / 自动停止 | PASS / PASS | PASS / PASS |
| destroyInstance | false | false |

## 最终判定与后续入口

Phase10.8受控验证完成；Phase10.5仍PARTIAL。多版本、相同完整路线、相同配置与Foundation、同源码条件下均复现，**不支持11.2.100独有regression解释**，优先询问共同使用方式或SDK内部静止定位/缓存行为。两版各一次同路线120秒，不等于证明所有版本/全部场景稳定必现，更不能认定SDK defect。额外诊断CoreLocation请求非必要触发条件，SDK私有内部输入不可观测，内部根因仍UNKNOWN。

下一步入口：先使用support-materials确认AMapNaviLocation.timestamp静止语义、约60秒回调机制与官方推荐内部定位配置；另外单独核验Swift strong manager释放及destroyInstance=false的干净生命周期处理。不要据此自动加入SDK重启，不伪造源时间或放宽15秒stale。技术支持包已准备、未实际发送；包为已实测App调用片段与原始证据，非新增独立App编译通过的声明。

源码只存在隔离work/phase108/Source和两份临时Pod构建；正式工程业务代码、Podfile/锁文件/11.2.100不变。1项最大间隔专项测试PASS，A/B受控构建与同路线门控构建PASS，真机证据如上。最初未带受控模式样本排除；首轮路线不同样本保留为辅助证据；最终结论只使用A2/B2。字体版报告Report.html使用Times New Roman及宋体/Songti字体。

# Phase 5 高德驾车接入记录

日期：2026-10-06。此记录属于可写接入副本；原 ChatGPT 同步镜像没有修改。

## 本次实现

- iPhone 新增 `AMapNavigationProvider`，沿用 `NavigationProvider → NavigationCore → NavigationSnapshot → WatchConnectivity → Watch`。高德 SDK 不进入 Watch Target。
- 驾车路线以当前位置为起点、用户输入的高德坐标系终点经纬度为终点。路线规划成功后启动 GPS 导航。每次启动生成新 sessionID，快照 sequence 从 0 递增。
- 映射转向、当前/下一道路、转向距离、剩余距离/时间、预计到达时间和车道；高德未提供或本轮未核实的字段保持 nil。停止时清理 SDK delegate 与数据代表，并让现有通信层发送终态。
- iPhone 增加模拟/高德驾车选择和首次高德 SDK 初始化前的隐私同意入口。Key 从 iPhone App 的 `AMapAPIKey` Info.plist 构建值读取；不写入源码。
- 算路请求增加 30 秒超时，避免 SDK 不回调时界面无限等待。
- iPhone 在路线已启动、首条定位快照尚未抵达时保留“停止导航”入口，避免重复启动；请求结束时取消超时任务。修正 SDK 图标 18（驶出环岛）与 19（掉头）的映射。
- `Podfile` 指定无 IDFA 导航 Pod，仅安装到 iPhone Target；将 Pod 目标部署版本设为 iOS 18，避免 Xcode 27 拒绝其默认的 iOS 9 模拟器目标。Watch 的快照模型和正式通信协议未修改。

## 实际验证

| 检查 | 结果 |
|---|---|
| `AMapSnapshotMapper` 两项定向测试 | PASS，2/2 |
| 无 SDK 的 Debug generic iOS Simulator 构建（含 Watch Target） | BUILD SUCCEEDED；高德入口在运行时提示 SDK 未安装 |
| 使用高德官方 11.3.100 导航开发包和 1.9.4 基础包进行临时手动链接的 Debug generic iOS Simulator 构建 | BUILD SUCCEEDED；仅用于核对 SDK Swift 接口与目标链接，不代表 `Podfile` 11.2.100 已安装或验证 |
| 用虚拟 `TEST_KEY` 验证 iPhone App 信息文件 | PASS；构建产物的 `AMapAPIKey` 为 `TEST_KEY`，没有使用真实凭据 |
| 本机 `Config.local.xcconfig` 注入链路 | PASS；Debug 模拟器构建成功且 App 信息文件读到 `TEST_KEY`；虚拟配置随后已删除 |
| 用户提供的本机 Key 配置 | PRESENT；仅确认非空和对应的 iPhone Bundle ID，没有输出 Key 内容 |
| 官方 11.3.100 导航开发包手动链接的实体 iPhone Air 构建 | BUILD SUCCEEDED；更新版已安装并启动，确认进程仍在运行，App 信息文件中的 Key 非空 |
| 真机点击“同意并继续” | 先前临时手动链接版本发生 SIGABRT；设备崩溃记录显示 `AMapNaviLocalizationUtils.localizedTextWithToken` 在导航管理器初始化时调用 `NSBundle bundleWithURL:` 后异常。核对安装包发现缺少 `AMapNavi.bundle`、`AMap.bundle`。按高德官方要求将两包加入 iPhone Copy Bundle Resources 后重建、重装，两包均嵌入；用户复测回报不再闪退，并出现导航指令 |
| 真机驾车算路 | 用户截图显示输入纬度 `31`、经度 `120` 后旧版提示“无法开始高德导航：未能完成操作”。加入前台定位与精确位置检查、保留高德 SDK 错误码后，诊断版构建、安装、启动成功；用户用同一组坐标复测回报导航成功。旧版没有保留错误码，原始失败原因无法确定。复测后 App 进程仍运行，没有新增崩溃记录 |
| iPhone 重复启动与停止 | 更新版实体 iPhone 构建、安装、启动成功；用户在静止状态下回报“开始→停止→再开始”两次正常，停止按钮有效。首条快照前的按钮状态未单独观察 |
| iPhone 前台导航快照连续更新 | 用户回报手机静止、导航页面保持前台约 1 分钟时“序号持续增加”。这证明页面在该条件下收到连续快照；未核对每条快照的道路、距离、位置是否变化，也未验证移动中的 GPS 引导 |
| SDK 转向图标映射 | 核对官方 11.3.100 头文件，修正图标 18/19/20；定向单元测试 1/1 PASS |
| 正式 `pod install` | 初次下载高德导航包时，域名默认命中的 CDN 地址在 TLS ClientHello 后报 `SSL_ERROR_SYSCALL`；抽查另外三个同域名地址均返回 HTTP 200，直接重试后安装成功。`Podfile.lock` 锁定 `AMapNavi-NO-IDFA` 11.2.100 和 `AMapFoundation-NO-IDFA` 1.9.1；未绕过证书校验 |
| 正式 CocoaPods 版构建与启动 | 初次模拟器构建因 Pod 目标默认 iOS 9 低于 Xcode 27 支持范围而失败；在 `Podfile` 中将 Pod 目标设为 iOS 18 后，Debug generic iOS Simulator 构建通过，App 含 `AMapNavi.bundle`、`AMap.bundle`。使用本机 Key 的实体 iPhone 签名构建、安装、命令行启动通过，随后进程仍在运行；临时 Key 副本已删除 |
| 正式 Pod 11.2.100 静止导航复测 | PASS（基础 Provider 集成）。用户按要求在实体 iPhone 静止、App 前台约 1–2 分钟使用之前成功的终点；回报出现导航指令且序号持续增加，未报告错误或闪退。随后同 Pod 诊断版记录 SDK 导航信息回调与快照序号 0–5，指令非空、剩余距离 317920 m、剩余时间 14373 s。静止时 SDK 回调可能近 1 分钟无更新；移动中的 maneuver、车道和路况仍为 NOT YET VERIFIED |
| iPhone 锁屏后台、移动中的 GPS 引导 | 锁屏后台 Phase 6 按本轮约 2–3 分钟静止验收规则 PASS，详见 `PHASE6_BACKGROUND_RESULTS.md`；移动中的引导仍需独立验证 |
| Watch 验证 | 既有配对 iPhone/Watch Simulator Mock 最小联测通过；Physical Apple Watch validation deferred。实体 iPhone → 实体 Watch 端到端链路 NOT VERIFIED ON PHYSICAL WATCH |

## 继续前的条件

1. 正式 Pod 安装、模拟器构建、iPhone 安装启动及静止状态算路/连续序号已有结果；若在新环境重装时遇到同样 TLS 错误，可先重试并检查同域名不同 CDN 地址，保留证书校验。隐私清单未在本次 Pod 文件和 App 包中找到，发布前需向高德核实。
2. 用户已在本机 `Config.local.xcconfig` 配置与 iPhone Bundle ID `dev.local.NavigationWatch` 对应的高德 iOS 导航 Key；已确认构建产物的 `AMapAPIKey` 非空，并在 iPhone 上回报算路成功。尚无独立鉴权日志或路线详情记录；本机配置不纳入交付压缩包。
3. 2026-10-06 Phase 5A/6 验收时实体 Watch 验证为 deferred，Watch 最小回归使用配对模拟器。用户随后报告实体 Watch 已可连接，但存在连接中断和信息延迟；该后续问题需单独诊断，不将先前模拟器结果写成真机 PASS。
4. 发布前补齐应用隐私政策及高德 SDK 披露，确认该 iPhone 导航、Watch 副显示形态的授权与计费条件。

高德官方手动部署说明要求将 `AMapNavi.bundle` 和 `AMap.bundle` 加入 App 资源。项目声明的 `AMapNavi-NO-IDFA` 11.2.100 Podspec 也列出了这两个资源；本次正式 Pod 版的构建产物已核对包含两包。[高德手动部署](https://lbs.amap.com/api/ios-navi-sdk/guide/create-project/manual-configuration)；[Podspec](https://github.com/CocoaPods/Specs/blob/master/Specs/c/5/d/AMapNavi-NO-IDFA/11.2.100/AMapNavi-NO-IDFA.podspec.json)。

正式 Pod 11.2.100 版的基础 Provider 集成按本轮规则标为 PASS：实体 iPhone 静止前台复测出现指令、序号增长，未报告闪退；诊断版另记录距离/时间数值。移动中的 GPS 引导仍未验证；实体 Watch 已被开发工具识别，但实时导航同步稳定性尚未验收。

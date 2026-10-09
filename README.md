# NavigationWatch

iPhone 与 Apple Watch 高德导航应用。支持真实驾车导航、Watch同步与停止、车道/路况/事件、Live Activity、Dynamic Island、Smart Stack、高德分享链接导入、最近目的地和全程路线地图。

当前源码：**1.0(10)**。正式默认AMap，无自动地图fallback；Apple Route-only只作架构实验。早期核心导航已获用户验收，最近UI及地图全览仍待真机确认，详见[状态](docs/PROJECT_STATUS.md)。静止AMap callback行为仍待供应商澄清。

## 本机配置

1. 使用Xcode及CocoaPods；iOS最低18、watchOS最低11。当前实体构建环境使用Xcode27。
2. 从高德官方取得Search 9.8.1无IDFA SDK，按[Vendor说明](Vendor/README.md)放置。其他SDK通过`pod install`安装，保持Podfile.lock固定版本。
3. 将`Config.example.xcconfig`复制为`Config.local.xcconfig`，填写绑定自己Bundle ID的高德iOS Key。该文件被Git忽略。
4. 运行`pod install`，打开生成的`NavigationWatch.xcworkspace`。选择自己的签名团队，必要时调整Phone/Watch/Widget Bundle ID及高德Key绑定。
5. 双端安装后分别验证导航与UI。不要将模拟器或构建通过当作实体功能通过。

## 最小测试

`swift test --filter RoutePlanningTests`

`swift test --filter DestinationHistoryTests`

按修改范围选择相关测试，不重跑全部道路历史实验。

## 仓库范围

由正式NavigationWatch-Phase5源码导出，不含真实Key、设备日志、构建缓存、Pod/SDK二进制或个人位置记录。作者：张秀康。保留源码、测试、配置样例及经路径/设备标识脱敏的项目文档。

## 开源许可

本项目自有源码与文档采用 [MIT License](LICENSE)，Copyright (c) 2026 张秀康。允许使用、修改、分发及商业使用，须保留许可证与版权声明。

高德等第三方 SDK、地图数据、服务及其商标不属于本项目的 MIT 授权范围，仍遵循供应商各自的许可和使用条款。使用者需自行获取 SDK、申请 API Key，并满足相关商业授权、隐私及地图版权展示要求。

后续先读[交接](docs/NEXT_SESSION_HANDOFF.md)。仓库使用相对路径；交接文档中`<LOCAL_PROJECT_PATH>`和`<LOCAL_DEVICE_ID>`是本机记录脱敏标记。

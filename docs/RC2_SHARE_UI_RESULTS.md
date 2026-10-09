# RC2 高德分享导入与显示修正

2026-10-08。版本1.0 (3)，正式AMap-only。**PASS — 代码、6项限定测试、Release build及本次用户实体复验通过**。RC1核心完成结论保留为历史已验收基线；本次三项UI/导入PASS另有用户反馈依据。

## 高德路线及地点链接

首页“导入高德分享链接”→系统PasteButton或手工粘贴分享文本→确认隐私→解析终点→从当前位置高德重新算路→用户选路开始。不会自动开始导航、替换正在导航的session，也不会按分享链接原始起点/整条几何路线导航；途经点/策略未复制。设置自定义URL入口navigationwatch://import?url=百分号编码的高德链接。

支持官方URI navigation的to、marker的position/poiid、m.amap.com/navi的dest、iosamap navi/path中已有偏移终点；GCJ02保持统一模型。未偏移WGS84链接明确提示不支持，不默认为高德坐标。只有POI ID时通过官方Search SDK ID查询取得位置。

两条用户当前App实际分享短链接均返回302到wb.amap.com：路线r字段为起点latitude/longitude/name后接终点同组三元组；地点p为POIID/latitude/longitude/name/address。本轮直接以实际分享跳转验证此格式，**不是官方承诺该私有分享格式永不变化**。两条真实resolver测试PASS；真实地点名称/坐标未写入测试fixture或公开文档。

短链接解析用ephemeral URLSession HEAD、15/20秒超时、最多5次跳转、逐跳高德HTTPS域名白名单，不读取剪贴板后台历史，不执行HTML/JS。非法来源、重复路由参数、无效坐标、不同坐标系或非驾车模式明确报错，不silent fail。此版本是复制链接→App导入/自定义URL入口，**没有系统Share Extension**，不能接管高德HTTPS域名或宣称系统分享菜单直达本App。

依据：[高德路径规划URI](https://lbs.amap.com/api/uri-api/guide/travel/route)、[地点标注](https://lbs.amap.com/api/uri-api/guide/mobile-web/point)、[iOS导航URI](https://lbs.amap.com/api/amap-mobile/guide/ios/navi)、当前官方Search SDK头文件。

## Smart Stack

用户附图证明白色卡片背景上主要距离/下一道路近乎不可读。原Activity使用systemBackground但继承宿主文字环境，存在背景/文字不一致。视图与activityBackgroundTint改为统一深中性背景，正文白色，辅助信息白色82%透明度，转向保持蓝色。小family内边距12，撑满系统给定区域，不修改Activity session、限流、状态机或Island核心布局。锁屏卡片同步采用相同成对配色。依据[Apple Live Activity视图](https://developer.apple.com/documentation/activitykit/creating-custom-views-for-live-activities)。本次用户确认Smart Stack文字清晰，PASS。

## iPhone黑边

用户明确上下黑边/未铺满，源Info.plist和构建设置均无Launch Screen。补充现代UILaunchScreen空字典，Root NavigationStack使用可用空间，不用忽略安全区强行放大，不硬编码手机尺寸。最终产物确认UILaunchScreen存在；用户本次确认上下黑边消失，PASS。依据[Apple Launch Screen](https://developer.apple.com/documentation/xcode/specifying-your-apps-launch-screen)。

## 最小验证

- AMapShareLinkTests 6项PASS/0失败：实际路线短链接、实际地点短链接、两类分享schema、官方URI、粘贴/自定义scheme/ID、恶意/歧义/非法数据拒绝。其余套件0 tests未执行，不报为PASS。
- Signed Release build PASS；首次编译的Section初始化形式已修正后构建通过。
- artifact-check.json：1.0(3)、Launch Screen、自定义scheme、Key配置及AMap资源PASS。构建日志Key已脱敏。
- Core、freshness、诊断及AMapNavigationProvider SHA与本轮基线一致，无callback workaround，无Provider fallback。
- 实体iPhone/Watch安装及iPhone启动success（install-phone/install-watch/launch-phone.json）；两端build3一致。用户本次确认上下黑边消失、两种分享导入目的地及路线正常、Smart Stack清晰，并已停止，三项PASS，仅界面收口，不要求重跑历史道路实验。

## 修改文件

AMapShareLink.swift（新）、AMapDestinationSearch.swift（POIID查询）、NavigationWatchPhoneApp.swift（导入表单/URL入口）、iOS/Info.plist、Widgets/NavigationLiveActivity.swift、project.pbxproj、Package.swift、ShareTests/AMapShareLinkTests.swift（新）；正式工程与Pods镜像均同步。文档本页、PROJECT_STATUS、NEXT_SESSION_HANDOFF、KNOWN_ISSUES、PRIVACY_POLICY_DRAFT/APP_STORE_RISKS补充入口和用途。

## 最终实体验收

用户明确回复：“三项都正常，已停止”。iPhone全屏适配、高德路线/地点分享App内导入及正确路线、Watch Smart Stack可读性均PASS。证据work/rc2/user-acceptance.json；与6项解析测试、Release build和双端install/launch证据分开记录。没有重新道路回归，不把本次UI验收当作长期稳定性或全部分享格式覆盖。Core/freshness/AMap Provider生命周期未改，本轮结束。

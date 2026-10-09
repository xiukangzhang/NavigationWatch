# RC1 上架与合规待办

2026-10-08。正式产品AMap-only；未提交App Store，未获得正式法律/审核批准。

## 当前库存

| 依赖 | 版本/来源 | 隐私清单核查 |
|---|---|---|
| AMapNavi-NO-IDFA | 11.2.100，Pods | 当前安装目录未找到SDK manifest，TODO向官方取得匹配版本清单 |
| AMapFoundation-NO-IDFA | 1.9.1，Pods | 同上 |
| AMapSearch-NO-IDFA | 9.8.1，官方下载，手动Vendor framework | 当前官方压缩包未发现manifest，TODO；不是已完成Pod集成 |
| Apple系统框架 | CoreLocation、WatchConnectivity、ActivityKit、SwiftUI | 自身Phone/Watch manifest已加入UserDefaults CA92.1与自身tracking=false；仍需Archive聚合隐私报告核对 |
| Apple MapKit | 仅实验源码/独立测试 | 正式iPhone target不编译实验Provider、不请求其search/route |

NO-IDFA不等于SDK不收集任何信息；自身manifest不替代供应商清单。依据[高德合规说明](https://developer.amap.com/api/compliance-center/check-and-reference/sdkhgsy)核查初始化前展示与同意，依据[Apple Privacy Manifest](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)及[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)准备最终披露。

## App Privacy高层数据盘点（待SDK确认，不是最终标签）

- 搜索关键词/地点结果：搜索服务与临时路线选择，当前关键词搜索不发送本机位置；搜索词可能包含用户自填敏感地址。
- 精确位置：路线规划、GPS导航、用户主动导航时后台/锁屏持续；Stop/到达结束本次定位。SDK服务需要的数据处理不能以“只在本机”概括。
- 导航状态/道路名：系统WatchConnectivity到本人配对Watch，以及本地Live Activity，无自有服务器上传。
- SDK设备/网络/诊断信息：具体种类、关联用户、保存及tracking属性须按当前SDK说明逐项核实，UNKNOWN；不猜“不收集”。
- 自身无账号、广告、analytics/第三方crash服务、云端历史；Release不记录精确长期轨迹。Debug诊断不作为正式功能。

## 发布检查

| 项目 | 状态 |
|---|---|
| 图标 | 现有AppIcon资源保留；未完成商店视觉/完整设备图标验收 |
| Display name | NavigationWatch |
| Version/build | Phone/Watch/Widget 1.0 (2) |
| Bundle IDs | dev.local.NavigationWatch及watchkitapp/liveactivity；正式注册ID/分发profiles TODO |
| 定位文案/后台mode | WhenInUse及AlwaysAndWhenInUse说明、location mode已入包；真实锁屏/结束耗电待验收 |
| Privacy Manifest | 自身Phone/Watch已入包；第三方SDK及最终聚合报告TODO |
| 隐私政策 | App内有用途说明和高德链接；自身政策草案见PRIVACY_POLICY_DRAFT.md，发布者/联系/公开URL TODO |
| 商业授权 | TODO：高德导航及Search服务额度/许可、Watch companion文字转发范围书面确认 |
| 版权/审图号 | 设置显示高德来源；当前无地图画布，仍需高德确认此展示形态的版权文字/审图号要求，不能猜已满足 |
| 开源/第三方attribution | SDK库存已记录；须依据Pods附带LICENSE/acknowledgements整理最终适用告知 |
| 商店材料 | 截图、说明、分类、支持URL/联系人、年龄分级等TODO |
| 分发Archive | 本轮设备Release build PASS；Archive/签名出口/商店validation未执行 |

最终验收不因自然路线未出现Lane/Speed/Road而阻塞，但不能由build代替实体测试。禁止交付含Config.local.xcconfig/真实Key的ZIP；凭据仅本机配置，构建日志须脱敏。

## 历史合规记录

# 上架与合规风险

当前正式工程已集成AMap；Phase11新增Apple Route-only实验源码。以下事项不视为已获得商业授权或App Store批准。

- **高德授权**：确认商业许可、收费、API 使用范围及高级导航授权。TODO：向高德官方书面确认：“本 App 使用 iPhone Navigation SDK 进行导航计算，并通过 Apple Watch companion app 实时显示转向、距离、车道及交通信息；Apple Watch 不独立使用高德 SDK，也不接入车辆中控。请确认此产品形态所需商业授权。”保存书面答复。
- **地图数据**：不得抓取或逆向高德 App，不自建其道路/POI 数据库，不长期缓存地图数据，不移除地图版权标记。
- **位置隐私**：仅在用户主动导航期间申请并使用必要定位；结束后停止。Release 不记录完整轨迹。后续补齐隐私声明、用途文案、Privacy Manifest 和 App Privacy Labels。
- **后台能力**：后台定位仅用于真实导航。锁屏持续性、系统挂起、Watch 状态恢复及耗电须真机实测，不能预先承诺。
- **凭据**：Phase 5 采用 NO-IDFA SDK（若官方提供），检查隐私同意 API 与 Manifest；Key 不进入 Git，仅保留示例配置。

## Phase 11 Apple MapKit 简审

Apple不是另行下载的商业SDK，不添加地图Key/Secret；使用系统MapKit与现有开发协议。依据[Apple Developer Program License Agreement Attachment 6](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)：仅经公开API使用；保留版权标识；数据只能短期按需缓存；数据展示需对应Apple地图。当前不把Apple结果发到Watch/Activity纯文字界面，正式展示前需单独核实；未声称获法律或Apple审核许可。中国Apple地图服务包含AMap服务，不宣称独立数据来源。

本轮仅公共地标服务探测，无设备位置采集、后台定位、轨迹或新第三方二进制。原生MapKit不免除App隐私政策/App Privacy Labels及Privacy Manifest最终核查；本轮没有完成App Store privacy报告。私有Place/Route缓存Stop时清理，搜索/算路响应不导出持久数据。未改变AMap密钥、同意流程与本机配置，不把任何Key放Shared或交付包。

百度/腾讯未接入；未来如选择完整导航，须按当前官方AK/授权、SDK Privacy Manifest、初始化前同意、地图版权与Watch再展示条款逐项核实。当前百度官方下载页提供Privacy Manifest，不能据此认为本产品已合规；腾讯商业条件UNKNOWN。

## RC2补充

1.0(3)新增UILaunchScreen，已通过设备Release构建；自定义navigationwatch scheme只是本App导入入口，不注册高德scheme或冒充高德域名Universal Link。没有Share Extension/App Group新权限。当前wb私有分享字段仅按用户样本观测验证，未来变化明确报导入失败，不抓取页面或建POI数据库。隐私草案已补充用户主动链接解析和粘贴用途。

## 1.0(6)本机最近目的地

新增本机目的地名称/地址/坐标/ID缓存，最多20条，可逐条删除和清空；不存行驶轨迹，不主动上传历史。高德重新规划处理位置仍按SDK用途披露；自身历史存储使用已有UserDefaults reason CA92.1。首页来源页脚按用户要求删除，设置页高德来源保留；此前商业授权/版权适用要求TODO仍不凭此宣称已合规。

## 1.0(10)地图全览

使用现有导航SDK内置地图，保留原生Logo/版权和比例尺；不裁切生成静态图片，信息卡位于地图外。地图服务隐私声明已补。正式商用、地图展示/版权审图号适用要求仍需上架核实，当前构建不等于合规结论。

# Phase 11 Second Provider Decision

Selected Provider：Apple MapKit，Experimental Route-only。决定在编码之前完成官方能力比较；此次选择服务于能力降级审计，不承诺第二套完整驾车导航。

## Why

1. MKLocalSearch、MKDirections与MKRoute有当前官方资料和本机系统框架，无需增加商业SDK或第二密钥即可验证真实搜索/Route映射。
2. 与AMap完整导航差异足够大，可暴露协议默认“所有Provider都有引擎”的遗漏；支持不同能力比再复制一套完整导航更直接。
3. SDK对象停留在Apple Provider/Mapper中，统一Place/Route不携带MK类型；无需修改Watch与Activity状态机。
4. 最小集成不引入额外定位manager、后台权限、导航计时器或高德恢复逻辑，隔离成本小。

依据见[Capability Matrix](PROVIDER_CAPABILITY_MATRIX.md)中的Apple官方API与协议链接。中国Apple地图服务可能由AMap提供，所以不能把它当成独立供应链对照或AMap callback问题的根因实验。

## Why not the others

百度是未来完整第二导航引擎的有力候选：当前官方实时诱导、状态与灯数回调已确认。但独立SDK/AK、地图依赖、图片型车道转换及授权核对扩大本轮范围，当前未接入。腾讯当前官方导航文档访问/商业可用性证据不足，不能根据旧Demo推定当前能力。

## Scope

创建AppleRouteProvider(origin:)；能力声明；MKLocalSearch；MKDirections；AppleRouteMapper；opaque UUID；短期私有缓存、stop取消与清理。独立Package target和iPhone编译目标均可挂载，无正式Apple选择UI。通过NavigationProvider注入，route-only start返回unsupportedOperation，AsyncStream正常结束。没有实时Snapshot、语音、后台导航、map matching或自动reroute。

AMap依然正式默认，Mock仅保留已有手动选择。没有复杂Registry/DI：当前生产AMap创建还有专属授权与定位检查，未把它复制给Apple；独立构造已足够完成Spike，不强加未使用工厂。

## Risks

Apple地图展示需对应Apple地图，当前Watch纯文字展示不作为合规方案；生产接入须独立确认。系统SDK成熟不等于中国每条路线可用，服务访问和真机许可边界以本轮日志为准。网络/配额/地区行为不承诺。SDK不提供完整实时导航引擎；未来产品化若需要必须另立范围，不能偷偷补造。

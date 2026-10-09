# 1.0(8)Watch剩余距离与时间单位分行

2026-10-08。按用户要求将车道左侧剩余距离、右侧剩余时间改为数字在上、单位在下。保留NavigationUnits格式化与缺失值“—”，不足1km时m也放数字下方。车道仍居中，两侧等宽，数字使用系统caption粗体等宽数字、单位caption2；条带动态高度从36调整为40，保持Dynamic Type缩放。VoiceOver继续读完整剩余距离/时间。

用户追加iPhone首页内容往下移动：仅将首页搜索行顶部留白增加32pt，后续导入及折叠历史随之下移，保留导航标题位置和滚动能力。

仅调整Watch导航视图、iPhone首页顶部留白与版本号；iPhone胶囊搜索框、最近目的地、Smart Stack、Core/freshness和AMap不改。不为低影响布局新增测试，不重跑道路或历史回归；最小签名Release构建、安装及真机显示分别记录。

最终签名Release构建与1.0(8)版本/AMap资源/Key配置核查PASS，Core/Provider/freshness/Widget未变。Phone安装success，Watch安装success；真机视觉尚未验证。证据work/rc7。

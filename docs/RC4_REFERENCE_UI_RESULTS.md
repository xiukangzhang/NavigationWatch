# 1.0 (5) 参考图首页与Watch导航布局

2026-10-08。依据用户HEIC首页参考及编号Watch截图实现。此前1.0(4)已撤回，本轮从正式1.0(3)继续，build号使用5以避免混淆。

## iPhone

中性系统背景、白色圆角卡片、蓝色导入主按钮。首卡为高德分享导入，第二卡为原有搜索目的地；下方原有搜索结果/真实路线/导航保持。底部原生TabView只有首页与设置，没有添加参考图的Inbox/回收站或任务系统。外部导入URL切回首页，保留原有导入路径和隐私同意。系统字体、语义深浅色、安全区与键盘滚动保留。

## Watch标注对应

- 1（剩余距离）移到车道左侧，2（剩余时间）移到车道右侧。
- 4（车道）占中间50%宽度，两侧等宽，保持居中；更多车道仍可横向滚动，没有非空真实数据时不画假车道。
- 3（GPS文字）在可靠导航页面替换为右上角信号柱图标：绿色3柱为raw strong且定位quality good，橙色2柱为strong但quality weak或SDK smartPositioning，红色1柱为raw weak。当前SDK没有原生medium enum，橙色属于显示层中等定位质量，VoiceOver据实区分智能定位；不是伪造SDK回调。
- 未知、unavailable或source stale不能宣称强/弱；灰色状态图标与既有过期提示保留。freshness门槛、旧引导隐藏和时间戳语义未改，未新增恢复workaround。
- 转向与转向距离保持优先，道路/临时事件位于车道栏下方；Stop入口保留。

## 验证边界

最终限定签名Release构建PASS（release-build-final.log），产物1.0(5)、Key配置/高德资源/保护源码hash均PASS。初始Watch视图括号问题已修正后通过构建。双端安装及iPhone启动success（install-phone/install-watch/launch-phone.json）；正式两份工程UI源码一致（integrity.json）。用户显示确认单独记录。仅UI修改，不新增镜像实现式测试或重跑道路/事件/分享历史测试。protected-integrity证明确认Core/freshness/Provider、Watch同步和Smart Stack Widget未变。本轮仅Phone和Watch两份Swift展示代码及版本号；Smart Stack保留已验收的1.0(3)配色和布局。

真机显示效果仍需本次用户确认；不能由build声明全部长文本、全部字号或颜色强弱状态均已实际观察。

## 修改及证据

正式NavigationWatch-Phase5与Pods镜像同步：iOS/NavigationWatchPhoneApp.swift、Watch/NavigationWatchApp.swift、project.pbxproj及本页/状态/交接。证据work/rc4。原始HEIC仅转换临时PNG供查看，未修改原文件；真实Key不入文档或交付包。

# 1.0 (4) 首页与Watch布局调整

**REVERTED — 用户要求返回上一版，正式恢复1.0(3)。**

2026-10-08。用户请求首页名称居中、搜索区下移居中，以及Watch文字越界修正。

## 本轮修改

- iPhone首页使用原生居中inline导航标题；搜索框居中对齐、下移，搜索按钮位于中间，分享导入保留。仍用原生List，键盘、安全区、动态字号正常参与布局；有搜索结果时减小顶部留白。
- Watch按GeometryReader提供的安全区域宽度设置内容宽度，左右各留8pt，纵向滚动；等待/过期信息使用可换行的紧凑文字布局。
- 长道路名最多3行，事件可换行；距离数字必要时有限缩放；剩余距离和时间改为上下两行，不挤在同一行。移除车道容器150pt最小宽度，继续允许横向滚动。Stop按钮保留。
- Smart Stack小family中道路名可用2行，剩余距离单列，时长/ETA另列，保留上一版本深背景/白文字。锁屏/Island的现有信息路径不改。

## 最小验证

签名Release build PASS，版本1.0(4)，高德资源、私有Key配置及Launch Screen产物核查PASS。仅展示改动，无新增单元测试，不重跑历史导航/分享/事件测试。

protected-integrity.json确认Core、freshness、AMap Provider、双端WatchConnectivity源码与本轮基线一致。本轮只改PhoneHomeView、WatchNavigationContent/容器、Widget展示及build号，不增加Provider或workaround。

双端安装及iPhone启动success（install-phone/install-watch/launch-phone.json），实际布局反馈等待用户；不由编译成功宣称长文本、小屏或全部动态字号视觉PASS。

## 文件

正式NavigationWatch-Phase5与Pods镜像均同步：NavigationWatch/iOS/NavigationWatchPhoneApp.swift、NavigationWatch/Watch/NavigationWatchApp.swift、NavigationWatch/Widgets/NavigationLiveActivity.swift、NavigationWatch.xcodeproj/project.pbxproj。当前文档与状态/交接一并同步。证据目录work/rc3；不交付含私有Key的包。

## 回退记录

用户回复“返回上一版”，已恢复三份视图源码与project build3；不把未得到用户认可的1.0(4)布局标为视觉PASS。重新安装已有签名1.0(3)产物，原版分享导入、黑边和Smart Stack配色修复保留；结果见work/rc3/rollback.json及rollback-install/launch证据。

回退完成：两端安装success，iPhone启动success；三处源码与上一版暂存逐文件hash一致（rollback-integrity.json）。

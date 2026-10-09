# Apple Watch 模拟器最小联测

日期：2026-10-05。范围：本次只验证双端安装与启动、Mock 导航同步更新、停止同步，以及发现的 Watch 回调崩溃修复。真机结果另见 `DEVICE_TEST_RESULTS.md`。

- 环境：iPhone Air iOS 27.0 模拟器，配对 Apple Watch Series 12（42mm）watchOS 27.0 模拟器；`simctl list pairs` 显示 `active, connected`。
- 构建、安装、启动：iPhone 和 Watch Debug 模拟器构建成功；两端安装成功并启动。初始画面为 iPhone“开始模拟导航”、Watch“等待 iPhone 导航”。
- 发现并修复：Xcode 调试器捕获 Watch 端 `_dispatch_assert_queue_fail`，调用栈定位到 `WatchConnectivityClient.requestCurrentState` 的 `replyHandler`。WCSession 在后台队列执行回调，而闭包继承了主线程隔离。现将回调声明为 `@Sendable`，通过 `nonisolated` 方法提取数据，再切换到主线程更新状态。修复后 Watch Debug 构建、安装、启动成功，未重现该崩溃。
- 导航同步：点击 iPhone“开始模拟导航”后，Watch 显示前方 500 m、科苑南路、剩余 5.7 km／14 min；稍后显示右转、280 m、5.1 km／13 min，iPhone 序号从 0 更新到 68，随后到 95。说明本次前台 Mock 状态持续更新并显示在 Watch。
- 停止同步：点击 iPhone“停止导航”后，iPhone 回到未开始画面，Watch 回到“等待 iPhone 导航”。

本次未测：5 分钟稳定性、锁屏与后台、重连、乱序与旧会话探针、延迟分位数、耗电和真机。模拟器结果不代表真机 PASS。

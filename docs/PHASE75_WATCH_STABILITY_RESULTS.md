# Phase 7.5 — Watch 稳定性结果

日期：2026-10-07，北京时间。**PASS WITH KNOWN HISTORICAL ISSUE**。

Watch 历史间歇性退出：**NOT REPRODUCED AFTER TARGETED SOAK**；历史根因 UNKNOWN，不记为 FIXED。首轮发现的 iPhone crash 有独立明确根因并修复，不与 Watch 历史问题混为一谈。

## 真机 targeted soak

修复版实体 iPhone 正式高德导航从 **17:29:48 到 17:46:44，共 16 分 56 秒**；手机大部分时间后台运行，最终活跃快照 245、Watch 停止状态应用到 246。同一 navigation session：299AB129-2478-4F08-B775-EF407D4E211B。

| 恢复检查 | 用户观察 | Applied |
|---|---|---|
| 第 1 次，约 17:33，熄屏恢复、离开再进入，并打开通信诊断 | 正常，无退出 | 39 |
| 第 2 次，约 17:37，同样恢复操作 | 正常，无退出 | 125 |
| 第 3 次，约 17:42，同样恢复操作 | 正常，无退出 | 162 |
| 停止导航 | Watch 回到等待 iPhone 导航 | 日志 246 |

Watch 完整日志只有同一 runID C239A3DD-947F-4032-AF9B-36BC3D8FEB14、PID 903、一个 monitor_task_started（ID 81590D79-05E2-4118-B471-F2183D865AB9）。本 session 已应用序号未回退；重复及乱序消息被丢弃，没有逐条历史回放的证据。scene active/inactive/background/foreground、activation/reachability、receive/apply/pull 均有记录。自动熄屏后用户重新进入仍正常，不凭熄屏认定 crash。

并非全程无 stale：17:32:58→17:32:59、17:39:34→17:39:35、17:44:26 同秒 entered/recovered；均随最新状态恢复，无持续 stale 无法恢复。Watch 停止状态 246 已收到并应用，用户确认等待页。手机停止后已取得的日志无新活跃 snapshot。移动道路准确性及精确延迟分布不属于本次结论。

系统报告目录两端定向查询：Watch 无匹配报告；iPhone 修复后无新增 NavigationWatch IPS（保留首轮 17:18:53 报告）。中途 Mac→Watch tunnel 发生超时，后重试成功提取完整本地日志；这不是 App crash 证据。没有 debugger 长期附着或主动终止 Watch 来改变 soak 条件。

## 首轮失败与确定修复

首轮真实导航 17:12:23 开始，iPhone 17:17:50 进入后台，最后回调与快照 49 在 17:18:52；Watch 17:20:29 进入 stale。用户回到手机发现导航停止，重新开始后 Watch 17:24:33 恢复新会话。

取得系统报告 NavigationWatch-2026-10-07-171853.ips，captureTime 17:18:52.1008，PID 13141，incident CE7B0CAF-7956-403D-9809-9FC5E8DF3FDE。EXC_BREAKPOINT / SIGTRAP，utility NSOperationQueue 的 _dispatch_assert_queue_fail → Swift executor isolation check → closure #2 in WatchSyncCoordinator.publish(_:) → WCSession errorHandler。返回时 PID 13422 为新进程，不能以查询时存在新进程否定已发生崩溃。

仅修复 WatchSyncCoordinator 正常发送与诊断发送的 errorHandler 为 @Sendable，避免推断成 MainActor 回调后在 SDK 工作线程触发断言；Debug trace 继续在 Task @MainActor 中记录。未改 session/sequence、schema、过期阈值或后台定位设置。

修复后 **17:34:37 手机 background 状态实际触发 wc_message_error_7007（序号 58）并存活**，随后继续同一会话直到停止，定向真实错误路径回归 PASS。首轮 FAIL 不累计到新版 soak。

## 诊断改动

扩展现有 NavigationDebugLog，Debug Watch 有界本地 JSONL（当前与轮转各最多 1 MiB），记录时间、runID/PID、session/sequence、最近接收/应用序号、snapshot age、activation/reachability 和线程。新增 launch、scene 生命周期、monitor、stale entered/recovered；沿用 receive/apply/pull 等已有事件。不保存坐标、道路名或 Key，不接第三方云端 Crash SDK。

PreviousRunState 仅在 Debug 保存启动/active/background 时间、最近应用序号、session/scene、cleanExitMarker。没有 clean marker 只记 previous_run_may_have_terminated_unexpectedly，后台不伪造 clean exit。公开 scene API 无法保证收到系统进程回收通知；日志线索不能独立断言 crash。文件 I/O 失败不会抛出到导航流程。

## 最小检查

- 2 项 PreviousRunState 测试与 sequence/session、2 项 stale/latency 相关检查：5 项，0 失败。
- Watch Debug / Release 真机目标构建、Debug 安装启动与日志提取 PASS。
- 实际错误回调代码的 Swift 6 worker-thread harness PASS；使用 stub logger/trace，仅证明线程边界。
- 正式 Pod 修复版 Debug 双端构建及 iPhone 安装 PASS。
- 上述 16 分 56 秒真实导航、3 次恢复、手机真实 errorHandler 回调与停止同步 PASS。

证据位于当前任务工作区 work/phase75/；原始 IPS 留在本机工作区，不加入源码交付包。

Gate 已满足，允许用户限定的 Phase 8。不存在“证明绝对不会退出”的结论。

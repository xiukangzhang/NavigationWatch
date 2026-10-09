# Phase 2–4 配对真机测试计划

## 准备与最少操作

1. 在 Xcode 的 Settings → Accounts 登录可用的 Apple 开发账号，连接并解锁与 iPhone 配对的 Apple Watch，确认 Watch 出现在 watchOS 真机运行目标。打开 `NavigationWatch.xcodeproj`，选择自己的 Team，让 Xcode 为两个 Bundle ID 生成开发描述文件；按需改临时 Bundle ID，再安装 iPhone 与 Watch app。此处不需要高德 Key 或定位授权。后续可将工程移到允许 Git 的普通开发目录。
2. 两端打开 App；iPhone 点“开始模拟导航”，Watch 打开导航页。Mock 每秒产生一个快照，约 6 分钟后到达。若要做完整 5 分钟观察，请在开始后立即计时。
3. Debug 构建中，iPhone 的“通信诊断”和 Watch 顶部的诊断按钮显示连接、序号、丢弃与延迟。Xcode Console 可按 `dev.local.NavigationWatch` 或 `[CONNECTIVITY]`、`[SEND]`、`[RECEIVE]`、`[DROP]`、`[PULL]`、`[APPLY]` 筛选。不要将包含真实位置的日志长期保存在 Release。
4. 每个用例结束，将设备型号、系统、构建时间、观察时间、序号、计数与 Watch 诊断页的 median/P95/P99/max 抄入 `DEVICE_TEST_RESULTS.md`。可附截图；无数据填 `UNKNOWN / 尚未验证`，不填 0。

## 判定口径

- `receiveLatency`：Watch 收到消息时间减信封 `sentAt`；`applyLatency`：SwiftUI 页面收到状态变化后、下一次主 actor 调度时间减 iPhone 生成快照的 `timestamp`。后者是应用层 UI 更新回调，不是屏幕像素完成显示时间。
- 这两个单向延迟依赖两设备时钟同步；发现负值会忽略该样本，需记录时钟问题。Watch 页面显示 count、median、P95、P99、max。当前统计仅存内存，Watch App 重启后重新计数。
- `sequenceGaps` 是已应用序号之间的空缺，可能由 context 合并、SwiftUI 合并或传输丢失造成，不能直接当作真实丢包数。重复、乱序与旧会话计数来自明确的门控拒绝。
- `lastRecoveryDuration` 是 Watch 页面恢复或重连后，到首次接受快照的时间。它不等同于网络链路重建耗时。
- 状态超过 5 秒未更新时，Watch 隐藏转向与距离，显示“导航信息暂未更新”。阈值由 `WatchConnectivityClient(staleThreshold:)` 配置；本轮先使用 5 秒，真机结果后再调整。
- Mock 不申请后台定位权限。锁屏后 iOS 若挂起 Mock，记录 `EXPECTED LIMITATION BEFORE LOCATION BACKGROUND MODE`，不能判为后台导航已通过。

## 用例

| ID | 操作 | 必须观察和记录 | 通过条件 |
|---|---|---|---|
| 1 前台 5 分钟 | 两端前台，开始 Mock，观察至少 5 分钟 | 起止序号、received/applied、duplicate/out-of-order/oldSession、latency 分位、crash | 序号前进，无 UI 回退或 session 错乱；记录实际统计 |
| 2 iPhone 锁屏 | Watch 前台，iPhone 锁屏 30–60 秒后解锁 | Mock 是否继续、Watch reachable/stale/context/pull | 如 Mock 被挂起，准确记录预期限制；不得声称锁屏导航通过 |
| 3 Watch 熄屏恢复 | iPhone App 保持可用，Watch 熄屏 30 秒再抬腕进入 | 恢复前后序号、pull 时间、lastRecoveryDuration | 直接显示最新可得快照，不逐条回放 |
| 4 断连恢复 | Mock 运行中使连接不可用 30–60 秒，再恢复 | 断连时 stale 页面、context 时间、重连/拉取时间、恢复序号 | 旧转向被隐藏；恢复后跳到最新状态并继续递增 |
| 5 乱序 | 停止 Mock，在 iPhone Debug 诊断点“发送乱序” | Watch 日志 100/102/101/103、outOfOrder 计数、最终序号 | 101 被 `[DROP] out_of_order` 拒绝，最终 103 |
| 6 旧会话 | 停止 Mock，点“发送旧会话” | A100、B1、A101、oldSession 计数、最终 session | A101 被 `[DROP] old_session` 拒绝，保持 B1 |
| 7 Watch 退出重开 | iPhone Mock 保持运行；退出 Watch App，稍后重开 | activation、pull、恢复序号、恢复时间 | 不需重新启动 iPhone 导航；页面追到最新 |
| 8 iPhone 前后台 | Watch 前台，iPhone 前台→后台→前台→后台 | sessionID、序号速率、是否重复回调/crash | 不重复创建会话、无双倍快照或异常跳变 |
| 9 反复启动 | Start A→Stop A→Start B→Stop B→Start C | 各 UUID、序号从 0 重启、旧回调/Task、Watch 最终状态 | 无旧任务继续发送、无会话污染或明显泄漏 |

### 建议记录格式

每个用例写：开始/结束时间；操作步骤；实际屏幕与日志现象；sent/received/applied/duplicate/outOfOrder/oldSession/sequenceGaps；UI apply count/median/P95/P99/max；恢复时间；PASS/FAIL/PARTIAL/NOT TESTED；异常截图或日志位置。测试 2 的后台限制单独注明。

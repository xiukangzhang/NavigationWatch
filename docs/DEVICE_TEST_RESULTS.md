# Phase 2–4 配对真机测试结果

**历史基线，非当前设备状态。**2026-10-05 建立下方九项计划时实体 Watch 尚未被识别，故表内保留当时的 `NOT TESTED`。2026-10-06 实体 Series 10 已被识别、安装并完成少量独立场景；最新证据、一次高德同步失败、一次持续更新、WCError 7006 和最新修复版待复测事项，均以 `WATCH_DEVICE_SYNC_RESULTS.md` 与 `NEXT_SESSION_HANDOFF.md` 为准。Phase 5A/6 的实体 iPhone 结果分别见 `PHASE5_INTEGRATION_RESULTS.md`、`PHASE6_BACKGROUND_RESULTS.md`。九项计划仍未逐项完成。

记录创建：2026-10-05。已通过设备服务识别一部实体 iPhone，两端 App 已完成开发签名构建，且 iPhone App 已安装。用户确认 iPhone App 可手动打开，但尚未完成实际导航功能验证；仍未识别到 Apple Watch 真机。以下配对联测用例均未在设备上执行；不能把构建、安装或单端启动代替为功能 PASS。

## 设备与构建

- iPhone 型号：iPhone Air（iPhone18,4）；已通过有线连接识别，开发者模式开启，设备已解锁
- iOS：26.6（23G71），由设备服务读取
- Apple Watch 型号：Series 10（GPS），用户提供
- watchOS：26.6（23U67），用户提供
- App build / commit：Debug 真机签名构建成功；iPhone App 已安装且据用户反馈可手动打开；Watch App 安装状态 UNKNOWN / 尚未验证；当前工作区无 Git
- 真机功能测试日期：NOT TESTED
- 连接方式与场地：iPhone 有线连接；Watch 未在 Xcode 或 CoreDevice 列表出现

## 设备准备检查（不计入功能 PASS）

- `devicectl list devices`：实体 iPhone Air 处于 connected；未列出实体 Apple Watch。
- Xcode iPhone scheme 可选该实体 iPhone；Watch scheme 仅有通用 watchOS 目标，没有真机目标。
- 工程两个 Target 已选择 Personal Team。2026-10-05 真机 Debug 构建 `BUILD SUCCEEDED`，iPhone 与 Watch App 均完成 Apple Development 签名及描述文件嵌入。
- 首次 `devicectl device install app` 因免费开发账号的设备 App 数量上限失败。用户随后移除 FormulationLearning；重试返回 `App installed`，iPhone App 安装成功。
- 首次 `devicectl device process launch` 返回 `CoreDeviceError 4000` / `A required XPC connection to remoteService was unavailable`。在用户确认信任并恢复设备连接后重试，命令返回 `Launched application with dev.local.NavigationWatch bundle identifier`；命令行启动成功。
- 用户随后在 iPhone 主屏幕手动打开 NavigationWatch，反馈“可以”；这是用户观察的单端启动结果，未据此判定导航功能或 Watch 联测通过。
- `devicectl list devices`、`xctrace list devices` 和 Watch scheme 的 `xcodebuild -showdestinations` 均未列出实体 Apple Watch。手机配对状态由用户报告，开发工具识别状态仍为未识别。
- Xcode Device Hub 能列出实体 iPhone，但未列出 Watch；曾在“Pair Nearby Device”看到 `Waiting to pair` 并提示在目标设备开启 Developer Mode。
- 用户反馈 Watch 的“设置 → 隐私与安全性”中没有“开发者模式”选项。再次检查 Device Hub，仍为 `Waiting to pair`。
- 用户在 iPhone 系统 Watch 应用的“可用 App”中找到 NavigationWatch，但点“安装”返回 `This app could not be installed at this time`。安装未成功。
- 解码构建产物内 Watch App 的 development provisioning profile，`ProvisionedDevices` 仅含当前 iPhone 与 Mac 标识，未含 Apple Watch 标识；当前开发工具也未列出 Watch。两者与安装失败一致，但系统泛化错误尚不足以确认唯一根因。须先让 Xcode 识别并注册 Watch，再刷新 Watch 描述文件和安装。
- 用户重启 Apple Watch 后看到并确认了“信任此电脑”，但手表设置中仍未出现“开发者模式”。复查 Xcode Device Hub、Watch scheme 运行目标和 CoreDevice 设备列表，仍仅能看到实体 iPhone，未看到实体 Watch。当前 Watch App 最低系统版本为 watchOS 11。
- 用户提供手表为 Series 10（GPS）、watchOS 26.6（23U67），满足 watchOS 11 最低要求。iPhone 的开发者模式为 Enabled，设备服务状态为 connected，Developer Disk Image 服务 `isUsable: true`；后续命令行启动也成功。复查仍无实体 Watch，当前阻碍定位于手表开发设备发现/配对环节。
- 用户确认三端网络检查后仍无开发者模式及 Watch 运行目标。`xcdevice list`、`devicectl list devices`、Watch scheme 运行目标和 Device Hub 均未列出实体 Series 10；Device Hub 中出现的 Apple Watch Series 12 (42mm) 标注为 Simulator，不是用户真机。本机设备发现日志未提供可用的明确错误码。
- 经用户明确允许，在 Xcode Device Hub 中取消实体 iPhone 的 Mac 开发配对，随后选择 `Pair` 重新配对；CoreDevice 状态从 `available` 恢复为 `connected`。等待后复查 Watch scheme 和设备列表，仍只看到 Watch 模拟器，实体 Series 10 未出现。用户复查手表，确认没有新信任提示或开发者模式。
- 按用户提出的方法检查 Xcode 27 顶部运行目标：对实体 iPhone 项右键没有出现 `Show paired Apple Watches` 菜单；`Shift+Command+2` 打开的 Device Hub 中，iPhone 没有关联显示实体 Series 10，侧栏只列出实体 iPhone 与 Watch 模拟器。该方法在当前环境下未找到手表。
- 开发主机是 macOS 27.0.1、Xcode 27.0（27A266a）。Apple 的 Xcode 系统要求表列出 Xcode 27 支持 watchOS 10 及更新系统的真机调试，故 watchOS 26.6 在支持范围；Xcode 26.6 的受支持 macOS 范围止于 26.x，不能在当前 macOS 27 上作为官方支持的降级诊断。
- 2026-10-06 再次检查：`xcdevice` 仅列出实体 iPhone 与 Mac，Device Hub 仅列出实体 iPhone 和模拟 Watch；“Pair Nearby Device”保持 `Waiting to pair`。用户在该界面打开期间再次确认实体 Watch 的“开发者模式”仍未出现。设备发现原因仍未定位，真机用例状态不变。

## 测试记录

| Case | 状态 | 实际现象 | 计数 / 延迟 / 恢复时间 |
|---|---|---|---|
| 1 前台 5 分钟 | NOT TESTED | iPhone 据用户反馈可手动打开；Watch 真机未被开发工具识别 | UNKNOWN / 尚未验证 |
| 2 iPhone 锁屏 | NOT TESTED | iPhone 据用户反馈可手动打开；Watch 真机未被开发工具识别 | UNKNOWN / 尚未验证 |
| 3 Watch 熄屏恢复 | NOT TESTED | Watch 真机未被开发工具识别 | UNKNOWN / 尚未验证 |
| 4 断连恢复 | NOT TESTED | Watch 真机未被开发工具识别 | UNKNOWN / 尚未验证 |
| 5 乱序保护 | NOT TESTED | Debug 探针已实现，未通过真实 WCSession 发送 | UNKNOWN / 尚未验证 |
| 6 旧 Session | NOT TESTED | Debug 探针已实现，未通过真实 WCSession 发送 | UNKNOWN / 尚未验证 |
| 7 Watch 退出重开 | NOT TESTED | Watch App 安装失败，真机未被开发工具识别 | UNKNOWN / 尚未验证 |
| 8 iPhone 前后台 | NOT TESTED | 仅用户反馈可手动打开，前后台切换未测 | UNKNOWN / 尚未验证 |
| 9 反复启动 | NOT TESTED | 仅单元测试覆盖 Mock 重新开始 | UNKNOWN / 尚未验证 |

## 自动验证（不是设备结果）

- SwiftPM 核心单元测试：7/7 通过，2026-10-05。
- iPhone scheme 的 generic iOS Simulator 与 generic iOS device Debug 构建：BUILD SUCCEEDED，2026-10-05。未安装或运行。
- 独立 Watch scheme 的 generic watchOS Simulator Debug 构建：BUILD SUCCEEDED，2026-10-05。
- iPhone scheme 的 generic iOS Simulator Release 构建（含 Watch 目标）：BUILD SUCCEEDED，2026-10-05。
- iPhone scheme 的实体 iPhone Air Debug 构建（含 Watch App）：BUILD SUCCEEDED，2026-10-05；签名、iPhone App 安装及命令行启动均成功。UI 导航功能未验证。

## 性能基线

- Watch receive latency count/median/P95/P99/max：UNKNOWN / 尚未验证
- Watch UI apply latency count/median/P95/P99/max：UNKNOWN / 尚未验证
- 重连后首次应用最新快照耗时：UNKNOWN / 尚未验证
- 消息丢失：UNKNOWN / 尚未验证；当前 `sequenceGaps` 不能直接解释为丢包
- Crash / UI 回退 / Task 泄漏：UNKNOWN / 尚未验证

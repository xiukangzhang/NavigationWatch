# Phase 10.9 — AMap Navigation Manager Lifecycle A/B Validation

日期：2026-10-08（北京时间）。真机A/B各3个Session完成并停止。**Result A / SAME：No meaningful lifecycle-policy difference observed.**

## 控制条件与有效性

固定AMap11.2.100 / Foundation1.9.1，实体iPhone Air/iOS26.6，静止、前台，同终点与本地固定起点、完整路线hash相同；两组源码相同，只改变DEBUG编译选择。每组新进程起步，组三次Session在同一进程，固定75秒后Stop、3秒边界等待；切换不由stale触发，不是恢复机制。独立CL诊断请求关闭，无外部定位注入。
初次设备不可用已解决。随后首次沿用上午路线hash时，SDK算路成功但几何因起点小幅变化不同，被门控拦截；该样本没有进入导航、明确排除。改为本阶段的固定起点：第一次仅在导航开始前，用SDK路线首点建立设备私有缓存，并固定起点再算路建立本阶段完整hash；后续全部6个Session和B组共享同一本地基线。不进行stale后的重算路，不把首次bootstrap计为导航Session。精确坐标不导出。
A完整清理后释放应用strong manager再destroy：3/3返回true、weak旧manager均nil。B同样Stop/remove/delegate=nil，但不调用destroy：三次同一manager，旧实例保留。两组每次app active代表数1、Stop后0；累计delegate/DataRepresentative注册均1→2→3，非同时3个consumer。这是应用调用计数，不是不可观测的SDK内部注册表。

## 每Session原始结果

| 组/Session | 起止（北京时间） | raw位置/导航 | 最大gap位置/导航（秒） | 首/末源时间 | 首源年龄（秒） | Provider位置/导航 | Snapshot/yield/Core | 最终seq生成/消费 |
|---|---|---:|---:|---|---:|---:|---:|---:|
| A1 | 13:24:33–13:25:48 | 2/6 | 60.095/59.041 | 13:24:33/13:24:33 | 0.733 | 2/6 | 18/18/15 | 17/17 |
| A2 | 13:25:52–13:27:07 | 2/6 | 60.098/59.043 | 13:25:52/13:25:52 | 0.338 | 2/6 | 18/18/16 | 17/17 |
| A3 | 13:27:10–13:28:26 | 2/6 | 60.013/58.984 | 13:27:11/13:27:11 | 0.103 | 2/6 | 18/18/16 | 17/17 |
| B1 | 13:31:09–13:32:24 | 2/6 | 60.011/59.030 | 13:31:09/13:31:09 | 0.409 | 2/6 | 18/18/13 | 17/17 |
| B2 | 13:32:27–13:33:42 | 2/6 | 60.083/58.647 | 13:32:27/13:32:27 | 0.878 | 2/6 | 18/18/13 | 17/17 |
| B3 | 13:33:46–13:35:01 | 2/6 | 60.010/58.998 | 13:33:46/13:33:46 | 0.306 | 2/6 | 18/18/14 | 17/17 |

## Group A — Destroy

Session1/2/3均完成；各次销毁true并释放，manager身份与owner/session记录见summary-A.json。每个新Session首源时间不同，首源年龄均<5秒；Session内源时间0次推进，约60秒raw gap、stale，未观察自然fresh恢复。

## Group B — Retain

Session1/2/3均完成，同一manager。第二、第三次首源时间均更新，不等于前次末源；首源年龄均<5秒。每Session仍0次源推进、约60秒raw gap、stale，未观察自然fresh恢复。SDK在下一次算路前可保留route对象，这是预期retention差异；新算路及完整路线门控后，没有观察到旧route进入新导航。B2/B3在新Provider的idle注册/算路阶段曾收到与前Session末源时间相同的raw位置回调；这是实际的预导航差异。当时应用导航状态为idle、守卫不转发；startGPSNavi后的首源已更新，未观察到旧源覆盖新导航快照。不把预导航事件写成两组所有raw行为完全相同。

## Duplication 与旧状态检查

六Session均raw位置2/导航6，Provider分别2/6，无B组回调数量翻倍。生成/yield一致，Core bufferingNewest合法合并，最终生成/消费同session同sequence，App快照序号严格递增。未记录新导航开始后的旧owner原始定位/导航回调，或旧session navigating快照。Stop后全部辅助状态清空检查true。Start合并“全部字段为空”标志在A1/B2/B3为false，其余true；前序日志已有本次算路的traffic_raw/mapped回调。代码在算路前清空traffic，但允许算路时重新填充它，故合并nil标志不能单独证明污染。这是来自当前算路填充的解释与代码/日志相符，但SDK内部缓存来源仍未独立证明。
启动时部分导航回调已记录的少数字段相同、间隔<10ms，数量见comparison.json；指纹未涵盖SDK对象全部字段，不能认定完整事件重复，更不能由此断言重复consumer。没有B组重复注册或新增callback倍增证据。
本路线未实际覆盖所有非空lane/road数据；这些项保持NOT OBSERVED，不将App清空检查当成全部SDK缓存/道路场景验收。camera等在同路线可重复出现同一物理事件ID，本身不证明跨Session污染。

## Manager生命周期清理语义

既有正式stop在持有private let manager时调用destroy，Phase10.8返回false。本实验释放strong引用后3次destroy均true且旧weak为nil，验证了干净销毁流程可执行。该清理语义问题不能解释本轮stall：完整销毁与保留都复现相同回调/source行为。按无差异分支，不继续修改正式生命周期；所有实验更改仅在隔离DEBUG工程。

## Comparison / Conclusion

**Result A — No meaningful lifecycle-policy difference observed.** 本轮不支持manager lifecycle作为当前callback stall根因，也未确认Retained AMap singleton causes cross-session lifecycle contamination。仅限一次每策略3-Session、静止/前台/固定路线的观测，不排除所有道路/后台/压力条件。
Phase10.5 = **PARTIAL — AMap callback behavior pending vendor clarification**。真正blocker转为SDK静止location timestamp/约60秒回调机制的官方语义、推荐配置及后续澄清，设备连接不再是blocker。

## 最小验证与恢复

2个不同直接相关测试PASS（单调max gap、旧Provider owner拒绝）；初版generic签名构建及本轮固定起点实体目标A/B签名构建PASS；实际A/B安装、启动、3+3个Session和Stop都有原始日志。未跑全量业务或新SDK矩阵。
初次未带当前基线路线样本排除；清理失败路径增加DEBUG防重复Stop，避免实验A已释放manager后再次清理访问空引用。该防护不改变正式代码；新signed build通过，不声称故障路径真机验收。
最后已恢复验证前正常11.2.100应用，正式业务源码/SDK/Podfile未改。临时固定Session自动切换和路线门控不进入日常应用。

## 支持材料

AMAP_SUPPORT_REQUEST.md已加入本轮有效Result A，单一AMap-Support-Materials.zip更新并脱敏校验，**SUPPORT PACKAGE READY FOR SUBMISSION**，未提交。包含Phase10.7系统定位/Provider/Core证据、Phase10.8版本对照、Phase10.9全部有效日志和生命周期结果。不同阶段条件明确分开；本轮不声称同时观测SDK私有输入。材料为实测App片段，不声称独立最小App已经验证。
证据：work/phase109/phone-A.jsonl、phone-B.jsonl、summary-A/B.json、comparison.json、matched-source-manifest.json、build-A/B-fixed-route.log、tests.log、tests-owner.log、安装/启动/恢复JSON。完成后停止，不进入workaround、更多版本或第二Provider。

## 最终交接锁定

2026-10-08：结果、状态、下一会话入口及支持请求同步到两个正式工程。本轮结束，不继续实验；六Session停止已取证。正常版本restore-normal.json安装success、launch-restored-normal.json启动success，本轮此后没有开启新导航测试。支持包READY但未提交；下一会话先读NEXT_SESSION_HANDOFF.md，按新授权处理支持提交或官方反馈。

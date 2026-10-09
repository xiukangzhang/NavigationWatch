# 已知事项 — RC1

更新：2026-10-08。

| 事项 | 状态与边界 |
|---|---|
| AMap stationary callback behavior | Pending vendor clarification。静止约60s gap、源时间不推进，版本与生命周期比较无明显改变；支持包READY未提交。行驶是否失败须本次真实验收，未新增workaround。 |
| Historical Watch exit | Not currently reproducible / root cause unknown。历史定向测试未再现；RC1本次用户确认无崩溃，双端列表无新增；不替代长期测试。不能写root cause fixed。 |
| Real speed limit | Coverage not observed。只在真实非空数据时显示；属于覆盖缺口，不判产品缺陷。 |
| Non-empty road event | Coverage not observed。保持optional，无数据隐藏。 |
| Lane real-road coverage | 本次NOT OBSERVED；不专门绕路，既有Mapper/历史观察范围保留。 |
| Watch Stop入口缺失 | 用户本次报告，初始RC1 FAIL；已补齐并build/双端安装PASS，用户真机复验PASS，当前RESOLVED。 |
| RC1核心功能验收 | 本次用户确认核心十项正常，COMPLETE / Release Candidate；长期能耗、Stack点击独立记录、失败UI/全面accessibility保留覆盖边界。 |
| SDK合规与商用授权 | TODO，见APP_STORE_RISKS；自身manifest不能替代第三方manifest及完整隐私披露。 |

网络错误、权限拒绝、无搜索结果、路线超时等已有明确错误路径；所有真实失败UI尚未逐项观察，不宣称已全面验收。隐私同意目前每次启动显示，不新增持久账号/历史。

## RC2本批验证

Smart Stack低对比度与iPhone黑边：代码修正/Release build及本次真机显示均PASS，RESOLVED。用户高德路线/地点短链接解析PASS；App内目的地正确及重新算路用户已确认PASS。复制导入是当前交互，无系统分享菜单Extension，途经点/原始路线几何不导入。

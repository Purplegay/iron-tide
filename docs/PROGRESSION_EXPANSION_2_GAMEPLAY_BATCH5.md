# 第二批养成扩展：第五批步兵天赋

2026-11-17，本会话承接普通单位 T07/T09/T10/T11。实际仓库 `C:/Users/admin/IronTide`，共享脏工作区，不包含皮肤或四英雄新功能。普通内容累计已实现 9/24 张卡、9/16 项天赋，持续目标保持 active；电系旧套快照超时仍有下述验收缺口。

## 可玩规则

- 狙击手「转移阵位」：普通主攻击击杀真实敌步兵后移速 +15/20/25/30%，持续 2 秒，间隔 8 秒。不增加伤害或射程，额外伤害、召唤物、友军不触发。
- 动员兵「交替推进」：实际连续移动 2 秒后停下，下一次普通开火开始的新装填缩短 10/15/20/25%，间隔 10 秒。原地转向和伪速度不计移动；不改已经运行的装填，炉火护卫各自判断，临时召唤物不继承。
- 磁暴步兵「蓄电转储」：停火蓄电强化的主电击直接击杀后，保留其自然蓄电额外增伤的 20/30/40/50%，供 5 秒内下一次主电击使用。只留一份，与新蓄电取强、不相加；开火消耗，转储发不能再次转储，不复制 W 或分支增伤。
- 防空步兵「追身破片」：普通对空直击真实敌机后附着破片，0.8 秒后在目标当时位置引爆，半径 1.2 格，主目标和附近合法敌机各承受攻击力 25/35/45/55% 的防空伤害，间隔 4 秒。落地取消；先死亡则锁定死亡时空中位置；不伤地面、友军或可拦截火箭，不递归挂载。
- 四项接入真实战斗、四档配置、永久购买升级、状态显示、战斗快照和演示时间轴。本批没有新 W；保留既有 Auto W 策略，诱导跃扑仍由玩家决定突进时机。
- 修正 C13 诱导跃扑稀有度 `legendary` → 引擎规范 `legend`。原错误会使真实抽卡分组和兑换/升级无法消费；新增正常兑换、三次升级、W 装配、档案重读及新对局 W/Q 共存断言，并为普通扩展包所有卡增加可抽稀有度断言。此前 BATCH4 的直接解锁/手动装配不覆盖该缺口。

## 实现与验证

独立逻辑 `scripts/units/expansion_2_infantry.gd`；通过普通攻击来源、伤害和真实死亡事件判定，延时破片归属 `world.allied_state`。共享钩子仅涉及 progression_expansion 的 shot/damaged/killed、第二批 tick/reload/speed/status、expansion_cards.world_tick，以及 SHK 原生蓄电消耗表达式。英雄会话已经收到文件和事件边界。

输出根 `.validation/progression-expansion-2-gameplay-batch5-20261117/`。入口 `run.py <测试名>` 和 `run_gpu.py`，Godot 4.7.2、当前工作区资源、独立 APPDATA/LOCALAPPDATA 与 CodexIronTideValidation 用户目录。无服务、数据库或外部协议。专项覆盖新规则与边界；相关套件覆盖既有电系、普通养成、机器人、炉火、状态和 Auto W。无需 Unity/KFramework 验证。

| 测试 | 通过检查 |
| --- | ---: |
| progression_expansion_2_infantry_regression | 144 |
| tesla_reserve_regression | 231 |
| progression_expansion_2_regression | 553 |
| progression_expansion_regression | 909 |
| progression_expansion_2_soviet_regression | 120 |
| progression_expansion_2_drone_regression | 145 |
| unit_status_regression | 484 |
| furnace_contract_regression | 640 |
| auto_w_regression | 156 |
| progression_expansion_2_demo_regression | 392 |
| 合计 | 3774 |

上述最终结果零失败、无 SCRIPT ERROR；炉火套件保留 `card_upgrade_cost_cases.gd:35` 主动制造存档写入失败的预期警告，验证购买回滚，其余最终日志无 ERROR/WARNING。初次新专项中临时单位夹具缺少 left/owner，已补齐完整夹具后重跑，旧错误日志不算通过证据。

演示 GPU 在从未激活的私有 Windows 桌面执行，实际绘制检查 392 项通过，输入桌面前后均 Default，0 截图。不运行性能测试，视觉观感仍为 `pending_user_visual_confirmation`。

### 未关闭的关联缺口

原 `electric_cards_regression` 在 `BattleSaves.Snapshot.capture` 超时，无法给出原套通过结论。普通主电击、分支和四档伤害在诊断探针中先通过；逐字段打印的快照探针完整 171 项通过，但原字节快照副本仍卡住，因此诊断探针不替代原入口验收。

`pre-infantry-control` 为隔离脚本副本，仅去掉本批 shot/damaged/killed 三个 Infantry 钩子，仍然超时。该旧套冻结的 SHK 天赋只有 tesla_reserve，新的转储规则不启用；此对照不能证明所有可能因素，也不声称已找到根因。待继续查快照复现条件，未修改公共存档实现。临时探针只在本轮缓存；其中 electric_probe2 的插桩改变了缩进，92 项结果明确无效，不纳入验收。

收尾检查无本轮遗留 Godot 进程，无玩家档案修改；源摘要见 accepted-source-sha256.json，检查摘要见 accepted-summary.json。无打包、提交或推送。原会话继续四英雄，我方下一批为 V3/APOC 普通卡与天赋，并跟踪上述电系关联缺口。

后续证据：BATCH6 使用 Godot 直接 `--headless` 跑原 electric_cards_regression，169 项完整通过，公共快照与原测试未修改；见 [第六批记录](PROGRESSION_EXPANSION_2_GAMEPLAY_BATCH6.md)。该后续结果补齐当前原入口覆盖，不重写上述历史超时或推断其根因。

### T09 用户加强修订（2026-11-17）

交替推进改为实际连续移动 2 秒后停下，获得 5 秒强化；0～3 级每轮普通攻击的新装填分别缩短 10/15/20/25%，攻击力同时提高 10/15/20/25%。10 秒间隔从强化开始计时，开火不消耗效果，重新移动不刷新持续时间；已开始的装填不追溯修改。原地转向、被控制打断移动及召唤物不获得资格。攻击通过真实单位属性统一计算，与其他独立攻击增益正常叠加，重复刷新属性不重复累乘。

配置、状态倒计时、战斗光环及演示同步更新。演示覆盖停止前后、5 秒内连续射击与到期恢复；这是被动天赋，不新增 W 或改变自动施法。

本次独立输出根 `.validation/progression-expansion-2-advance-buff-20261117/`：步兵专项 182、普通池 608、炉火/契约关联 705、最终伤害上限 124、GPU 演示 484，共 2103 项通过、0 失败。专项包含四档多次实际命中、剩余 4 秒状态读档、属性叠加、到期、控制中断及易主清除。炉火套件保留主动制造写盘失败的预期回滚警告，其余最终日志无 ERROR/WARNING。GPU 位于从未激活的私有桌面，前后输入桌面均 Default；0 截图，实际视觉观感仍待用户确认。未打包、提交或推送，总目标继续推进。

### T10 用户永久储存修订（2026-11-17）

用户要求蓄电转储永久储存，取消原 5 秒有效期。合格主电击击杀后，按四档 20/30/40/50% 保留原蓄电额外增伤，直至下一次普通主电击开火消耗。仍只存一份，与新自然蓄电取强，转储发不能再次转储，易主清除；不改变原停火蓄电及 W 规则。状态显示储存量和“永久储存至下一发”，没有倒计时。演示将转储发延后至第 7 秒，展示超过原窗口仍保留，然后开火消耗；本项为被动天赋，无新增自动 W 行为。

本次输出 `.validation/progression-expansion-2-permanent-transfer-20261117/`：步兵专项 188、停火蓄电 231、苏联卡关联 131、GPU 演示 512，共 1062 项通过、0 失败。四档分别验证等待一小时、真实存读档后再等待一小时、下一发精确伤害/单次消耗及不可递归，并核对无时限状态、易主清除、原 W 分支排除和自然蓄电取强。最终日志无 ERROR/WARNING；后台 GPU 桌面未激活，输入桌面前后 Default，无本轮残留进程，0 截图。观感仍待用户确认。之前另记的旧电系套件超时未在本次重试，不宣称已解决。

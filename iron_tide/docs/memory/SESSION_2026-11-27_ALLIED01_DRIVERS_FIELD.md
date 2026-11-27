# 美国首关正式驱动与全图复核

Iron Tide 0.32，Godot 4.7.2，目标为战役菜单美国首关《时间流逝》。原图 ALL01UMD 的 SHA-256 为 `dee38769f2247a85908705486c175ef14a4cf90437899defe7c8b4c0d1c51fb0`，Steam AIMD 的 SHA-256 为 `5df41eaec00a78d0760ef5eecdf27d65ae1cd537309c7eac973318266986f89d`。

| 批次 | 触发器新增 | 累计 / 总数 | 剩余 | 地图 AI 新增 | 累计 / 总数 | 剩余 |
|---|---:|---:|---:|---:|---:|---:|
| 难度装甲和矿车生产 | 5 | 114/334 | 220 | 1 | 1/165 | 164 |
| 金门大桥损毁链 | 5 | 119/334 | 215 | 0 | 1/165 | 164 |

[触发器逐 ID 表](ALL01UMD_SCRIPT_RECHECK.tsv)的末列与正式驱动导出 ID 对应；其余字段保留原始事件、动作、标签和实现差异。[AI 逐 ID 表](ALL01UMD_GLOBAL_AI_RECHECK.tsv)关联本图开关和全局 AIMD 的原始行。任务脚本增援只统计到触发器。

## 正式战场

- 换场后按原图的两条 Create_Apocs、三条 Send_Armor 读取难度、队伍、动作 80 指定航点和两支装甲队的配置。三个 Send_Armor 延时分别为 90、100、30 游戏秒。Create_Stuff 和声音链的启用时点由现有关卡适配；界外 RM 仍从 41 入场，天启原脚本指向水格 78，当前由战场的可见目标选择接管，整队原路行进仍有差异。
- 矿车规则 0c8c2c3c-g 在开放生产的 Confederation 房使用本房 NAWEAP 和 NAREFN。普通、困难可执行，简单禁用。本房已有矿车数量上限条件为三辆，原队伍最多同时一队。队列按进度付费，生成的 HARV 获得本房和队伍标记，并按脚本 58,15 接令前往本房矿厂。初始地图无这套生产前置；正向测例通过正式建筑接口放置两座设施。当前敌方资金仍按共用账户结算，未验矿车自然采矿回款。
- 金门大桥由七条 BridgeHouse 建筑记录组成，六条位于区内，CASANF10 起始已毁，五段实际在场。标准高低桥覆层为零。连接段和中央桥段分别由原事件 61 检查，执行五条触发器的 63 号动作。BS 起点为空，BH 击中木甲每次扣 75 血。清除 CASANF09 后 CASANF11 从 500 降至 275；清除中央 CASANF04 后 CASANF11 被毁，CASANF12 和 CASANF13 各损失 300。区外 EP 不落点，读档保留断口、剩余血量和已消费事件。五个区内桥区航点实测装甲与舰艇的通行类别。没有可修复的普通桥面或小屋。
- 189 条原图建筑逐实例复核，区外 31 条，区内初始已毁 1 条，开局实际装配 157 栋，含 104 栋 Neutral。检查原图编号、房号、类型、位置、地基、最大和初始血量、载入美术、中立建筑的驻军位和占领配置、实体房色与雷达记忆。补齐 CALAB 和缺失的 NEWURBAN 民建筑美术，八座任务电厂按原版地基和耐久落地。三栋指定建筑继续用真实驻军命令、疏散检查，并覆盖核电站保留/重建及抵达通讯。
- 原图与项目逐格匹配 9,400 个地格、981 个坡格，包括原始 tile、子块、格高、坡向和地表类别。另查 Terrain 原表 230 条，34 条界外；195 个树木、路灯等地物逐一比对剧场贴图和落点，另 1 棵矿树由矿区系统生成。矿树未重复绘制。贴图扫描 715 格，回归列表为空，16 组共 89 格保留为视觉复核候选。未做逐物遮挡、树木碰撞和逐像素有头验收。

## 复验入口

从工程根目录执行 `python -B tools/audit_allied_ends.py .validation/allied-ends-20261126/source . .validation/allied01-drivers-round`。触发器使用 `tools/export_allied_script_slice.mjs`，AI 使用 `tools/export_allied_first_ai.mjs`，建筑和地物使用 `tools/export_allied_first_sites.mjs`。

用隔离用户目录运行 Godot 的 `--headless --path . res://tests/allied_first_playable.tscn --`，后接以下参数。读档使用与写档相同的隔离目录。各阶段允许夹具推进计时、摆位和指定伤害。现场入口是游戏战役菜单与 Battle。

| 范围 | 场景参数 |
|---|---|
| 普通主线和完整地物、驻军、AI | `--field-audit --new-sequence-mainline --retail-transition --global-ai --save-ai-queue --ai-contact` |
| 困难、简单和替代结局 | `--field-audit --new-sequence-mainline --global-ai`，另选 `--easy` 或 `--hard --ai-contact --carriers` |
| 核电站重建、桥毁连锁和实际导弹命中 | `--field-audit --new-sequence-mainline --retail-transition --dx-bridge-production --reactor-loss` |
| 独立进程恢复 | `--cold-ai-queue` 和 `--cold-bridge-chain` |
| 原表解释器 | `res://tests/allied_retail_script.tscn -- --first-only` |

本轮使用工作区直接出击，未制作发行包、未截图。验收数字与日志保存在 `.validation/allied01-drivers-round`。

| 最终后台运行 | 通过 | 日志 |
|---|---:|---|
| 普通、驻军、矿车、装甲交火 | 94/94 | nn.out |
| 困难、矿车、替代结局 | 84/84 | hh.out |
| 简单、矿车禁用 | 71/71 | ee.out |
| 核电站重建、断桥和无畏舰 | 78/78 | bb.out |
| 矿车在产独立进程冷读 | 6/6 | ncl.out |
| 桥链独立进程冷读 | 5/5 | bcl.out |
| 首关原表解释器 | 113/113 | rr.out |

上述各独立进程的标准错误均为空。逐项对照导出表中的 119 条记录，所有原始事件和动作字段与原图一致。建筑原始朝向字段保留在场景清单。区内 12 栋有非零朝向的防御建筑，其炮口起始画面尚待核验。

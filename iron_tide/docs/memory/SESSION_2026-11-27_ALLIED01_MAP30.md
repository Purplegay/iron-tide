# 美国首关 30 条任务与本图小队

Iron Tide 0.32。以 Steam 原图 ALL01UMD 的唯一 ID 统计，SHA-256 为 `dee38769f2247a85908705486c175ef14a4cf90437899defe7c8b4c0d1c51fb0`。

| 范围 | 上批累计 | 本批新增 | 当前累计 | 剩余 |
|---|---:|---:|---:|---:|
| [任务触发器](ALL01UMD_SCRIPT_RECHECK.tsv) | 144 | 30 | 174/334 | 160 |
| [本图 AI 小队](ALL01UMD_AI_RECHECK.tsv) | 23 | 16 | 39/91 | 52 |

地图定义 102 个 TeamType。逐条解析 334 个触发器的动作后，91 个有创建、招募或增援引用。另 11 个只在定义中出现，逐行保留。按唯一 TeamType 计数，同一队的多次出场、不同难度或同一 ScriptType 的复用均可追溯。此前的 23 个包含 16 个舰队、6 个装甲队与 1 个核电站工程师队。[历史全局 AIMD 核对](ALL01UMD_GLOBAL_AI_RECHECK.tsv)单独保留。

## 正式战场

| 新增触发器 | 玩家可见的行为 |
|---:|---|
| 8 | Start_CityP 及其余 7 条巡逻触发器共调动 12 支队伍。按原房号、TaskForce、难度与航点执行。动作 4 招募场上已有成员，动作 7 派出增援。三支增援只在普通和困难出现。 |
| 3 | Deploy_Start_GI、Deploy_Start_GGI、Deploy_GGI_Group2 各对原图五名步兵执行部署。 |
| 2 | Camera_GGI 使用原图航点与重装大兵语音。GGI_GuineaPig_Start 招募 V 附近的两辆原图 LTNK 前往 22，原有教学诱饵行为本批转入表驱动。上游镜头仍沿用简报交还控制的衔接。 |
| 1 | Damage_Reactor 在一游戏秒后按原动作 63 向 NA 航点施加伤害，回归核对原核电站实际扣血。 |
| 16 | 简单难度 GivePower1–8 与 TakePower1–8 依原局部变量和房号转属。八座 GAPOWR 原始实例均位于可玩边界外。转属使玩家电网、HUD 与建造用电获得或收回每座 200 电力。第八组失去 CAPOWR08 的所有权即收回，其余七组按各自原始损失变量。 |

八组巡逻共 12 个 TeamType，加上三支部署队和一支诱饵队，本图 AI 新增 16。出场、成员来源、房号、难度和初始部署按队核对。RD 坦克经正式移动系统实际行走超过 60 像素。两支队伍首段使用界外航点 205，战场取同连通区域内的边界落点，保留原始指令；到达落点后核验下一航点 681 或 27，该断点测试使用摆位。未逐队自然走完整圈或逐队验证交火。

入口为 `scripts/world/allied_first.gd` 与 `allied_first_opening.gd`。巡逻游标、队伍归属、界外电厂实例所有者及电力进入存档。已交还控制的旧存档沿用原有教学进度，避免重新招募玩家已操作的单位；新开局按本轮完整开场接线。穿越后简单难度仍响应电厂丢失，结算主线不重开供电目标。

## 复跑与证据

使用 `tools/export_allied_script_slice.mjs` 从原图索引重导任务，以 `node tools/export_allied_first_map_ai.mjs <原图索引> data/ra2/allied_script_slice.json docs/memory/ALL01UMD_AI_RECHECK.tsv` 生成地图 AI 表。已将正式片段中全部 174 个任务的事件与动作字段逐行同原图比较。

使用隔离 APPDATA 和 Godot 4.7.2 的 `--headless --path . res://tests/allied_first_playable.tscn --`，记录在 `.validation/allied01-map30/`。

| 场景 | 参数 | 通过 |
|---|---|---:|
| 普通、困难逐队，含界外航点 | `--map30`，另加 `--hard` | 各 65/65 |
| 简单难度奇数组、偶数组损失 | `--map30 --easy`，另加 `--even-loss` | 74/74、73/73 |
| 简单档独立进程冷读 | `--cold-map30` | 3/3 |
| 普通、简单主线结算及全图 | `--new-sequence-mainline --retail-transition --field-audit`，普通另加 `--late-dominator` | 85/85、82/82 |
| 简单难度穿越后失厂 | `--easy --new-sequence-mainline --past-power` | 49/49 |
| 原表解释器 | `res://tests/allied_retail_script.tscn -- --first-only` | 135/135 |

主线验收含工程师占领、加速任务计时和分支伤害夹具；截图 0 张。
# 《脑死》收尾：剩余任务和地图 AI

承接 [30 AI／10 任务](SESSION_2026-11-27_ALLIED_FINALE_BATCH_30AI_10_DRIVERS.md)。[本轮全部 14 个零售 ID](ALL07SMD_CLOSING_IDS.md)，已更新 [88 条任务表](ALL07SMD_SCRIPT_RECHECK.tsv) 和 [84 条地图 AI 表](ALL07SMD_AI_RECHECK.tsv)。Steam `mapsmd03.mix/ALL07SMD.MAP` 解包 `.validation/allied-ends-20261126/source/all07smd.map.map`，SHA-256 `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`；同目录 `audit/yr_all07smd_index.json` 提供原图字段与队伍依赖。双表全部原始字段与索引逐行核对。

| 类别 | 零售总数 | 本轮正式接入 | 累计正式接入 | 本轮逐项实测 | 未接或不适用 |
|---|---:|---:|---:|---|---|
| 任务 | 88 | 3 | 83 | 3 条在真实出击触发并检查结果，部分语义近似 | 4 条原图不可达或禁用、1 条零动作，均保留原状 |
| 本图 AI | 84 | 6 | 84 | 1 条专项看选队、实际出厂与占领；另外 5 条未逐队跑 | 0 未进正式调度；不是 84 条原版行为通过 |
| 全局 AIMD | 不继承 | 0 | 不适用 | `IgnoreGlobalAITriggers=yes` | 地图的 `AITriggerTypesEnable` 启用覆盖不当额外队伍计数 |

## 正式战场改动

- `export_allied_script_slice.mjs` → `allied_script_slice.json` 的 `yr_all07smd` → `allied_finale.gd::tick/apply` → `allied_finale_branches.gd::opening_defense/defense_orders`。`0960EE5C` 和 `04F32AFC` 在开场任务时钟启动后编组尤里主房与非洲守军；动作 4 就地招募、不凭空生成，动作 7 按原表两组 5 名、两组 4 名新兵进场。反应炉队按原队航点找有容量的己房生物反应炉，走现有进炉逻辑；无名额时守卫，未完整复刻原版统一集结与重试。非洲敌对动作接到本房工厂 AI 启用门，仍需关卡的南极 AI 开关；未扩充全局外交。`090AD17C` 以现有部队执行原巡逻 40→41→40→39，再按跳转重复；缺现有单位则局部编组，普通按组空缺不复制。七条开场与倒计时沿用上一轮。新增开场事件仅新开局启用，旧档不补派 18 人。
- `0955DD2C` 开场步兵空降和 `0EE0857C` 超武充能修改都默认禁用，查无启用引用；油井定时链虽有 `0F22154C → 078F61FC → 061BD4EC`，但中间条目三个难度均为 0，不激活；原已接入的发现油井支线不变。`09197EDC` 无动作和后继，不能把它当第三房败退逻辑补写。
- `export_allied_finale_ai.mjs` → `allied_finale_ai.json` → `allied_finale_ai.gd::tick`。最后六条为反光棱、工程师突袭、非洲反遥控坦克、非洲雷鸣飞碟、两房反磁暴线圈；保留难度、权重、门槛、编队和脚本数据。`game_data.gd` 为终关敌人开放现有神经突击车／尤里工程师目录许可，保留工厂和前置门槛；旧档工厂目录走已有刷新。`13525D8C` 从原动作 46 解码建筑类型，按原序找可见目标，工程师走真实占领命令，护卫在附近防卫；`allied_abilities.gd` 在实际到门后把建筑计入正确的尤里房。护卫集合、较长引路、按原版目标优先级与权重更新、其他五队的完整出厂/行军/交火未验，不称等价，也无新美术素材。

## 验证与复跑

- 临时输出后仅合并 `yr_all07smd`，避免覆盖盟军首关：`node tools/export_allied_script_slice.mjs .validation/allied-ends-20261126/audit <任务输出>`；`node tools/export_allied_finale_ai.mjs .validation/allied-ends-20261126/audit/yr_all07smd_index.json <AI 输出>`。
- Godot 4.7.2，隔离 APPDATA，隐藏无头。从战役菜单出击跑 `res://tests/allied_finale_playable.tscn`，主线 **91/91**、`-- --branches` **71/71**、`-- --enemy-ai` **43/43**、`-- --closing` **37/37**、独立进程 `-- --cold` **6/6**，全部 exit 0、最终 stderr 各 0 字节。日志 `.validation/finale-closing/`。
- 专项确认原图关闭项未启用、三条触发、动作 4 不复制、动作 7 共 18 人、至少一人真实进炉、巡逻接令及重复推进不重出；工程师 AI 用电厂前后判定、实际出厂，摆位到近处后实际走到门口并转属，未测从非洲跨图自然行军。冷读雷达档恢复 18 名新兵及三条闩锁，不重发守军或盟军基地车。未测试新 AI 队列断点、整关自然游玩、画面或发行包；未改玩家存档。

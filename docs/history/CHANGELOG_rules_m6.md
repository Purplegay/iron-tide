# CHANGELOG — 规则迁移 第 6 批：部署/卧倒（单点主技能）+ 矿车倒车入库/采矿优化

> 铁律：**RA2 是规则唯一事实源** · **判定几何 WYSIWYG** · **每步必须可验证**（无头自检 + 有头离屏截图 + 实测日志，跑完删临时工装）。
> 本轮口令：用户「**美国大兵不能卧倒了，修一下，并且改成单点能放主技能的模式。采矿车倒车入库，采矿优化一下**」。
> 定位：**不是新规则，而是两条已迁规则（A4 采矿 / C 命令集·部署）的回归修复 + 手感打磨**。

---

## 1. 目标与结论

**PASS**：无头探针 **36/36 断言**（卧倒 23 + 采矿 13）；有头离屏截图 4 张（合成对比图 1 张）；editor/battle 回归 `exit=0`。

一句话：**美国大兵能卧倒了（有姿态帧、有 D 键、有主技能单击），矿车会倒车入库、会认领矿点、不再绕矿厂打转。**

---

## 2. 事实源与回归根因

### 2.1 事实源（RA2）

```
rules.ini  [E1] Deployer=yes                       ; 可部署（卧倒）
art.ini    [GISequence] Deployed=292,1,1           ; 卧倒姿态首帧（8 朝向 → 292..299）
           [GISequence] Deploy=300,15,0 / Undeploy=276,2,0   ; 展开/收起动画（本轮未接）
rules.ini  [E1] DeploySound= / UndeploySound=      ; 语音（第 4 批已接）
skills.json ap_deploy（slot 0, radius 0, effect=deploy, cd=0.5）  ; 本作主技能
```

### 2.2 回归根因（「能部署但躺不下去」）

`deploy_frame` 从来不在事实源链上：它是**一次性脚本 `ra2pipe/p7_deploy.mjs` 直接写进 JSON** 的（`E1: 292 / atk×1.5 / def×1.15`）。
第 5 批全量重产 `ra2_allied.json`（`faction.mjs`）时这些字段没有对应提取逻辑 → **被丢掉**，于是：

- `_deploy_frame = -1` → `_draw()` 不切卧倒帧（人还是站着）；
- `data.deployer` 也不在 allied 数据里 → `can_deploy()` 判据缺一条。

叠加一个**从未接通的命令通道**：

```gdscript
# battle.gd（修复前）
for u in selected_units:
    if is_instance_valid(u) and u.has_method("deploy"):
        u.deploy()          # ← Unit 根本没有 deploy() 这个方法
if n == 0:
    Events.emit_message("当前单位无部署能力（红警2：D 部署基地车/步兵车）")
```

→ 按 D / 点命令栏「部署」**永远无反应**，还弹「无部署能力」。玩家感受就是「美国大兵不能卧倒」。

---

## 3. 实现

### 3.1 数据管线（把 deploy_frame 拉回事实源链）

| 文件 | 改动 |
|---|---|
| `ra2pipe/build.mjs` | 新增 `deployedFrameOf(seqName)`：读 `art.ini [<Image>Sequence]` 的 `Deployed=<start>,...` → 首帧；`technoEntity()` 落 `o.deploy_frame` |
| `ra2pipe/faction.mjs` | 单位 entry 落 `deployer`（rules.ini `Deployer=yes`）、`deploy_frame`、`deploy_attack_mult=1.5`、`deploy_defense_mult=1.15` |

产物：`data/ra2/units.json`（infantry 共 7 项带 `deploy_frame=E1:292`）、`data/ra2_allied.json`（E1 四项）。

### 3.2 引擎

| 文件 | 改动 |
|---|---|
| `scripts/units/unit.gd` | 新增 `can_deploy()` / `deploy()` / `set_deployed(want)` / `is_deployed()` / `_deploy_skill_index()`；`_toggle_deploy()` 改为薄封装走 `deploy()`；`stance_label()` 卧倒时返回「卧倒据守」；`order_move` 拒绝提示补「命令栏部署 D」 |
| `scripts/world/battle.gd` | `deploy_selected()` 改调 `u.deploy()`，先过 `can_deploy()` 过滤再计数（无可部署单位才提示） |
| `scripts/ui/hud.gd` | 新增 `_refresh_deploy_cmd()`（每帧随选中刷新）：命名栏按钮 `disabled` 状态 + tooltip「部署 (D) / 起身 (D)」+ 图标转**琥珀色** |

**「单点能放主技能」的落法**：`battle.deploy_selected()`、技能栏第 1 格、快捷键 D 三条输入全部汇到同一个 `unit.deploy()`
（`ap_deploy` 是 `radius=0 / target=self` 的**即时**技能，本来就没有「选技能 → 点地面」两步；D 键走的是姿态指令，**不吃技能冷却**，与技能按钮互不阻塞）。

### 3.3 采矿：倒车入库 + 优化

| 文件 | 改动 |
|---|---|
| `scripts/units/unit.gd` | 新状态字段 `_dock_pt/_dock_out/_dock_home/_dock_locked/_dock_phase/_dock_wait/_back_in` + 常量 `DOCK_STAGE_BACK=46 / DOCK_STOP=24 / DOCK_REVERSE_SPEED=0.55`；新函数 `_lock_dock()/_unlock_dock()/_dock_stage()/_dock_occupied()/_reverse_to()` |
| `scripts/units/unit.gd` | `_process_harvester()` 的 `to_base` 改**两段式**：阶段 0 驶向待泊位（`_go_to(_dock_stage(), 16)`），阶段 1 倒车入库（车头朝外）；`unloading` 保持倒车姿态，卸完 `_unlock_dock()` 前驶离场 |
| `scripts/world/resource_node.gd` | 新增矿点认领 API：`claim_by/claim_release/claim_held_by/claim_owner`（**弱引用**，车销毁自动失效） |
| `scripts/units/unit.gd` | `_ore_target()` 优先未认领矿点（全被认领则回退最近）；新增 `_claim_ore()/_claim_release()`；`order_move/order_repair` 时释放认领 |
| `scripts/units/unit.gd` | 新增 `_draw_reverse_tag(r)`：`_back_in` 时车尾绘两盏琥珀倒车灯 + 「倒车」小标（截图可直接验证） |

### 3.4 关键设计决策

| 决策 | 理由 |
|---|---|
| 泊位**进入 300px 后冻结**，不再每帧重算 | 旧 `_dock_point()` 依赖「矿车当前方位」→ 泊位跟着车转，矿车绕着矿厂画圈；冻结后是一条干净的直线入库 |
| 倒车入库用**位移朝泊位、车头朝外** | 尾舱对着矿厂＝红警2 观感；`hull_angle` 每帧钉在 `_dock_out` 上，不受避障推挤影响姿态 |
| 倒车速度 = 前进 ×0.55 | 观感区别明显，也给「待泊位等待」留出余地 |
| 卸矿口被占→在待泊位等，**超时 6s 强行入库** | 防两车互锁（也防驻留卡死）；等待期间 `_stuck_reset()` 避免触发脱困推挤 |
| 矿点**认领**而非硬性排队 | 两车自动分流到不同矿点（实测 4800 帧内始终不同）；弱引用，零清理负担 |
| D 键不占用技能冷却 | D 是姿态指令（红警2 可反复切换）；技能按钮仍有自己的 0.5s 冷却，两条路径互不阻塞 |
| 卧倒战斗加成随数据落盘（×1.5/×1.15） | 本作卡池设定（原版是换 `DeployedFire` 姿态开火，不改数值）；落数据后不会再被重产丢失 |
| 保留 `_dock_point()` | 泊位几何的历史入口，留给调试/其它调用方，不影响正式入库路径 |

---

## 4. 可验证性

### 4.1 无头自检 `_probe_m6.tscn`（36/36 PASS）

```
M6PROBE [ OK ] 生成美国大兵 E1
M6PROBE [ OK ] 事实源 art.ini [GISequence] Deployed=292 → _deploy_frame=292
M6PROBE [ OK ] rules.ini Deployer=yes → data.deployer=true
M6PROBE [ OK ] 卧倒战斗加成 deploy_attack_mult=1.5
M6PROBE [ OK ] 卧倒防御加成 deploy_defense_mult=1.15
M6PROBE [ OK ] can_deploy() = true（有卧倒姿态帧 + 主技能 deploy）
M6PROBE [ OK ] 卧倒姿态帧 292..299 已在图集里（rects=744）
M6PROBE [ OK ] 主技能栏含 deploy 技能（槽位 0）
M6PROBE [ OK ] 选中 1 个单位
M6PROBE [ OK ] 点「部署 (D)」→ 卧倒生效（battle.deploy_selected 通道）
M6PROBE [ OK ] HUD 姿态卡 = 「卧倒据守」
M6PROBE [ OK ] 命令栏「部署」按钮可用（disabled=False）
M6PROBE [ OK ] 命令栏按钮 tooltip 随状态变「起身 (D)」
M6PROBE [ OK ] 卧倒后移动指令被拒（has_move_order=false）
M6PROBE [ OK ] 卧倒后未走向目标点（距目标 200 px）
M6PROBE [ OK ] 卧倒后转向向量被压制（_steer_dir=0）
M6PROBE [ OK ] 再点一次 → 起身
M6PROBE [ OK ] 姿态卡回到常驻态（'待命'）
M6PROBE [ OK ] 技能栏主技能单击即施放 → 卧倒（单点，无瞄准态）
M6PROBE [ OK ] 主技能再单击 → 起身
M6PROBE [ OK ] set_deployed 幂等（第二次返回 false）
M6PROBE [ OK ] 起身后接受移动指令并位移 101.9 px
M6PROBE [ OK ] 灰熊坦克 can_deploy()=false（命令栏不误亮）
M6PROBE [ OK ] 生成矿石精炼厂 GAREFN（泊位宿主）
M6PROBE [ OK ] 找到采矿车 2 台（场景默认 2 台）
M6PROBE       矿车 超时空采矿车: states=['to_node','to_base','unloading'] back=901 revdot=-1.00 dock_frozen=True unload=True hull_out=True deposits=3 claim=True
M6PROBE       矿车 超时空采矿车: states=['to_node','to_base','unloading'] back=31 revdot=-0.99 dock_frozen=True unload=True hull_out=True deposits=1 claim=True
M6PROBE [ OK ] 倒车库位在倒车段内冻结不漂移（×2）
M6PROBE [ OK ] 状态机跑通 to_node/to_base/unloading（×2）
M6PROBE [ OK ] 2/2 台出现倒车段（_back_in 帧数 ≥ 8）
M6PROBE [ OK ] 2/2 台倒车证据成立（速度·车头 ≤ -0.6）
M6PROBE [ OK ] 2/2 台进入卸矿态
M6PROBE [ OK ] 2/2 台卸矿时车头朝外（尾部对着矿厂）
M6PROBE [ OK ] 2/2 台完成完整循环（unloading → to_node 已结算）
M6PROBE [ OK ] 资金增长：5040 → 7040（卸矿入库生效）
M6PROBE [ OK ] 矿点认领分流生效（两车同时持不同矿点样本 4800 帧）
M6PROBE FINAL fails=0
M6PROBE VERDICT PASS
```

> `revdot = -1.00 / -0.99` 就是「倒车」的硬证据：**速度方向与车头朝向相反**。

### 4.2 有头离屏截图

- `[A] 站立`：两张美国大兵站立，姿态卡「**待命**」，命令栏「部署 (D)」未点亮。
- `[B] 卧倒`：同一批大兵卧倒（沙袋掩体姿态帧 292..299），姿态卡「**卧倒据守**」，命令栏按钮**转琥珀色**，tooltip 变「起身 (D)」。
- `[C] 倒车入库`：矿车在待泊位倒着进泊位，车尾两盏琥珀倒车灯 +「**倒车**」小标。
- `[D] 卸矿`：矿车停在精炼厂卸矿口（车身保持倒车姿态），卸完自动前驶离场。
- 合成对比图：`RA2移植_大兵卧倒_采矿倒车_对比.png`（2×2）。

### 4.3 回归

`--editor --quit` → `exit=0`；`battle.tscn --quit-after 900` → `exit=0`。

---

## 5. 改动文件清单

**管线**：`ra2pipe/build.mjs`、`ra2pipe/faction.mjs`
**引擎**：`iron_tide/scripts/units/unit.gd`、`iron_tide/scripts/world/battle.gd`、`iron_tide/scripts/world/resource_node.gd`、`iron_tide/scripts/ui/hud.gd`
**数据（重产）**：`iron_tide/data/ra2/units.json`、`iron_tide/data/ra2_allied.json`、`iron_tide/data/ra2/*.json`（全量）
**文档**：本文件、`RA2_RULES_MIGRATION.md`、`RA2_PORT_ROADMAP.md`、`RA2移植_规则迁移台账.md`
**工装（已删）**：`_probe_m6.gd/.tscn`、`_shot_m6.gd/.tscn`、`_shot_m6_*.png`、`_m6_labels.txt`、`_m6_compose.ps1`、`_m6_*.txt`、`_shot_*.txt`

---

## 6. 已知边界 / 未做

- **展开动画**（`art.ini Deploy=300,15,0 / Undeploy=276,2,0`）未接：D 是**瞬间切换**姿态，没有「趴下/起身」的过渡帧序列。
- **矿车卸矿动画**（`HarvesterDumpRate` 之类）未接：卸矿仍是 4s 计时 + 无动画。
- **`HarvesterTooFarDistance=5` / `HarvestersPerRefinery=2`** 未接入寻路（本轮只做了同阵营泊位占用等待）；跨矿厂负载均衡未做。
- 多矿车时的**停靠微调**（两车都贴同一泊位时靠碰撞分离互相推挤）未做专门排队几何。
- 苏军阵营尚未运行时化（本轮仍只跑盟军）。

---

## 7. 下一步候选（不变）

EVA 播报（`eva.ini`，含「电力不足 / 电力恢复」，与第 5 批电力天然衔接）／老兵等级／苏军阵营运行时／命令集（巡逻·警戒·守卫·停止）／地形水 + `MovementZone` + `SpeedType`／建造耗时公式／超武／低电关雷达／命中音效（等动画 `start_sound` 数据）。

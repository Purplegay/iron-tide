# 《脑死》最后五条零售任务记录

续 [上批收尾](SESSION_2026-11-27_ALLIED_FINALE_CLOSING.md)。Steam `mapsmd03.mix/ALL07SMD.MAP`，解包地图 SHA-256 `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`。按 `.validation/allied-ends-20261126/audit/yr_all07smd_index.json` 比较 [88 条任务 TSV](ALL07SMD_SCRIPT_RECHECK.tsv) 的原始条件和动作。正式驱动表从 83→88，外部链接 0；不是 88 条自然可触发或逐动作复刻通过。地图 AI 未变，仍 84/84 接入选队，不继承全局 AIMD。

| 零售 ID | 本批正式接线 | 验证与玩家结果 |
|---|---|---|
| `0955DD2C` | 原图禁用且无启用源；动作 7 读原编组和航点，`allied_finale.gd::optional_gi_drop` → `american_paradrop.gd::launch_story_manifest` | 正常开局不派。夹具启用后单架运输机从 DB 到 DC，2 GGI、4 E1 全部走真实飞机、降落伞及落地。 |
| `0EE0857C` | 原图禁用且无启用源；动作 132 是 SuperWeaponSetRechargeTime，不是一次性预充。对主房心灵控制器、基因突变器应用 13500/9000 规则帧的周期，若尚未生成，则由任务状态保留并在动作 125 建筑实装时应用。 | 默认不变；夹具启用实测后生成的两建筑继承周期。没有另验实际到点发射或运行中的计时重新校准。 |
| `078F61FC` | `0F22154C` 的动作 53 现引用真实表内记录；保留 100 的计时字段及对下游的 53，但简单、普通、困难掩码全 0。 | 三难度均验证驱动拒绝启用，不模拟原图之外的难度。 |
| `061BD4EC` | 唯一直接启用源为上一条；两个动作 7 复用现有油井工程师适配，各走原队航点和原油井目标。 | 正常不发；夹具单独启用，两人真实入场接令，摆位后其中一人实际到门转属。既有发现油井支线不变。 |
| `09197EDC` | 虽原名 `Yuri3_Lose_ConYard`，但原图事件 57 参数 71 对应 CAOILD，驱动使用房内无油井条件；原图动作数 0。 | 正常开局第三房无油井时记为触发，不额外播放、生成、结束战斗或强改第三房状态。 |

## 验证

- `node tools/export_allied_script_slice.mjs .validation/allied-ends-20261126/audit .validation/finale-last-five/slice.json`；仅合并 `yr_all07smd`，不重写盟军首关任务定义。
- Godot 4.7.2，隐藏无头、隔离 APPDATA、真实菜单出击，`res://tests/allied_finale_playable.tscn`：`-- --last-five` 39/39、主线 91/91、`-- --closing` 37/37、`-- --branches` 71/71、`-- --enemy-ai` 43/43；均退出 0 且 stderr 为空。证据 `.validation/finale-last-five/`。
- 独立进程 `-- --cold` 两次均退出 0、断言 7/7（四关闭分支不补发、空动作保留、守军和基地车不重复）；stderr 有并行苏军《时空转移》`time_shift_late.gd` 查未导入的 `094A4E1C` 等连带编译日志，不能当干净冷读通过，未修改该关。无实测禁用动作执行途中冷读、自然整关、有头或发行包；未动玩家存档。

# 鲍里斯攻击油桶：步枪与米格分流

玩家反馈：鲍里斯攻击油箱是否一定要叫米格。修复范围是地图上的 `CAMISC01`（油桶堆）和 `CAMISC02`（单桶），不是 `CAOILD`（科技油井）或普通装饰。

## 零售依据

- 用 `ra2pipe/lib/yr_source.mjs::YrSource` 读取本机 Steam 尤复 `expandmd01.mix` 中 `rulesmd.ini`（SHA-256 `3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`）。`[BORIS]` 主武器 `AKM`、精英 `AKME`、副武器 `Flare`（米格指针、Airstrike 弹头）；`BORISWH` 对 concrete 为 1%，不是 0。两种桶都是 5 HP、concrete、`BaseNormal=no`、`CanC4=no`、`DeathWeapon=BarrelExplosion`。科技油井同样可爆炸但为不同的可占领设施，未列入例外。
- 读 `mapsmd03.mix` 的 `ALL01UMD.MAP`（SHA-256 `dee38769f2247a85908705486c175ef14a4cf90437899defe7c8b4c0d1c51fb0`）：`[Structures]` 原图桶堆在 `(51,67)`、单桶在 `(51,68)`，无相关规则覆盖。`SOV01UMD.MAP` 零售 `[Structures]` 也有 `(44,67)` 和 `(44,68)` 的同类桶。可用 `MixFile/MixEntry` 按地图名哈希读出，再用 `parseIni` 查节。以上是规则及原图核对，不等于在原版引擎亲测了右键、每发扣血或武器选择。

## 实际修改

- `soviet_specials.gd::boris_airstrike_target` 把两类油桶排除在可指示空袭的建筑外。`unit.gd` 的武器选择、开火冷却、指示动作和命令语音共用，`battle_cursor.gd` 与 `attack_cooldown_indicator.gd` 据此显示；在途米格转调、英雄副目标、步枪中继也使用同一判定。普通建筑的米格分支不变。
- 项目把正数小数伤害向下取整。普通 AKM 原始 65 × 1% = 0.65，会取整成 0；`building.gd::receive_hit` 仅对真实正伤害的 `YR_SOV_BORISWH` 命中这两种桶保底 1，不更改全局量化、其他武器、其他建筑或死亡武器。保底是修复本项目取整导致完全打不动的局部处理，未声称原版精确扣血相同。

## 验证及未验范围

Godot 4.7.2 隐藏无头、独立 APPDATA，`--headless --path . res://tests/allied_first_playable.tscn -- <参数>`，从真实战役菜单进入盟军首关。夹具把鲍里斯/灰熊放在原图油桶旁，普通/精英鲍里斯真实像素拾取、普通右键、物理推进发射和爆炸，不注入伤害。

- `--boris-barrel` 31/31：AKM 打桶堆、普通指针与语音选择、空袭冷却中没有派机、打爆并连锁；再把测试用敌方实验室放进真实战场，用单位命令下令，确认仍标记且派出两架米格。
- `--boris-barrel-elite` 29/29：AKME 直接打单桶并连锁。
- `--barrels` 25/25：灰熊仍可打桶堆，爆炸伤邻近坦克并连锁。最终三项 `.err` 均为空；证据 `.validation/boris-barrel-20261127/accept-*.{out,err}`。初跑遇并行工作树 `local_traffic.gd` 类型推断故障，其后该文件已由并行工作修正，本任务未改此文件。

未跑原版有头对照、苏军首关实际游玩、英雄副目标及在途转调专项、完整空袭命中/返航、独立冷读或发布包。未碰玩家存档，未打包、未提交。

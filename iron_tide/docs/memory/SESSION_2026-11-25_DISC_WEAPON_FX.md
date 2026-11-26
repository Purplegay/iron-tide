# 镭射幽浮武器特效

`DiskLaser` 使用瞬发弹，导入的武器数据缺少通用光束查找所需的 `ra2_weapon_id`。`scripts/units/unit.gd` 现在在 DISK 的真实开火分支绘制 0.24 秒红色激光，从碟身连到目标。`scripts/units/head_games_weapons.gd` 中的 `DiskDrain` 紫束从碟身连到建筑画面中心。

Godot 4.7.2 有头隔离战场从 `_fire_shot` 触发实装武器。坦克和完工电厂两例分别验证单束、起止点、掉血或断电，共 6 项通过。人工查看战场渲染截图确认红束与紫束。探针及截图保存在 `.validation/disc-fx/`。覆盖范围为地面坦克和电厂、单次开火。对空、矿厂、多碟自动索敌及导出包留待后续验证。

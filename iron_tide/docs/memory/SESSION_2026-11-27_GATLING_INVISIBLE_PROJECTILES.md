# 2026-11-27 固定盖特机炮飞行圆点

## 原因和实际改动

用户在战场截图中报告盖特炮子弹异常。`YAGGUN` 六把枪引用 `Invisiblelow`（对地）和 `Invisible4`（对空），但原项目弹道库没有这两项，1100 速度的 Projectile 因而飞行并进入通用小圆点绘制。零售 `rulesmd.ini` 对两者均定义 `Inviso=yes`、`Image=none`；`InvisibleLow` 有墙、峭壁及高差标志，`Invisible4` 为 `AA=yes / AG=no`。叠加 ALL02UMD 原图覆盖后，六把枪仍对应这两个 ID。取证文件 `.validation/allied-ends-20261126/source/rulesmd.ini` SHA-256 `3D341EF8A13A4B5AB24AF2EEF48AC94931AC2BB87D950FE3330A07E2D25672EF`，`.validation/three-trigger-ai-19/all02umd.map` SHA-256 `168ED42024991B6C2AF4DE0E5A667E9C2BF15767741EFE99DAC975721460B303`。

- `data/hollywood_combat.json` 和 `tools/hollywood_field_audit.mjs` 补两个 `YR_HOL_` 作用域弹道；`data/hollywood_yuri.json` 和 `tools/hollywood_yuri.mjs` 只切六把固定炮枪及默认枪。不改车载盖特、伤害数值、装填或音效配置。
- 继续使用现有 `Projectile` 的 Inviso 同帧结算，保留弹头、伤害归属、目标高度和命中 SHP；不要把速度设为零，否则 Building 会走通用瞬发光束。玩家看到方向炮口火光和目标处的 `PIFFPIFF`，不再看到空中或地面的飞行圆点。
- `building.gd` 用当前目标的空地类型和档位判断围墙阻挡，不沿用上一发武器。`battle_snapshot.gd` 对旧档内保存的武器定义按武器 ID 刷新弹道 ID，不覆盖冷却、伤害或归属。

## 验证

Godot 4.7.2，隔离 APPDATA，无头从战役指挥室出击 `res://tests/hollywood_campaign.tscn -- --unit-states`。三档对地、三档对空（实际升空基洛夫）逐项验证当帧扣血、正确的炮口及命中位置、未留下仍在飞行的弹体；两连发、空地互切围墙、旧数据同进程快照恢复均通过。完整场景 128 过 1 失败，唯一失败为坦克碉堡可见原版地台断言，未在本轮追查；退出 1，stderr 空。证据 `.validation/gatling-inviso-20261127/confirm.{out,err,exit}`。两导出器通过 `node --check`；数据修改由已提取零售 INI 与原图派生，未重跑整套素材导出。

未开窗口做像素对照、未做旧玩家存档冷进程回放（旧快照里已存在的在途圆点不迁移）、未打包。本轮只恢复 Inviso 语义及项目已有的墙体规则；峭壁/高差两个零售标志已保留在导出数据，但引擎没有在此处实现相应遮挡，不宣称已修复跨崖射击。

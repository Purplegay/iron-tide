# 鼠标变化图标接入

## 实际改动

- `scripts/ui/battle_cursor.gd`
  - 保留现有 `mouse.png` / `mouse.json` 的逐帧光标行为。
  - 新增加载 `assets/ra2/cursors/mouse_atlas.png` 与 `mouse_atlas.json`。
  - 将原版图集状态注册为运行时光标资源：Guard、NoMove、AttackRange、AttackNoRange、NoDeploy、NoSell、RepairMove、SideRepair、NoRepair、Power、Chrono、NoAction、Beacon 等。
  - 为 `patrol`、`reverse_attack`、`reverse_cover`、`reaper_split` 等已有指令模式建立语义别名。
  - 超级武器 `LightningStorm` / `Chronosphere` 接入 Power / Chrono 光标；巡逻、特殊倒车、掩护倒车和 Reaper 分裂不再落回通用移动/攻击图标。
  - 维修、出售、占据等已有状态继续沿用原先精确状态，并补齐原版禁用状态的图集资源注册。
- `tests/cursor_regression.gd`
  - 每个 RA2 / Iron Tide 测试场景启动时断言图集状态和特殊指令别名已加载且非空。
- `docs/memory/evidence/cursor-atlas-overview-20261126.png`
  - 保存原版鼠标图集总览截图，作为本轮资源整理证据。

## 已查实机制

- 当前战场光标由 `battle_cursor.gd` 统一解析，Windows 使用 `Input.set_custom_mouse_cursor`，其他平台使用屏幕 Sprite；资源加载统一放在该组件，不在 HUD 或 Battle 各入口重复切换。
- `mouse.json` 是既有精细状态来源；`mouse_atlas.json` 是原版大图集状态来源，两者可按语义键合并。

## 验证

- Godot 4.7.2：`--headless --path . --editor --quit` 通过，无脚本解析错误。
- 已运行过一次普通测试启动，工程保护正确拒绝非隔离 runner。
- 按测试要求构造外部复制工程和独立 user dir 时，`cursor_regression.tscn` 未在 120 秒内完成，进程已停止；没有拿到真实场景 `result.json`，因此不宣称完整实机回归通过。
- 原版图集截图已保存；本轮未完成带鼠标指针叠加的真实窗口截图。

## 未验证范围

- Windows 原生鼠标指针在真实窗口中的逐状态显示和热点。
- `patrol`、特殊倒车、掩护倒车、Reaper 分裂、Power、Chrono 在完整玩家操作链中的实际触发截图。
- 完整隔离 `cursor_regression` 的运行时结果。

# 2026-11-20 全模式自动保存

用户要求所有游戏模式自带自动保存，间隔由助手安排（原句末尾似未完）。

## 实现
- 新增 scripts/save/battle_autosave.gd，由 BattleScreen 统一装配。非远征战斗累计 60 秒有效现实时间自动保存；BattleClock.control_delta 消除倍速影响；world.paused/tree.paused/ended 不计时、不保存。
- BattleSaves 新增 auto 专用槽，沿用快照校验、临时写入、上一份 .bak 恢复。quick/slot1/2/3 不受覆盖；菜单可读取自动档，手动保存按钮禁用。
- 远征仍走 runtime 的 30 秒 checkpoint，统一入口遇到 Rules.active 直接退出，避免重复或遗漏增援状态。
- 战役/无尽/RA2/扩展遭遇战共用 BattleScreen，因此入口统一覆盖。单份 auto 为跨非远征模式共享最近自动档，不是每模式分别保留。

## 验证与限制
- 新 tests/battle_autosave_regression.gd/.tscn，在真实 battle.tscn + autoload 的隔离副本执行，RA2遭遇战/扩展遭遇战/m01战役 30/30通过、exit0、test2.log无SCRIPT ERROR/ERROR。
- 覆盖：装配、未到间隔、暂停/结束停计时、磁盘读取校验、模式、quick未改、恢复暂停、倍速无关、自动槽只读可加载。
- 隔离副本 C:/Users/admin/AppData/Local/Temp/IronTideAutosave-20261120-131107，唯一 custom_user_dir，不碰玩家存档。
- 初跑被已有两处类型推断错误阻塞：campaign.gd request_multi、uprising_threat_meter.gd point。仅测试副本改为 bool/Vector2 显式类型后复跑；主目录这两文件未改。首次带编译错误的PASS不算验收。
- 无尽/远征未单独端到端回归；未实等60秒（测试手动调用真实计时回调触发实际写盘），未冷启动新进程恢复、未人工UI截图、未打包提交。现有同步快照/校验可能在大场景保存瞬间卡顿，未作耗时验收。
- 生产改动仅 battle_autosave新增、battle_saves槽/label、battle_screen装配、save_panel提示与按钮；不要覆盖大量并行未提交修改。

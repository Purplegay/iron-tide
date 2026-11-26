# 苏军第七关：存档 2 的当前目标

2026-11-26。用户截图中顶栏停在「攻陷尤里的城堡／已解放基地 2 / 2」。只读取玩家 `slot2.itsave` 的副本，校验外层 SHA-256，确认关卡 `yr_head_games`、两翼解放标志均已写入、无城堡摧毁时间戳，敌方城堡 `CATRAN03` 仍存活（5000 HP）。不是存档丢阶段或任务卡死。

原图依据：`SOV07_TRIGGER_INDEX.md` 中的 `_Win (Bldgs KIA)`、`_Win (Free Soviets)`、`_Win (Free Allies)`、`_Win (Cheer)`、`_Win (Game Over)` 是胜利收尾链；当前移植用 `head_games.gd::objectives` 处理城堡被毁、释放仍受控的翼和胜利收尾。两处信标解放不独立结算，现有规则也允许先拆城堡。本次不改目标判定、战场实体、收尾时长或存档格式。

`scripts/ui/hud.gd::_refresh_timer()` 根据现有标志显示简报、摧毁心灵信标及解放进度、摧毁尤里的城堡、城堡已摧毁。不再把已完成的 2/2 常驻在当前目标旁。旧档可直接用这些既有字段。

Godot 4.7.2，隔离 APPDATA。`--headless res://tests/head_games.tscn` 从战役菜单出击，45 项通过；覆盖顶栏 0/2、1/2、2/2 后切换及胜利。`--headless res://tests/head_games.tscn -- --cold-objective` 把玩家存档 2 的副本放入隔离 `user://battles/slot2.itsave`，新进程按正常存档入口加载，7 项通过，检查暂停、两翼状态、目标切换、敌方城堡存活、摧毁及结算。均 exit 0、stderr 空。证据为本轮 Chatbox 沙箱内 `main.log` / `main.err` / `cold.log` / `cold.err` / `inspect.log`。主线用夹具推进简报并对建筑造成伤害；结算推进任务计时至阈值后（避开浮点边界），未验证自然进攻、图形顶栏排版或发行包。没有写玩家存档或替换正在运行的版本。

# 远征直接闪退修复

用户反馈肉鸽直接闪退。根因不是远征存档，而是本轮新增代码造成的全局脚本解析失败，主入口加载远征依赖链时即被阻断。

修复：
- `scripts/world/native_maps.gd` 将 `world.map_layout()==... and ResourceLoader.exists(...)` 拆成显式布尔赋值，避免 Godot 4.7.2 对无明确类型表达式的解析错误。
- `scripts/expedition/rules.gd` 将对 `Dictionary` 的 `has_any()` 调用改为 `Dictionary.has()` 的显式组合。

验证：
- `godot --headless --path iron_tide --editor --quit` 通过。
- 主入口 `scenes/main.tscn` 使用隔离用户目录启动并运行 8 秒，通过，无脚本错误。
- `tests/expedition_defense_regression.tscn` 未完成运行。该夹具强制要求用户目录路径包含 `CodexIronTideValidation`，当前 Godot 4.7.2 的 `--user-data-dir` 未满足其检查，夹具提前退出。直接用脚本运行则缺少场景自动加载的 `Expedition` 全局上下文，属于测试启动方式问题，不能作为游戏回归结论。

未验证范围：正式用户存档恢复、完整图形界面点击进入远征、发行包启动。

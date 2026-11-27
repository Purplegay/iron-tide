# 中立英雄制造所每方限建一座

- 用户按截图指名 `NEUTRALSTUDIO` 限建一个。`scripts/rules/hollywood_heroes.gd` 的建筑定义增加 `buildlimit: 1` 及中文介绍。`Battle.single_structure()` 优先读取建筑目录显式值，没有时沿用零售类型数据；复用原有生产、待放置、落地和 HUD 同源门禁。各方独立；排队、完工待放置和存活建筑占用名额，出售或摧毁释放。不清理存档里已经存在的重复建筑，也不限制场景脚本直接生成。
- Godot 4.7.2，隔离 APPDATA、隐藏无头场景 `res://tests/hollywood_heroes.tscn`：144/144，退出 0，stderr 空。扩展断言覆盖阻止重复排队、成品允许首次摆放、已建禁止生产和放置、敌方名额独立、快照恢复仍限建、实际出售后重建、夹具直接组织致死伤害后释放、工业工厂仍限建且普通兵营不受影响。最终日志 `%TEMP%/CodexIronTideValidation-Studio-20261126-194652/final.out.txt`。`git diff --check` 通过。
- 全阵营 parity 库因当前项目未启用测试要求的 `use_custom_user_dir`，按其保护条件退出 2，未执行。未做冷进程继续对局、有头目检、发布打包或玩家存档改写。保留 Battle 中并行改动。

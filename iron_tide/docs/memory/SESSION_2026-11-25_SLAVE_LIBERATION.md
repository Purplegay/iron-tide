# 奴隶矿工归击毁方

奴隶矿车 SMIN 和展开的矿场 YAREFN 在死亡时共用 `slave_mining.gd` 的 `release`。致命炮击传入 Projectile，以前只读 `side` 导致回退为中立。现在读取炮弹发射时的 `owner_side`，单位或建筑直接击杀时读取 `side`，无来源时仍为中立。

`tests/hollywood_unit_states.gd` 的原断言曾直接调用 `_die(liberator)`。现用真实 Projectile 的 setup 和爆炸路径击毁收起的矿车，确认快照恢复的五名矿工全部解除搭载并归盟军。Godot 4.7.2 无头运行 `res://tests/hollywood_campaign.tscn -- --unit-states`，109 项显示通过，标准错误为空。日志在 `%TEMP%/it-liberation-319d42fc/`。本次炮击实测覆盖车辆形态，展开形态核对了共用入口。
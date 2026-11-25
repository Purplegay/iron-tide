# 远征筹备记住英雄选择

scripts/expedition/screen.gd 在玩家选择时保存国家和该国英雄到 user://expedition_opening.cfg。首次读取时从现有远征的 country 和 hero 取默认值，恢复前按已解锁名单核对。主动选择「不携带英雄」同样保存。

Godot 4.7.2 隔离存档两次独立启动，第一次在下拉框选择苏俄炉火，第二次读取到苏俄和 E2。切换国家后返回苏俄仍选中炉火，改选空项后再次切换保持空项。

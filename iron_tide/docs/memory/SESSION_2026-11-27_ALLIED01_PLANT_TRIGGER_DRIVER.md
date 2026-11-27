# 盟军首关：逐厂毁坏与判负驱动扩展

承接 [驱动名单](ALL01UMD_DRIVER_INVENTORY.md) 与 `SESSION_2026-11-27_ALLIED01_TRIGGER_BRANCH_DRIVER.md`。零售 `ALL01UMD` 八座 PP*_Destroyed（各自事件 61）、`04EC206C`（简单难度启用），以及 Losing/Lost 的局部变量、启停动作。`tools/export_allied_script_slice.mjs` 保留原始行序并扩充 41 条，首关 13→54 条，终关不动。零售总计 334，尚有 280 不在这张通用表，不与全局 AI 混计。

`allied_first.gd` 以独立持久驱动状态处理逐厂变量和失败动作，不再直接拿数量跳到失败。命令 21 播报；切片之外的启停仅记录，不能当作外部任务已触发。保留当前供电仍可维持时不判负的门槛。通用驱动新增可选 row_gate（无参数的既有调用行为不变）。现按不同电厂物理毁坏数量约束 Losing 级次，补适配原驱动缺少的局部变量边沿/启停调度：已置位但被关掉的 Lost watcher 重启一次。不是对原版逐帧调度的完整复刻；PP 配对、自动显露及原附着对象链仍须接入。夺厂不计损失。

Godot 4.7.2 隐藏无头实际主菜单，隔离 APPDATA，`tests/allied_first_playable.tscn -- --power-loss`（另加 `--easy` / `--hard`）各 25/25；普通 `--save-plant-driver` 26/26，独立 `--cold-plant-driver` 3/3，均 exit0 stderr 空。普通/困难毁第 5 座才判负，简单毁第 7 座才判负；门槛前不败、存四厂损失后读取再毁第五座判负。测试用伤害与计时夹具，不是自然游玩。证据 `.validation/allied01-playable/plant-rearm-{normal,easy,hard}.{out,err}` 与 `plant-save-{write,cold}.{out,err}`。未改玩家档、未打包，未全量回归其他关。其余已知缺项仍在脚本核对表。

# ALL01UMD 驱动名单与首批正式接线

先编 [驱动名单](ALL01UMD_DRIVER_INVENTORY.md)，以零售索引按原格式扫描 334 条触发、437 条事件（19 种）、1158 条动作（52 种）；AI 165 全局开关独立计。原始逐条名单在 ALL01UMD_SCRIPT_RECHECK.tsv。通用驱动表只导出 9 条，不能等同全关；此前盟军首关任务主体是专用脚本。

`allied_first.gd` 在已确认胜利阶段启动 `allied_retail_script.gd`，只显式启用 `089ecdec` 和 `089ec79c`，按表内 3/10 秒执行动作 113 庆祝、动作 1 正式结束战斗。处理并确认后的状态原子写入既有 allied_state，阶段 5 的旧档无驱动状态仍走原倒计时。两条控制器判定、界外建造场、供电等未改，仍非通用驱动。未改变共享解释器或其他关卡的数据。当前每帧恢复小切片，未做性能验收。

Godot 4.7.2 隐藏无头，隔离已有 slot2 副本：`tests/allied_first_playable.tscn -- --reported-slot2 --carriers --late-dominator --save-victory-driver` 42/42；独立 `--cold-victory-driver` 4/4；均退出0、stderr空。日志 `.validation/allied01-playable/driver-{write,cold}.{out,err}`。使用夹具推进战役、造成胜利条件；庆祝后实际写 quick，独立恢复验证已执行标记、9 秒未结算、10 秒结算及总动作数2。没有修改玩家档或打包，未做有头和自然通关。

# 第 12 关检查点恢复与据点重叠

2026-11-23 从玩家远征文件复制检查点到隔离目录。旧档单位缺 excluded_from_army_selection，prepare_battle 返回「实体字段版本不匹配：unit」。scripts/expedition/run.gd 在恢复时仅为缺失此字段的单位补 false，继续完整验证。

原坐标为 (4721.75,4169)、(4592.5,4207.5)、(4592.5,4207.5)。scripts/expedition/objectives.gd 在生成和恢复 control 任务时按序保留先前点，若距离小于 480 则找最近的同连通区可走格满足间距。无合适格时保留原位。分数沿用原编号。

Godot 4.7.2 无头加载玩家检查点副本进入真实战场。1 号原位有 2 支可计分友军，2/3 号分开到 (4207.5,4152.5)、(4537.5,3712.5)。恢复为 [0,60,60]，调用一次任务 tick(1) 变为 [1.2,60,60]。expedition_control_regression 44 项全过。截图中的侧栏 height 在本次开始时已显式声明 float，当前场景加载成功。验证限于无头场景，未进行桌面视觉复验。原档未写入，证据在 %TEMP%/IT-point-1938/final.log 和 control.log。

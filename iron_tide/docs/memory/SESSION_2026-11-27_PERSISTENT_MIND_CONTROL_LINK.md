# 2026-11-27｜心控期间持续显示弧线

玩家截图反馈「被尤里变的线看不到」。前次 `SESSION_2026-11-26_YR_MIND_CONTROL_LINK.md` 按零售 `MindControlAttackLineFrames=20` 复刻命中短显、选中重显；如果双方均未选中，20 个规则帧后就不画线，但心控关系仍在。此次为方便读战场，显示时机有意不同于零售；房色、32 段抛物线、移动高光、端点偏移保留。

- `scripts/world/yuri_support.gd::visible_control_source` 去掉限时和选中门槛，双方可见就持续画。保持原有两端迷雾判定、乘员隐藏及来源有效性校验；信标和永久支配仪的查找逻辑不改。
- `scripts/core/yr_mind_control_link.gd` 仅负责弧线绘制；`scripts/units/allied_abilities.gd` 不再设置或推进闪线计时。已有快照中的 `mind_control_link_left` 不影响显示，解控时清掉旧字段。阵营转属、解控、伤害及声音逻辑不变。
- Godot 4.7.2 隐藏无头、隔离 `APPDATA/LOCALAPPDATA`：`--headless --path <工程> --quit-after 350 res://tests/yr_mind_control_link.tscn`。从苏军菜单真实出击《首脑游戏》，17/17 通过、exit 0、stderr 空。覆盖正式开火、敌方夺取原己方单位、超过旧时限不选中、暂停、旧计时归零、移动端点、多目标、建筑目标、迷雾、解控、控制者死亡、快照编解码。证据 `%TEMP%/IT-MindPersistent-20261127-121137/test.{out,err}.txt`。
- 同步更正 `tests/hollywood_unit_states.gd` 的旧断言，未另跑完整好莱坞套件。未开窗口核对截图像素，未冷启动读档或重新打包，也未修改玩家存档。

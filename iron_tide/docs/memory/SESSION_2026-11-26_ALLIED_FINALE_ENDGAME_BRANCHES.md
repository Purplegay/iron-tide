# 盟军终关最终反扑、敌组结算和海军/油井支线

依据零售 `ALL07SMD` 解包索引 `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`，承接 SCRIPT_RECHECK / PRIORITY_SCRIPTS / SLOT5_BOOMERS。`export_allied_script_slice.mjs` 加入后段相关 16 行与动作 4 队伍资料；`allied_retail_script.gd` 为动作 4 解析原始队伍、路点。`allied_finale_branches.gd` / `allied_finale.gd` / `allied_abilities.gd` / `building_crew.gd` 接具体执行。

- `0780A03C/0BA8052C` 及 `0901606C/0BA8312C`：按各自房遗失设施数量、关键建筑、超武与原触发延时接出售、现存部队出击、重发命令。建筑损失数用原图可玩预置数减剩余房产近似，重建/捕获等不等价；BuildingTypes 索引参考既有适配，300 按关卡 ConYard 用途接实际 YACNST，并非断言所有索引语义已逆向。军贸出售保留科技油井及不可出售目标。售出建筑逃生人员继承任务房归属。地面/海军路径接项目攻击移动，不宣称原版 Hunt AI 完整。
- `07CA72BC` 依原图 9、14 两个判定分别检查，不再靠切数组猜房号；现运行时无独立 French/Yuri3 House，Yuri3 的残局目标仍并入第二敌组，继续保留共有敌人、建筑清剿与存档 5 六艘潜艇，不宣称原引擎事件 9 已逐房复刻。`08CBA88C/08CBA40C` 不擅自把潜艇转给 French，只收尾工程师指令。庆祝目前接简报文字。
- `0462BE5C` 对应 GAYARD，`0B8152BC` 的 NAYARD 仅置变量。动作 4 以 TG 位置从现存 Yuri3 雷鸣潜艇找最近艇作为原图 Boomer 反击路线适配，保持房归属，不凭空造艇，未逐指令实现原版招募与 `46,131095`。`078F6E5C/078F692C→078F71EC` 普通/困难发现 AR/AS 后由 AQ/AT 派原图两名工程师，用真实移动占领，定位只针对指定油井、不给玩家开雾。油井实体转属已接，后续独立第三房建造经济未接。已进入清剿的旧档不追补海军/油井支线，避免存档 5 刚清完又多出敌人；其它旧档由 fired 锁存恢复触发。

Godot 4.7.2 无头、隔离 APPDATA、真实菜单 `tests/allied_finale_playable.tscn` 主线 55/55、`-- --branches` 40/40（阈值和船厂用夹具，油井工程师实际走到并完成转属，检查两房反扑和未提前胜利）、`-- --slot5-cleanup` 8/8（真实玩家副本，夹具清除潜艇后原胜利链）、`-- --cold` 5/5；均退出0 stderr 空，日志 `.validation/finale-branches/`。未自然试玩整关、未验证潜艇到港交火、分支任一点冷读、三难度及完整 AI；未改玩家原档或打包。
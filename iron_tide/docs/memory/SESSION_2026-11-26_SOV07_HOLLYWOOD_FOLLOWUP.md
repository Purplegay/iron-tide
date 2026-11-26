# 苏军第七关与好莱坞：触发器索引、TMP 核对与桥梁冷读

2026-11-26。零售原图 SHA-256：SOV07 `eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4`，ALL02UMD `168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303`。本轮没有修改战役玩法或地形资源，新增的是核对材料和隔离场景的存读档用例。

## 已完成及玩家能观察到的结果

- `SOV07_TRIGGER_INDEX.md` 按原图顺序列出 126 条触发 ID、房号、原开关、事件、动作及标签/格子引用；`HOLLYWOOD_TRIGGER_INDEX.md` 列出 253 条。两图同 ID 的 Events 和 Actions 均无缺行。这是原图静态索引，不是逐条实机行为通过。
- 用 `tools/audit_native_terrain.py` 对现有导入地图逐格查零售 TMP 子块类别与坡型：第七关 18,414 格、1,902 坡格、18 低桥片、1 座低桥、2 间维修小屋；好莱坞 18,972 格、1,286 坡格、100 高桥片、6 座高桥、11 间维修小屋。合计 37,386 格，对应 TMP 子块无缺失、类别和坡型 0 差异。零售图高度和实际视觉效果不能由这个类别扫描单独证明。
- `tools/check_native_terrain.py` 扫描战场实际加载的第七关 `terrain.png` 及好莱坞 `bridge_ground.png`，分别扫描 1,239 / 2,462 风险格；纹理重复特征 54 格 / 11 组与 48 格 / 14 组，位置见 `YR_TWO_MISSION_TERRAIN_REVIEW.md`。好莱坞南桥头保护区无回归。告警并非确认缺陷；尚未逐处图形窗口与零售同机位核对。
- `tests/hollywood_campaign.gd` 新增 `--write-broken-bridge`、`--cold-bridge-broken`、`--cold-bridge-repaired`：从正式战役菜单出击，损毁六座可玩高架桥的中段并写盘；独立进程读入，检查六个断面血量、两端小屋、车道缺口、桥面坦克无法跨断口；六名工程师各自受理维修、消耗、修复桥面与小屋，再写盘；第三个独立进程检查六座桥均能继续通行。原地图边界截断桥头保留一间小屋。三阶段分别 8、64、44 项，退出 0 且 stderr 空。
- `tests/head_games.gd` 新增相同三阶段低桥冷读；检查断面血量、地面断面、寻路断面、两端小屋及工程师维修消耗。三阶段 3、10、6 项，退出 0、stderr 空。场景主线回归第七关 42 项、好莱坞 89 项，好莱坞桥梁 59 项，均退出 0、stderr 空。第七关原有用例曾访问已释放单位并输出脚本错误，本轮仅给其断言筛选添加 `world.actor_alive()`，复跑已清除。

## 复跑入口与证据

Godot 4.7.2 console，隔离 `APPDATA`，顺序运行 `--headless res://tests/hollywood_campaign.tscn -- --write-broken-bridge`、`--cold-bridge-broken`、`--cold-bridge-repaired`，第七关同样参数换成 `res://tests/head_games.tscn`。每关独立 profile，不混用 `slot1/slot2`。日志在 `.validation/yr-two-mission-audit/`，分别有 `profile`、`s07-profile`。静态 TMP 对照所用剧场目录为 `%TEMP%/IronTide-S07-retail`、`%TEMP%/it-hollywood-retail` 和 `../.validation/{expedition-v2-20261117/map-source,bridge-art-20261113/source,high-bridge-20261118/source,yr-roster-9d7462e5/source}`；终端结果保存在 `tmp-audit.md` 和 `tmp-audit.err`。原图并非提交入库，后续如目录失效应重新从合法零售资源提取并核对哈希。

## 尚未验收

- 126 条第七关、253 条好莱坞的每条触发器尚未逐项对照实际实现和玩家结果；具体应逐条验证启用/停用关系、难度、打断、存读档。索引中的“待逐项运行复核”即此状态。74 条第七关 AI 条件是另一张表，不包含在 126 条中。
- 逐格坡面画质不是 TMP 类别一致或重复纹理扫描的同义词。需将 25 处告警组在实际战场同机位对照零售坡底、坡顶、邻接平地、路缘与车道线，覆盖未报警坡面、桥遮挡和车辆通行；不要宣称画质全部通过。
- 冷读测试以工程师交互命令并用夹具将工程师置于接近点、手动推进交互计时；桥上坦克用低层移动函数测试断口/修复通行。未验证玩家从远处下令的完整寻路、冷读后自然行车、桥下遮挡、六座桥全部损毁组合的视觉截图、三难度自然通关及发行包。

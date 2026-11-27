# 苏军第七关志愿军漏接与两关复查

## 苏军 07《首脑游戏》

零售 `%TEMP%/IronTide-S07-retail/sov07.map` 复核 SHA-256 `eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4`。`093B806C` 挂在 Einstein House 的三名 TERROR、两辆 DTRUCK；`093C666C` 发现后执行换房、揭开 26/24、语音与雷达、置局部标记 1/2；`093BB0FC` 以两旗标为门槛组织 `0BF4446C`/`093C182C` 并用动作 106 解锁两型科技至 5；原图覆盖 RequiredHouses=Player，前置 NAHAND/RADAR 与 NAWEAP/RADAR。后续音频 `093B91CC` / `093CAF3C` 沿用 5/10 规则秒。

- `scripts/world/head_games.gd` 按零售坐标预置中立志愿军，任一幸存者实际可见才换边，保留原实例和伤亡，揭示两处、报点、发集合命令。用中立侧近似原角色房，复现集合第一步，未复刻队伍脚本 20/49 后续指令。前置旧档缺预置标记时补放一次；已招募旧档沿用 head_volunteers，不重新生成并能启用生产。未用旧玩家档或独立进程验此分支。
- `scripts/autoload/game_data.gd` 仅本关两型志愿军产品使用任务解锁、零售苏军设施和雷达前置、玩家房而非遭遇战国家限制；普通关卡、遭遇战的对应条件不动。`tests/head_games.gd --volunteers` 从任务菜单出击，用夹具放侦察兵、消除单辆车（避免自爆连锁）及推进工时；验证初始五支单位、未发现禁止下单、发现后只接管幸存者、保留雷达门槛、正式队列扣费出厂，不重复接管。14/14，退出 0，stderr 空。未从指令甲板实际点击两卡、未验证自然到达/后续交火、有头或整关自然通关。
- 仍未逐项等价：十条混编 KIA 分支当前按组阶段和补招募近似，尚未穷举会合／装载／出击后的死亡和取消。各房地图 AI 共享敌方资金，队伍指令与动态权重非零售完整机制。旧审计中的“城堡倒下即结算”“没有 Hello”在当前运行代码已有对应，不列为全缺。

## 好莱坞与苏军首关复查

- 好莱坞主线 94/94（含设施迷雾、一次报告与中立不修），`--shop-repair` 13/13。静态重核 `Bridge1..4_Broke / Fixer_Team / Fixed`：分别有局部标记 9–12、启用后的延迟字段 60 和修复后复位；现行 `_tick` 仍使用 20 秒轮询、各小屋临时出工程师，不是原版四条独立链。未修改桥逻辑。
- 苏军首关 `--fleet-reinforcements` 11/11，另启动同隔离目录新进程 `--cold-fleet-reinforcements` 4/4；重验编队触发、船只补回及冷读不重发。原图全套开场海战导演、图外入场过程、实际抵达和连续损失的通知节奏仍未完整对齐，本轮未改首关。
- Godot 4.7.2，`--headless --path .` 搭配 `res://tests/{head_games,hollywood_campaign,time_shift}.tscn`，隔离 APPDATA；最终日志 `%TEMP%/IT-s07-recheck-78c4e2fdd6524c79a1a50bad0c18121a`：`s07final`、`hollymain`、`holly`、`s01`、`s01cold`，各 stderr 空。未改玩家档或打包。苏军第二关未纳入此次复查。

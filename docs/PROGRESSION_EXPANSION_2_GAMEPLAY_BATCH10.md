# 普通玩法第十批：深水耐压、尾流分叉

2026-11-18。本批实现 C14、T15，累计 **16/24 张普通卡、14/16 项普通天赋**，剩余 8 张卡、2 项天赋。T15 按设计稿现名「尾流分叉」实现，替代早期「深航整流」。不承接英雄或皮肤，不修改版本号，不打包、提交或推送。

## 玩法与边界

- **C14 深水耐压**：台风潜艇 SUB 稀有被动。停火 4 秒后获得最大生命 5/7/9/12% 护盾，持续 5 秒，从生成时开始共用 20 秒间隔。实际开火包括闪避发重置停火计时，但不清已有盾、不刷新剩余时间。护盾实际吸收来袭伤害，耗尽或到期消失；易主清除旧盾。原生浮潜、视野、射程和声呐权限不变。
- **T15 尾流分叉**：SUB 普通天赋 Lv.0～3。正常主鱼雷实际水中移动至少 2 格，直接命中合法敌水上或潜水目标后，从命中点生成一枚副鱼雷，选择半径 2/2.5/3/3.5 格内最近另一可见合法目标。伤害为主鱼雷攻击快照的 30/40/50/60%，沿用原生 SUBT、有限转向和弹头伤害/溅射。副弹不继续分叉、不记普通命中或触发其它追加。
- 航距仅累计鱼雷真实水中位移，不包含潜艇移动、陆上航段或重复读档位移。副目标的探测和反潜权限沿用 SUB 原规则，原主目标、岸上、空中、友方、不可见或装载目标不能成为副目标。分叉射程以命中点计算；目标移出范围或失效时按原生失去目标方式飞向最后已知点，不重新捕获。
- 正常直击被护盾吸收仍属于接触命中，可以分叉；原主目标命中前已死亡/消失则不能生成。发射后潜艇阵亡不抹掉主弹已保存的攻击快照。原主弹、在途副弹身份、已航距离、前一位置与已分叉标记随现有快照恢复。
- 两项均为被动，没有新 W 或 Auto W 策略。稀有度、兵种范围、普通池解锁/装配、天赋解锁/升级、永久保存、“新！”标记、四档演示和护盾状态已接入。

## 实现位置

- `scripts/units/expansion_2_submarine.gd`：停火护盾、主鱼雷快照、航距累计、合法副目标、一次分叉及失锁。
- `progression_expansion_2.gd`：计时、护盾吸收、易主清理、状态和绘制；`progression_expansion.gd`：普通发射快照与盾前真实接触回调。
- `unit.gd`：实际开火重置停火计时；`projectile.gd`：仅带本天赋标记的弹执行航距/失锁处理，主弹结算结束后处理分叉。普通未标记弹不增加航距扫描。
- `data/progression_expansion_2.json`、`ui/expansion_2_demo.gd`、`ui/progression_icon.gd`：等级、范围、演示和图标。

## 验证

源码 `C:/Users/admin/IronTide`，共享分支 `codex/ra2-independent`。隔离 APPDATA/LOCALAPPDATA，不连接服务、数据库或协议。Godot 4.7.2 直接 headless；GPU 仅在从未激活的私有桌面绘制，0 截图。入口为 `.validation/progression-expansion-2-gameplay-batch10-20261118/run.py <suite>` 和 `run_gpu.py`，Python 使用 `C:/Users/admin/AppData/Local/Programs/Python/Python312/python.exe`。

| 套件 | 检查数 | 结果 |
| --- | ---: | --- |
| progression_expansion_2_submarine_regression | 140 | 通过 |
| soviet_naval_regression | 112 | 通过 |
| progression_expansion_2_naval_fire_regression | 155 | 通过 |
| progression_expansion_2_regression | 750 | 通过 |
| progression_new_regression | 56 | 通过 |
| final_damage_limit_regression | 124 | 通过 |
| progression_expansion_2_demo_regression，隔离 GPU | 720 | 通过 |
| 合计 | **2057** | **0 失败** |

专项包括四档护盾金额/期限/冷却、真实伤害吸收、后续开火不续盾、未命中重置停火、原生浮潜不变、护盾部分消耗读档、四档真实鱼雷分叉和范围内外边界、命中点起算、最近目标、原生溅射、一次性及禁止递归、近距和陆上航段排除、潜艇本体位移排除、声呐和真实迷雾、原目标死亡、原艇移除、盾前接触、原弹与副弹在途读档、重复航距处理不多计以及天赋真实购买升级/磁盘恢复。

原生海军回归初次 110 项断言通过，但冻结场景导致 CollisionObject2D 按默认禁用模式退出物理空间，真实维修入口 `body_test_motion` 报 `body->get_space() is null`，该次不作为干净验收。仅修正测试夹具：在维修查询前让隔离场景碰撞体保持注册，同时继续冻结逻辑回调，并新增两种模式的物理空间有效断言。最终 112 项通过，原维修路径断言保留，无生产逻辑改动。

最终所有套件日志无 SCRIPT ERROR、ERROR 或 WARNING；GPU 返回 0、`activated:false`、输入桌面前后为 Default。结束时无 Godot 验证进程残留。摘要、源码 SHA256、原始结果及日志在本轮缓存根；中间失败不计入最终通过。

视觉观感为 `pending_user_visual_confirmation`，未声称整局平衡或性能验收。此前旧 `electric_cards_regression` 间歇超时缺口继续保留。本轮目标保持 active，后续仍须完成其余 8 卡、2 天赋及总体验收。

# 《脑死》：尤里超武就绪却不发射

截图显示突变器已就绪、控制器剩 1:50。原因是终关正式驱动只装配建筑、充能和广播，未从本图 AI 调用 `Building.fire_superweapon()`，不是玩家漏做任务。未读取或修改玩家档，也未关闭游戏。

## 原图与修改

Steam `mapsmd03.mix/ALL07SMD.MAP`，现有提取文件复核 SHA-256 `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`。`[YuriCountry] IQ=5`，零售 `rulesmd.ini [IQ] SuperWeapons=4` 注释明确电脑自动发射。原图 `[GeneticConverterSpecial] RechargeTime=10` 覆盖全局 5 分钟；`0460BDBC / Build_Yuri_SW` 生成两台并通过动作 132 为控制器设置 13500 帧（15 分钟）。`0901213C / Detect_PD` 与 `0901648C / Detect_GM` 是探测语音，不是使用超武；默认关闭的 `0EE0857C / Set_Charge` 仍未开启。零售规则中 `[YAGNTC]`、`[YAPPET]` 与其超武均需电，导出建筑原为 `powered=false`。

- `allied_finale.gd` 仅为本关尤里主房的两个发射设施补适用规则，不改全局数据；新生成和旧存档首帧均适用，保留已充秒数与可达动作设置。只在开场结束、进入南极阶段、未终局的正式战役循环启用发射。
- `allied_finale_ai.gd` 用现有共用释放、冷却、警报和实际效果路径。供电、就绪、敌方视野为门槛；当前策略选择首个敌方可见有效步兵给突变器，控制器优先可控地面单位，否则打可见建筑。精确零售择点、聚团评分与命中效果未反编译或对照；这是移植择敌策略，仍使用现有武器效果及战役合并的敌方视野与电网。未新增或重烘建筑、动画素材。
- 本轮 0 条新增任务触发器（累计 88/88 含原图关闭及空动作），0 条新增地图 AI 条件（累计 84/84）。自动释放是房 AI 规则，不充作地图 AI 条目；本轮未重跑两套全量逐 ID 矩阵。

## 验证

Godot 4.7.2 隐藏无头，从真实出击菜单装配，使用隔离 APPDATA，`--campaign-test-no-autosave`。运行 `--headless --path . res://tests/allied_finale_playable.tscn -- --campaign-test-no-autosave --superweapons`（55/55），相同隔离目录另进程 `--cold-superweapons`（4/4），`--final-return`（105/105）；全部退出 0、stderr 空。前者从正常建筑充能和战役入口验证供电、视野与有效目标门槛，实际夺取坦克、把步兵变为狂兽人、发送警报并清空对应武器充能。旧档夹具实际序列化后冷读，旧 300 秒周期改为 600 并保留已充 300 秒。结算回归覆盖清剿、盟军片尾及回菜单。

证据 `.validation/finale-superweapons-20261127/`。无头受控推进，不是从开局实等 10/15 分钟的自然对局；未实机复现截图存档的兵力/视野，未有头、未打包。旧游戏进程须重新加载新版后继续原档。

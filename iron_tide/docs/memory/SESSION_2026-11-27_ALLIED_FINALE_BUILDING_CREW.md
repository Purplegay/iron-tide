# 《脑死》：尤里建筑逃生兵种与房色回归

承接 [反应炉静态诊断](SESSION_2026-11-27_ALLIED_FINALE_REACTOR_CREW_DIAGNOSIS.md)。零售 `ALL07SMD`（SHA `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`）的正式设施表、第三房建造表及超武任务生成入口合计 12 类尤里建筑；`data/ra2/death.json` 提供 `Crewed` 与 `ThirdCrew=INIT`。

- 生产改动：`scripts/buildings/building_crew.gd::faction` 优先识别仍属敌方、实际房标签为 `YuriCountry/Yuri2/Yuri3` 的建筑，同时用于人员数量和兵种选择。玩家接管后即使保留旧房标签也按玩家国家；被尤里夺回时按有效尤里标签。当前工作树已有的房色继承沿用。没有改变建筑自身归属、伤害、概率、建造场工程师分支或通用敌方默认国家。
- 预置界内 106 座尤里建筑共十类：`NACLON` 1、`NAPSIS` 1、`YABRCK` 2、`YACNST` 2、`YAGRND` 1、`YAPOWR` 35、`YATECH` 2、`YAWEAP` 2 均允许逃生；`YAGGUN` 35、`YAPSYT` 25 不允许。地图触发生成的 `YAGNTC`、`YAPPET` 也允许逃生。第三房建造表不增加新类别。任务触发器、地图 AI 均未新增或改动。
- Godot 4.7.2，隐藏无头并隔离 APPDATA/LOCALAPPDATA，`--headless --path . res://tests/allied_finale_playable.tscn -- --campaign-test-no-autosave --building-crew`，86/86、exit 0、stderr 0 字节。日志 `.validation/finale-reactor-crew-20261127/crew.out` 与 `crew.err`。真实菜单原版出击，经雷达、超时空与超武生成；对已生成的 12 类逐类检查同类所有实例的房和逃生门槛，固定随机种子加直接高伤调用 `receive_hit` 逐类实际打爆代表设施，校验逃生者单位 ID、敌方、房标签及 `_col`。十类各生成 INIT，其中建造场另生成工程师；两类塔无逃生人员。另验第二房反应炉受击、调用共享转属入口后按玩家操作出售并产己方 E1、以第三房标签及转属夹具模拟尤里夺回并受击产 INIT。
- 未自然通关，未逐座摧毁、未走本次工程师到门流程或专项冷读、未实机视觉检查或打包。该修复作用于后续逃生事件，不转换存档中已经生成的单位，未改用户存档。

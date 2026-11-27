# 三战役零售地图复核：恶魔岛围栏与好莱坞覆盖层

沿用 Steam mapsmd03.mix 零售提取件，三个 SHA 与上轮 `SESSION_2026-11-26_THREE_CAMPAIGN_TRIGGER_FOLLOWUP.md` 相同。新增 `tools/audit_three_campaign_maps.py` 独立解包零售 IsoMapPack5、OverlayPack/OverlayDataPack，并逐格读取剧场 TMP，和正式 `data/maps` 对比。命令：`python tools/audit_three_campaign_maps.py "$env:TEMP/IronTide-S01-retail" "$env:TEMP/it-hollywood-retail" "$env:TEMP/IronTide-S07-retail" .validation/three-map-retail/audit.json`（本机用 `%LOCALAPPDATA%/Programs/Python/Python312/python.exe`，已有 lzokay/Pillow）。退出 0。

| 图 | 格数 / 坡格 | 桥、维修点、矿与墙 |
|---|---:|---|
| SOV01UMD | 14,124 / 1,331 | 0 标准桥片不能解释为无桥；7 个金门桥 CASANF 任务建筑（原图 Neutral、其中 CASANF10 开局 0 耐久），146 矿格；全导出 117 段 CAFNCP + 20 段 GAWALL 与任务覆层数据逐格相同。开场边界 `[4,29,52,60]` 与零售一致；`[4,5,54,132]` 是装载跨时代地形的联合裁剪，不是开场范围。中间时代和最终区域的打开时序仍为适配。|
| ALL02UMD | 18,972 / 1,286 | 100 高桥片、六座高桥、11 个界内/12 个零售维修小屋（保留原图剪掉的一端），558 矿格；188 个墙栏覆盖层原来未装配为可互动对象。|
| SOV07UMD | 18,414 / 1,902 | 18 低桥片、一座低桥、两间小屋，1,034 矿格；71 黑栏+36 白栏+20 盟军墙与现有覆层逐格相同。|

三图合计 51,510 格、4,519 坡格。零售裁剪集无缺格、额外格和重复；图块号、子块、格高、地形类、坡型无差异；桥覆盖片/帧、矿格/富集度相同。门槛是数据比对，不能当逐像素画面或完整分层寻路验收。

## 实际改动与玩家结果

- 恶魔岛的建造中控制器旁**已有** 23 段 `CAFNCP`；零售格 x=37–43、y=67–73，缺口在 (40,73)，映射世界格中心 (117.5,30.5)。未给首关加假墙。`tests/time_shift.gd` 新断言：正确数量、缺口、邻栏进通行网格；二次穿越后再核对实体仍保留。先前附近地形与真假墙规则继续覆盖。
- `data/maps/hollywood_wall_overlays.json` 由零售覆层提取坐标/类型/帧；`hollywood_mission.gd` 新开局装配 94 尤里墙、47 黑栏、28 白栏、19 铁丝栏，55 网格、原版已存在的连接图集，木围栏可被碾压、硬墙按既有规则；不计入清剿目标。`game_data.gd` 只给好莱坞复用三种木栏定义；`battle_saves.gd` 为本关中立木栏准入，避免首次复测出现的“单位或阵营不兼容”。既有战场旧档不会凭空补墙，避免替换玩家原来的战场和堵住正在走的单位。
- 未重烘地形或单位/建筑素材，复用现有贴图；未声称每段围栏画面逐像素一致。墙的连接帧按实际邻接/耐久绘制。

## 战场回归

Godot 4.7.2 隐藏无头、隔离 APPDATA；日志 `.validation/three-map-retail/`：苏一 `--alcatraz-cliff` 19/19、`--fence` 10/10、主线 52/52；好莱坞 `--retail-walls` 13/13、同档独立进程 `--cold-retail-walls` 3/3、`--bridge-tech` 59/59、主线 94/94；苏七 `--sites` 309/309、主线 51/51。夹具摆位、推进部分时钟、造伤害。围栏新档专项破坏一格并确认冷读只剩 187 段且仍挡路。尚未逐座桥头实车覆盖、逐地形接缝同机位检查、全难度自然通关、窗口画验或打包，不改玩家档。

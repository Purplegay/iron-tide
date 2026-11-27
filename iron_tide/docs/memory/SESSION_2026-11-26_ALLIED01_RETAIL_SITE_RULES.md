# 美国首关：建筑规则、房色与任务回归

用户要求全项查漏。承接 `SESSION_2026-11-26_ALLIED01_SCRIPT_GAPS.md`、`SESSION_2026-11-26_ALLIED01_OUTCOME_BRANCHES.md`、`SESSION_2026-11-26_ALLIED01_ISLAND_OVERLAYS.md`。本批完成下列可证实问题，不构成整关补齐。

- 零售 `ALL01UMD` 的 `[GASPYSAT]` 是 `Radar=yes,SpySat=no,Power=-1,Strength=1000,Armor=wood,Capturable=true`。本关 `GameData` 按地图覆盖，不套通用卫星；`SupportSystems.satellite()` 排除它，不给全图视野。未更改开局 FreeRadar 和正常小地图定位。
- `[GTGCAN]` 地图覆盖是 2000 HP、钢装甲、耗电 100、不可占领、无逃生乘员；`[GrandCannonWeapon]` 伤害 150、ROF 120 帧、最大 30 格、最小 3 格。新开局和穿越后重建用同一入口。旧档恢复雷达/巨炮耗电、装甲、占领资格和巨炮武器，不补满旧血量或改变旧档保存的最大血量。实测玩家 slot2 副本仍持有八厂，旧 1600/835 更新为 1600/736；供电状态未退回。
- `house_color.gd` 对带原图房号的首关敌方应用零售颜色：French/Special/Soviet2House 为 DarkRed，YuriCountry/Confederation 等为 Purple；对应中立房灰。己方继续尊重玩家设置。预置及有归属的一批脚本部队生成后刷新，快照应用旧字段后重算；没有改外交/识别描边，不把驱动材质检查当成每个动画层有头目检。
- `allied_first.gd` 兵营限制只检查玩家仍控制的盟军兵营，敌人持有的同型号建筑不应压制失厂后的工程师空投。当前仍是移植救援时序。CG、原声与医院/墙体重跑原验证，未替换或新编媒体。

Godot 4.7.2，隐藏无头隔离 APPDATA：`tests/allied_first_playable.tscn -- --retail-sites` 23/23、`--reported-slot2 --carriers` 38/38、`--engineer-rescue` 26/26（最终 `coverage-final-*`），`--hospital` 26/26、`--island-walls` 24/24、`--extended --natural --ggi-intro` 26/26（`coverage-*`）；均 exit0、stderr 空。旧档副本按原样读取，航母路线仍用夹具破坏控制器，没有获证舰载机击杀；工程师回归毁兵营，不单独造敌方同款兵营测转属。验了配置和运行实体，不做逐武器实射、全部帧和图形。玩家 slot2 原件 SHA 未变。日志 `.validation/allied01-playable/`。

仍缺：界外建造场转属及控制器原版双链、逐厂难度失败完整图、金门桥附着连锁和分层、全局 AI、开场完整演出、字幕人工核听、围栏西口自然通过及其余未载入建筑/场景。未自然从新开局通关、未图形验收、未打包。

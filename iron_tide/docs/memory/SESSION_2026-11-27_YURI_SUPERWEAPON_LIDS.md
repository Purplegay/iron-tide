# 心灵控制器与基因突变器提前开盖

- 玩家反馈《首脑游戏》两座超武倒计时临近归零但没有开盖。沿用 [待机关盖闪烁修正](SESSION_2026-11-26_YURI_SUPERWEAPON_FLICKER.md)。本机 Steam 尤复零售 `rulesmd.ini` 的 `YAPPET/YAGNTC` 均设 `ChargedAnimTime=1`；`artmd.ini` 的 `SuperAnimTwo/Three/Four` 分别是开盖、开盖后的循环、收盖。基因突变器的循环复用开盖 SHP 后段。实际取 `ra2md.mix > genermd.mix` 下 YGPPET_F/G/H（76/32/76 帧），YGGNTC_F/H（124/124 帧），均有配对投影。温带源、哈希、画布和帧表记入各 SHP 描述。
- `scripts/buildings/building.gd` 用现有充能值推导姿态：剩余 60 游戏秒开始开盖，开完即循环待发（不改变实际就绪时点），正式发射后播放收盖，再回到关盖。开盖进度跟随充能值，充能停住时不开下一帧；发射仍沿用既有电力和 AI 选目标规则。原版阶段图是完整姿态，绘制时替代主体及主体影子，而不是把已经开盖的图叠到旧盖上；命中拾取走相同的可见动画层。保留心灵控制器灯光与已有待机闪烁修正，不改 `YAPPPT` 剧情道具。
- 共享生成器 `tools/yuri_superweapon_idle_art.mjs` 新增阶段层，原有两条建筑资产导出链复用；`tools/yuri_superweapon_lids.mjs` 可单独重建这五张。新图用原画调色及项目房色槽，同批用 `ra2pipe/shp_details.mjs` 生成双倍细节（432 帧、14 页），无额外加亮，保留 SHP 原画明暗。画面检查核对突变器放电和心灵控制器的能量与收盖图页。
- Godot 4.7.2，隐藏无头、隔离 APPDATA：`--headless --path . res://tests/yr_superweapon_idle_art.tscn` 69/69；`--headless --path . res://tests/head_games.tscn -- --routes` 10/10。两者退出 0、stderr 为空。第一组经正式建筑生成，覆盖健康/受损、提前量、图层互斥、开盖逐帧、就绪循环、投影、双倍图加载、实际发射与回到待机；第二组以真实战役运行场景和脚本生成入口验证两座设施提前开盖，突变器自动选择夹具提供的可见步兵并发射，进入收盖。日志 `%TEMP%/IronTide-YuriLids-20261127-125759/{idle-final,routes-final}.{out,err}`，双倍贴图审计同目录 `detail/source-audit.json`。
- 这是视觉阶段接入，未做原版开/待发音效、低电专属视觉、有头叠图观察、自然等待全周期或独立进程冷读档；未打包、未改玩家存档。存档既有充能字段可推导开盖阶段，未把有字段当冷读验证。

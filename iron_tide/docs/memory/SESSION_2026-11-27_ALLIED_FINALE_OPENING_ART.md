# 盟军第七关开场帐篷与旗帜显示

- 用户截图对应盟军 07《脑死》，不是苏军《首脑游戏》。Steam `mapsmd03.mix/ALL07SMD.MAP` SHA-256 `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`。Structures `1050334` 大帐篷（80,132，Neutral，64/256，3×2），`1050335` 小帐篷（79,134，Neutral，64/256，1×1），`1050336` 苏军旗帜（81,135，Russians，256/256，1×1；当前战场作为中立布景）。原图坐标、现有归属、碰撞和开局耐久不变。
- `tools/allied_finale_scenery.mjs` 从 `isosnow.mix`、`isosnomd.mix` 导出元数据，核验后半段只有影子索引 0/1，把投影起始帧与完好/受损帧数拆开。六帧图的受损影子是帧 4，完好影子是帧 3；八帧图的影子从帧 4 开始。旧逻辑要求 `count == dmg*2`，把这批雪地建筑全部落到椭圆回退；`building.gd` 现优先用显式 `shadow_start`，本体与影子同锚。血条按当前本体的非透明像素边界对齐，不再由通用半径定高。
- 原 `artmd.ini` 指定 `CARUFGL_A`：雪地版 16 帧旗面加 16 帧投影，接现有建筑动画层。两顶帐篷、旗杆、旗面动画保留原雪地调色板和明暗，逐帧 Scale2x（不扩原 alpha 轮廓），`RA2Art.allied_finale_site` 加载双倍图集，原尺寸供几何和拾取。目视检查了这四张图集；图集中紫色为投影索引标记，运行时绘制为半透明黑。
- 复跑导出：`node tools/allied_finale_scenery.mjs '<Steam 尤复目录>' .validation/allied-ends-20261126/audit/yr_all07smd_index.json`。
- Godot 4.7.2 隐藏无头，隔离 APPDATA/LOCALAPPDATA：`--headless --path . res://tests/allied_finale_playable.tscn -- --opening-snow-art` 两次 17/17，退出 0、stderr 空。走战役菜单出击，跳片头/雷达并夹具推进空投，验证三物件的数量/原图位置/耐久、投影命令及同锚、血条位置、旗面双倍素材与换帧。记录 `.validation/finale-opening-art-20261127/{test,repeat}.{out,err}`。默认长回归通过上述检查和接管段，随后因情报面板控件为空中断；本次长跑还遇到了并行变化中的苏军 `super_site` 签名不一致日志，不作为完整验收，未修改该路径。未有头同机位复核、未测旧档冷读、未打包或改玩家存档。本轮不改任务触发器与地图 AI。

# 苏军第一关的坦克碾压围栏

《时空转移》科技建筑 CATECH01 邻近一排 CAFNCP。地图围栏坐标来自 data/time_shift_field.json，零售建筑规则 data/ra2/buildings.json 将 CAFNCP 定义为 Wall=yes、Crushable=yes。旧版按建筑封路，普通犀牛接触墙体也没有碾压处理。CAFNCP 的 64 帧图集缺少围栏布局元数据，只显示孤立立柱。

scripts/world/battle.gd 对具备碾压能力的地面单位按地形版本惰性建立通行网格，保留地形、交通避让、普通建筑与坚固墙体。scripts/buildings/wall_art.gd 从原版规则识别可压墙体。scripts/units/unit.gd 使用真实滑动碰撞命中的栏段走建筑受击与死亡流程。assets/ra2/shp/CAFNCP.json 启用 16 种连接、两档血量及后半区阴影帧。

Godot 4.7.2 图形运行 tests/time_shift.tscn -- --fence，隔离 APPDATA。从苏军菜单出击，跳过简报后开放登陆边界，在 (97.5,125.5) 栏段前生成犀牛，下达普通移动命令，接触压毁栏段并抵达另一侧目标附近。10 项断言通过，stderr 为空，日志 %TEMP%/IronTide-fence-regression/out.log。检查包括步兵通行格、混凝土墙规则与阻挡格、围栏连接布局加载。未逐帧验收外观、未逐车型或玩家旧存档复测，未打包。

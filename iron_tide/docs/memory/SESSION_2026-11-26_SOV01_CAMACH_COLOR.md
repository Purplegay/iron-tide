# 苏军第一关机械维修厂换边颜色

截图对应通用 `assets/ra2/shp/CAMACH.png`。零售第一关地图记录 `CAMACH` 位于 (99.5,132.5)，原归属 `Americans`，因此尚未占领时蓝色正确；选中黄框不代表已经易手。苏军工程师成功占领后才应变为苏军红。

实际修复：`shaders/house_remap.gdshader` 的 `SHOP_FACADE`（paint_mode 8）之前只处理好莱坞城市贴图的纯红房色和褐墙，跳过普通 CAMACH SHP 中已烘焙的盟军蓝房色阶。现优先识别该蓝阶并按原明暗转换到当前房色，保留原有好莱坞红阶和墙板分支；只影响有主 CAMACH，中立建筑不套此模式。占领入口 `AlliedAbilities.change_side` 已调用 `refresh_house_color()`，无需另改换边事件。

验证：Godot 4.7.2 编辑器扫描无解析错；Compatibility/OpenGL 独立 SubViewport 使用生产 shader 和通用 CAMACH.png 渲染，764 个蓝色房色像素全部变色，残留蓝色 0。前后对照图在 `docs/memory/evidence/shop-camach-sov01/before.png` 与 `after.png`，已目视检查钢架与吊架未被整片染红。临时探针位于 Chatbox 本次 sandbox 的 `shop_color_probe.gd`。

后续针对“占领应同步阵营色”补验：`tests/time_shift.gd -- --shop-capture-color` 从苏军战役菜单出击，确认第一关 `CAMACH` 初始属盟军、加载通用蓝色 SHP 且材质使用盟军色；生成苏军工程师、下达正式 `allied_engineer` 命令，将测试工程师置于入口后执行正式 `AlliedAbilities.tick_action` 进门。占领同一次调用内验证 `side == ally`、工程师消耗、材质模式为 `SHOP_FACADE` 且目标色为苏军房色。隔离自定义用户目录、复用主工程导入缓存的 Godot 4.7.2 无头真实 Battle 场景 8/8 通过，退出码 0，stderr 空。日志 `%TEMP%/IT-S01-ColorRun-a7ba34e9a2ba484fa4126bac53ca35e9/verify.out` 和 `verify.err`。第一次独立导入副本因缺少完整 `.godot/imported` 资源及类缓存失败，不计入通过。

未验证：工程师从远处自然寻路到门、玩家鼠标点击全流程与冷进程读档恢复后的颜色；当前对照图来自生产 shader 的独立图形渲染探针，并非战场同机位实拍。未改玩家存档或既有 shader 的其他未提交改动。

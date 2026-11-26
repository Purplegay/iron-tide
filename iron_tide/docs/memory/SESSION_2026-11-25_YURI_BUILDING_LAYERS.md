# 《首脑游戏》尤里建筑缺层

截图红框对应 YAPSYT 的底座。原版 artmd.ini 把上半部放在 YAPSYT_A。tools/head_games_assets.mjs 接入 head_games_building_layers.mjs，从温带剧场导出心灵控制塔、作战实验室、秘密实验室、任务心灵信标及复制中心的活动层。塔的健康段为 0–25，受损段为 26–51，阴影偏移 52。任务信标使用专用资源名。城堡原图使用静态主体。

Godot 4.7.2 导入资源后从 tests/head_games.tscn 的战役菜单进入，参数 -- --building-art。32 项断言通过，stderr 为空。五种设施包括七座塔均装配了可见活动层并取得贴图。验证范围为战役启动、建筑实例与资源加载。尚未逐帧实机录像或导出发行包。

图鉴 evidence/YURI_BUILDINGS.png 收录 16 种阵营建筑与 7 种战役或特殊设施，使用零售温带素材合成并逐图目视核对。图鉴使用独立展示比例。

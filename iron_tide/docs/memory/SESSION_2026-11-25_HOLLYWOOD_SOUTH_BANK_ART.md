# 好莱坞南缘桥头竖条

南段维修小屋旁，(56,146) 原图高度 0，(56,147) 为高度 4 的 TMP 279。旧地形烘焙对断崖两侧顶点取平均，投影在部分区域重复采同一行图像。通过原战役窗口同机位复现了玩家截图中的路缘和挡墙长条。

`tools/bake_native_slopes.py` 在这处桥头用高度 4 的采样平面读取从零售 TMP 合成的画面，外围四格逐渐过渡。属于平面纹理移植近似。已重新生成实际战场加载的 `assets/maps/yr/yr_all02umd_bridge_ground.png`。4680 × 4680 图的差异包围框为 (1200,3336) 到 (1656,3840)，右下端不含。

Godot 4.7.2 OpenGL 窗口运行 `tests/hollywood_campaign.tscn -- --street-slope-picture --south-bank`，7 项通过。在 (57.5,147.5) 同机位对照修前 `%TEMP%/holly-bank-before.png` 与修后 `%TEMP%/hollywood-south-bank.png`，公路、铺装和挡墙的长竖条消失。本次目视覆盖南段桥头，未对照零售客户端逐像素截图。

# 好莱坞街道斜坡

玩家指出截图中的条纹道路是普通斜坡。以后移植地图时，遇到重复的草带、台阶形断开的黄线或碎裂的人行道，查原图格高度、坡型、TMP 子块和延伸像素，在实际游戏镜头下检查完整路段。好莱坞复查位置为 (154.5,128.5)。这里的 DRSLPE03 街道连续跨过高度 0、1、2、3。

新增 tools/bake_native_slopes.py，使用同一剧场的原始 TMP 和色表，在原版等距坐标中按格高合成，再按坡面四角高度取样到项目的平面地图纹理。已更新实际战场使用的 yr_all02umd_bridge_ground.png，处理 1286 个坡格、12 种坡型。项目的地形坐标与车辆运动仍采用平面模型。本次验证覆盖地表图像。

复现时使用 Python 3.12 和 Pillow，依次传入零售剧场素材目录、data/maps/yr_all02umd.json、原始无桥地面 PNG、输出 PNG。本次素材目录为仓库根 .validation/expedition-v2-20261117/map-source。Godot 4.7.2 OpenGL 窗口从战役指挥室进入好莱坞，tests/hollywood_campaign.tscn -- --street-slope-picture 共 7 项通过。核看 %TEMP%/hollywood-street-slope.png 与修前修后纹理对照 %TEMP%/holly-slopes-cmp.png，确认样本道路中线连续，车道内的横向草带消失。其余坡格由同一流程处理，逐处画面与车辆行驶姿态不在本次验证范围内。

## 科技医院旁的西北双幅弯道

上一轮画面验收只覆盖 (154.5,128.5)。本轮按玩家截图定位到 CATHOSP 旁 (81.5,48.5)，两幅 Prslpe03 公路各跨四格。旧地面图在坡顶相邻平地仍有横向错开的路缘和黄线。tools/bake_native_slopes.py 现将 Prslpe 公路坡格周围一圈平地一起从按高度合成的 TMP 图取样，共处理 1286 个坡格及 38 个邻接平地格。已更新实际战场地面纹理。

核看修前、修后相同位置的纹理裁图，并通过 Godot 窗口运行 tests/hollywood_campaign.tscn -- --street-slope-picture --northwest，从指挥室进入关卡，7 项检查通过。截图 %TEMP%/hollywood-northwest-slope.png，日志 %TEMP%/nw-slope-field.log。目视验收覆盖这处双幅公路的接缝。

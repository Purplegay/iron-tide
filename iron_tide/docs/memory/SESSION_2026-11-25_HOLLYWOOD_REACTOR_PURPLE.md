# 好莱坞尤里房色与生物反应炉

ALL02UMD.MAP 的 YuriCountry、Yuri2、Yuri3、Yuri4 均设 Purple，rulesmd.ini 的 [Colors] 指定 8 位 HSV 201,201,189。HouseColor 将本任务敌方映射至该色，单位、建筑、血条阵营色和雷达敌方接触点取对应房色。

YAPOWR_A 和 B 各含 8 帧正常、8 帧受损、16 帧阴影，两套都是完整炉体。C 是灯光，正常与受损各 5 帧。运行时空炉使用 A，C 绘在其上方，半血切换损伤态。tools/hollywood_yuri.mjs 与 assets/ra2/bldanim/YAPOWR.json 同步校准帧段和层序。

Godot 4.7.2 从战役指挥室进入，OpenGL 场景专项 24 项通过。截图见 %TEMP%/it-hollywood-reactor-view.png 与 it-hollywood-reactor-damaged.png，后者同画面显示四成血量反应炉及附近完好反应炉。无头胜利回归 57 项通过，日志 %TEMP%/it-hollywood-reactor-win-checked.log。截图覆盖白天城市场景的空炉，雷达房色仅作代码核对。
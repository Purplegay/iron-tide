# 科技医院西北崖壁

好莱坞 CATHOSP 位于 (77.5,52.5)，西北侧 Cliff03/05/09 接 RAMP03，地图格高跨 0 至 4。bridge_art.py 的平面底图先贴地面再统一盖 TMP 延伸块，忽略格高。旧坡面烘焙只重采样坡格和公路邻格，在相邻崖壁留下三角形断口。

tools/bake_native_slopes.py 现在对 Cliff 周围两格取原版等距合成图，按相邻格共享角点的平均高度连续取样。平均角高是平面重投影的近似。重烘 assets/maps/yr/yr_all02umd_bridge_ground.png，1286 个坡格和 3085 个平格。窗口运行 tests/hollywood_campaign.tscn -- --street-slope-picture --hospital-cliff，从指挥室进入战场，7 项检查通过。核看 %TEMP%/hollywood-cliff-review.png 和 %TEMP%/hollywood-hospital-cliff.png，样本崖顶与崖面连续。其余悬崖尚未逐段实机验收，单位高度和前后遮挡未验证。

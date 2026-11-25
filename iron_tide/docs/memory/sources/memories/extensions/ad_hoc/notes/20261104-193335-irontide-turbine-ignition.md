# IronTide · 坦克杀手车体涡轮尾焰挂点案例

用户指定的表现顺序为起步叶轮高速旋转，先沿涡轮绕一圈，再向车后喷出大尾焰。v0.25.18 的工房与战场共用 tnkd_exoframe.gd；红蓝侧板与主炮套沿用现有装配。原有 AI 叶轮材质裁取内盘以旋转 UV，AI 蓝焰纹理铺在局部曲线上。
转向案例使用宿主的 32 向帧和投影原点，在 TNKD 喷口端面 X=-26.37、Z=13.5 的 YZ 平面上布置半径 5.35 的焰根。转向偏移只加到焰尾，原地转向计入点火。后续载具需重测宿主挂点、轴向和遮挡。
技术证据在 C:/Users/admin/IronTide/docs/MODEL_RENDERING.md 与 docs/tnkd-turbine-ignition.gif。隔离桌面 unit_showcase_regression 共 716 项通过，包含工房与真实移动、转向和停止指令。玩家外观验收待确认。

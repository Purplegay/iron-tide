# 盟军终关超时空增援特效

玩家截图中倒数后基地车和八组护卫直接出现，无传送画面，电台内容重复。续读盟军脚本切片、首末关差距审计及已有超时空资源。零售 ALL07SMD 的 `Chrono_MCV 0964B13C` 有 107 超时空增援到 AA、`ChronosphereMove`，`098DB96C` 另有八个 107；此前执行了 spawn 和播音但没挂特效。

`allied_finale.gd` 每个 107 成功生成后在单位实际落点加一次受迷雾过滤的 `WARPIN` 地环，基地车 AA (43.5,76.5 网格) 镜头到位并刷新视野后加一次既有 `CHRONOTG`，由它播放 `ChronosphereMove`，不重复执行同批语音动作。地环取零售 General.WarpIn 对应 WARPIN.SHP、ANIM.PAL；源 SHA e8f10d52d9b8a51a88a3eb737612312d9db8ac1cdd81977eb362411bdf3dea75；`../ra2pipe/yr_chrono_fx.mjs --with-warp-in` 可重建。15 帧/秒是项目适配，额外中心 CHRONOTG 是项目表现复用，不声称严格逐帧等同原引擎。HUD 电台已经写一次左上日志，删本关重复 emit。

Godot 4.7.2 隔离无头真菜单回归 `tests/allied_finale_playable.tscn` 36/36（九个地环与己方落点一致，中心光效一个、资源有动画帧）；同隔离目录另起进程 `-- --cold` 4/4，均退出 0。日志 `.validation/finale-chrono-fx/`。未有头校准亮度、声音及镜头实际画幅，未打包。已发生的传送不倒放，读增援前档才会触发。
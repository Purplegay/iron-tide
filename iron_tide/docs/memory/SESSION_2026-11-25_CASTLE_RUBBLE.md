# 《首脑游戏》河心城堡废墟花屏

玩家截图中的紫红噪点对应 CATRAN03 摧毁后的第 4 帧。原图取自 ra2md.mix 内 isotemmd.mix 的 CTTRAN03.shp，共 8 帧。tools/head_games_assets.mjs 过去统一套用单位调色板。现为废墟单独使用 isotem.pal，其他帧沿用原单位配色、明暗和透明轮廓。运行时仍由 building_rubble.gd 绘制。

在项目目录用 `node tools/head_games_assets.mjs <零售目录> --castle-only` 重建 assets/ra2/shp/CATRAN03.png。等待完成后执行 `node ../ra2pipe/shp_details.mjs <新临时目录> CATRAN03`，核对 source-audit 输入散列再复制城堡的细节页和清单到 assets/ra2/detail。首轮细节页取到旧图，节点断言通过但战场依旧花屏。最终以 SHA-256 为 3ef509bb4c0b60298c9d6451a36c828779f43af26b34da2057b44212cf805b54 的源图重建。

Godot 4.7.2 图形窗口、隔离 APPDATA，运行 `res://tests/head_games.tscn -- --castle-rubble`，从战役菜单出击，跳过开场通讯，揭开目标处迷雾并用 receive_hit 击毁城堡。5 项通过，退出码 0。同位置实机截图可辨认石墙、碎石及草色。[战场截图](evidence/SOV07_CASTLE_RUBBLE.png)。验证范围限工程运行版专项场景，旧存档和发行包未测。

# 苏军第七关夜色提亮

接续 SESSION_2026-11-25_SOV07_NIGHT.md。按玩家反馈，在 scripts/ui/post_layer.gd 将 yr_sov07 专用战场 RGB 乘数从 (0.22, 0.22, 0.385) 调到 (0.56, 0.58, 0.72)，保留偏冷色调和纯黑遮蔽。

Godot 4.7.2 图形模式经 tests/head_games.tscn -- --opening（固定 60 帧）进入战役，截图 evidence/SOV07_NIGHT_BRIGHTER.png。目视核对开局道路、步兵、装甲车辆及迷雾边缘。截图在基地车展开前取得。开局测试后段有 5 项生产卡检查报告科技前置不足，退出码 5。验证覆盖开局画面，未打包。

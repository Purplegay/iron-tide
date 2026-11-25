# 2026-11-20 警戒槽体阵营映射纠正

用户指出盟军警戒值UI误用了日升样式。已查看experience_panel.png图集：三排槽体分别为日升、苏联、盟军。scripts/ui/uprising_threat_meter.gd::_draw 的origin由Vector2(233,96 if soviet else 0)改为Vector2(233,96 if soviet else 192)。盟军用第三排蓝灰金属槽，苏联第二排不变；按钮本来是英文PUSH，未更改。图集第一排对应日升，不能继续作为盟军默认。

该origin同时用于槽体、玻璃灯条、左环倒计时UV，均随映射纠正。未改警戒值、总攻时长、增援或存档。git diff --check通过，已查看原图；未运行Godot实际HUD截图，不宣称视觉验收。未打包提交。此前SESSION_2026-11-20_RED_ALERT_UI.md的盟军y=0坐标说明已被本条取代。

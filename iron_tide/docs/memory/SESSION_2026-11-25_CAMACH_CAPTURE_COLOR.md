# 机械维修厂占领涂装

截图与 CAMACH 城市贴图吻合。占领流程已有 refresh_house_color，但该表保留原版 16 级纯红房色。HouseColor 和 house_remap 现在对有主 CAMACH 使用专属模式，按 252 归一化明暗并应用当前所有者房色。中立外观保留。

Godot 4.7.2 OpenGL 独立 SubViewport 读取生产 shader 与 CAMACH.png，蓝色和绿色各验证 815 个房色像素，所有不透明像素误差超限数均为零。测试脚本在 %TEMP%/IT-Shop-Pixel/check.gd。

已扩展 tests/hollywood_campaign.gd 的 shop-capture 分支。整关一次发令成功但未占领，测试夹具提高工程师生命后重跑，工作区缺少 hollywood_turret_pose.gd 导致战役编译中断，占领至快照恢复的整关链路本次未通过。未打包。

## 厂房外墙的战场实拍

好莱坞城市 CAMACH 图集的原版纯红主要覆盖门框和支撑杆。house_color.gd 为有主维修厂选用 SHOP_FACADE，house_remap.gdshader 将棕褐色墙板按原有明暗映射到当前所有者颜色。黄色吊架和白色高光仍可辨认。

Godot 4.7.2 源码运行 tests/hollywood_campaign.tscn，参数 --shop-capture --shop-pictures。从盟军战役出击，工程师右键占领并消耗，同机位实拍中立褐墙与占领后的盟军蓝墙。快照恢复后仍归玩家。原版房色像素 815 个全部符合预期。退出码 0，标准错误为空。截图和日志在 evidence/shop-facade/。本次实拍范围为好莱坞完好维修厂与默认玩家色，使用隔离配置和高生命值测试工程师，交付为项目源码。

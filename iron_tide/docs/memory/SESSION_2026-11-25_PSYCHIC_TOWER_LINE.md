# 心灵控制塔连线

按截图红箭头所指的塔和步兵处理。head_games_weapons.gd 的 tower 为每个受控目标设置 controller，原先 allied_abilities.gd 的 draw_status 只从单位控制者绘线。现受控单位在该入口检查控制者是否为存活、对玩家可见的 YAPSYT，从塔的美术中心至自身美术中心绘制紫线。每个目标独立绘制，只在控制关系有效时显示。

使用 Godot 4.7.2 从项目临时探针场景加载 allied_abilities.gd，TOWER_DRAW_COMPILED=true。首脑游戏无头回归在等待期限内未输出检查结果。未验证实机画面、移动端点与遮挡，未打包。

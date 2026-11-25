# 远征商店新商品标记

本次刷新上架且尚未售出的商品在标题下单独显示亮橙色粗斜体 NEW!。刷新按钮显示费用与更换格数。market.gd 记录 fresh_stock，screen.gd 与 shop_card.gd 控制商品标记。

Godot 4.7.2 隔离商店场景验证，6 格中锁定 1 格，刷新按钮显示「刷新 · 免费 · 更换 5 格」。刷新后出现 5 个设置独立字体的 NEW! 标签，锁定货位 fresh_stock 为 false。
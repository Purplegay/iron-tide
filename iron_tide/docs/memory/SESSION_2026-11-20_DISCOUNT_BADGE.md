# 2026-11-20 商店折扣黄色角标

用户在肉鸽优化/AI头像进行中新增：折扣改成卡片右上角黄色-XX%。

已修改scripts/expedition/shop_card.gd增加discount_percent/add_discount；screen.build_shop在apply状态色后添加独立overlay黄色底深字角标，按原价实际售价round(100*(original-price)/original)，不打折不显示；标题右侧预留70px；购买按钮只显示现价，去除商店优惠原价箭头和重复解释。角标tooltip保留原价现价。overlay不继承缺钱/售罄状态shader，黄色不变。

验证：sandbox/discount-preview最小Godot实际GUI+同源shop_card及shader，2张卡（可购买/不可购买），检查-52%（25→12）、50%（80→40）、无discounted不展示、位置右上与不继承材质，exit0。截图discount_preview.png已view_image人工查看，黄色显示正常且不遮标题。未运行完整远征回归，整个六项优化与头像仍未完成。参考SESSION_2026-11-20_EXPEDITION_ACTIVE.md。

AI绘图已accepted后台记录4fd21b5f-d56f-4c18-b4aa-ca5cf0d98f22，gpt-image-2.6，六宫格RA3风格：上排守望者/炉火/北辰，下排铁脊/游隼/雷铸。必须等待自动回调，不轮询。谭雅鲍里斯用户要求原版，不能用SVG。六宫格回来后裁切替换SVG路径并验证。所有工作授权持续有效。

持久记忆100条已满，上一轮save失败，主要靠项目交接。

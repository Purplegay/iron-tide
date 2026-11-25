# 满员兵种的商店规则

用户最终确认，已上架的招募卡在满员时可以锁定、解锁和跨店留货。market.gd 的 lock_available 对招募商品单独判断，人口和兵种数量仍限制购买与生成。screen.gd 同步更新说明。独立用户目录运行 expedition_shop_pricing_regression.tscn，268 项全部通过，覆盖满员保留旧锁、解锁再锁、刷新与换店保留折扣、读档和腾位购买。验证方式为无头回归，未实机点击截图中的卡片。

## 早先行为（已被上述规则取代）

普通货位、特装和定向招募取自按 Army.room 筛选的 unit_pool。market.gd 的 lock_available 重新使用 offer_available，满员时取消留货资格，整理存档会清除旧锁。先上架、后满员的卡仍可在当前货架显示，下一次刷新或换店会换掉。满员限制适用于招募商品，兵种养成另按可提升条件筛选。

Godot 4.7.2 独立 APPDATA 下第 11 关 TNKD 在有空位时进入候选池。加入 4 台并设置匹配的定向羁绊及旧锁后，开店和刷新共生成 32 次货架，TNKD 招募出现 0 次，旧锁在 normalize_shop 中清除。验证日志在临时目录 IronTideCapacity-9fdf3c39b07d47a58cbbcb59e26795ac/retest.log。未读取玩家原档，无法确认截图中上架和满员的先后顺序。

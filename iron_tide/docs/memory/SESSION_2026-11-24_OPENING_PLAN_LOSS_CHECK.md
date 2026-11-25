# 开局出兵预设缺失排查

只读检查正式用户目录。局外 JSON 的 academy 缺少 opening_order_plans 和旧 opening_orders 字段，production_recipes 中仍有命名手动配方。检查时 expedition.itrung 和 .bak 内匹配到的 opening_orders 均为空数组，未找到能还原顺序的订单。正式目录没有局外 JSON 的同名备份。

MetaProgress 启动时读档，save() 将当前内存中的整份进度写临时文件并替换正式文件。若两个游戏进程共用目录，先启动的进程后保存可覆盖另一个进程已保存的内容。此次没有并发写入的历史证据或之前含订单的玩家快照，无法据此认定原因。上轮正常保存回归不能排除覆盖。此次仅排查，没有修改代码或玩家文件，也没有复现历史写入过程。

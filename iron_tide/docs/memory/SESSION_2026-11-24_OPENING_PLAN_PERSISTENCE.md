# 开局方案独立持久化

编辑器保存整套方案到 user://opening_order_plans.cfg，包含方案名、选中索引和有序订单。每次写临时文件并读回校验，再替换目标，.bak 保留上一版。编辑器与新战场冻结订单都通过 current 读取，旧 academy 方案在缺少独立存档时迁移。普通局外进度保存只写原 JSON。

隔离 APPDATA 下 Godot 4.7.2 运行 opening_orders_regression 场景，验证编辑、保存、旧进度写入、混编派单和生产栏状态，输出 OPENING_ORDERS failures=0。新进程传 -- --cold，读取方案名、选中项和具体顺序，通过。再把隔离目录主文件替换成无效方案，新进程从备份读取，通过。测试对象为源码，发行包尚待更新。此次无历史订单可恢复。
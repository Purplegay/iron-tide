# 电脑不能自主生产英雄

用户要求 AI 不能生成英雄单位。本次禁止电脑自主选兵和工厂生产独立英雄类型：`TANY`、`BORIS`、`YURIPR`、`CLNT`、`ARND`、`STLN`。由普通兵种晋升的英雄不反向封禁基础兵种；保留玩家生产、关卡预置、脚本指定生成与既有场上单位，不修改存档格式或追溯删兵。已有英雄生产单到活动队首时取消并按正常取消逻辑退款，队列可继续。短名房号仍按 `BattleRequest.is_ai_house` 判断，不把中立房算电脑工厂。

`GameData.UNIQUE_HERO_TYPES` 供电脑生产候选与既有唯一英雄限额共用；`Building.can_queue`、`queue_block_reason` 及队列消费统一拦截。遭遇战直接选兵使用的 `_unit_pool` 已沿用 `ai_product_allowed`。普通战役生成入口 `Battle.spawn_unit` 没有添加全局黑名单，保留原图指定演员。

Godot 4.7.2 隐藏无头、隔离 APPDATA，`res://tests/ai_hero_production.tscn` 21/21，退出 0，stderr 空；日志 `%TEMP%/IronTide-AI-Hero-20261127/final.{out,err}`。覆盖正式遭遇战候选池、敌方和其他电脑房排队拦截、模拟旧订单进度与退款、普通兵与玩家谭雅排队、脚本直接生成尤里 X。没有用真实旧档复验订单迁移，未跑完整战役或发布包。
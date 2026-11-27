# 盟军首关：场外建造场脚本转属

承接 `SESSION_2026-11-26_ALLIED01_OUTCOME_BRANCHES.md` 和 `SESSION_2026-11-26_ALLIED01_RETAIL_SITE_RULES.md`。本批只接用户五项中的场外转属入口，并回归两条既有胜利路径。

零售 ALL01UMD Structures 1028503：Confederation `YACNST`，(103,158)，在本项目可玩边界外，标签 `045CE63C`。`0BD650AC` 原始时间字段 50 后启用 `045CEF3C` 和 `0BD6117C`；`045CEF3C` 事件 32/355，动作 14 房号 16（BridgeHouse）。`allied_first.gd` 在进入过去时保存场外建造场原房；晚期检查已启用且存在已登记的任务控制器，转为 BridgeHouse 并关闭 `confederation_production` 标记；重复检查保持归属。其为脚本对象代理，不把界外建筑加入本地生产/迷雾/战斗。早期胜利不改为强制等待晚期。仍未模拟零售 355 槽完整语义、双链独立取消、场外施工/生产 AI；关闭的是已有脚本标记，不宣称停掉了尚未实现的工厂。

Godot 4.7.2 隐藏无头、隔离真实 slot2 副本：`tests/allied_first_playable.tscn -- --reported-slot2 --carriers` 38/38；加 `--late-dominator` 41/41；另进程 `--cold-offmap-yard` 3/3，全 exit0、stderr 空。用夹具推进计时（49 至 50.1 模拟秒）、清敌及伤害，不是自然通关；测试控制器仍存活时发生转属，写 quick 并验证冷读取归属、关停状态和不误结算。证据 `.validation/allied01-playable/yard-early.{out,err}`、`yard-verified-{late,cold}.{out,err}`。本轮玩家 slot2 SHA 仍为 `57213705CE674EEBC6DE9F8D77E10402E856D8F767ABD4BD3EA5BD543F442E0B`，未开图形窗口或打包。

未改逐厂失败完整触发、金门桥坍塌和分层、全局 AI 以及完整开场；这四项不能计作交付。双胜利也仍有上述近似。

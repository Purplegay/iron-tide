# 机械维修厂的全图维修

CAMACH 通过建筑更新驱动 civilian_sites.repair_vehicles。原版 death.json 中 CAMACH 有 UnitsGainSelfHeal=1，全局周期为 75 规则帧，单次维修量为 5。建筑可运作时按游戏时间累计，在每个周期仅遍历一次部队，按当前归属、原版 VehicleTypes 和 Organic 筛选并调用单位的 heal。扩展单位缺少原版分类时按 vehicle/naval 角色判断。余时随建筑 special 保存，换边时清零。城市设施显示机械维修厂名称、禁止出售，选中说明列出效果。

Godot 4.7.2，隔离 APPDATA，真实战役场景 tests/hollywood_campaign.tscn -- --shop-repair，共 13 项通过，退出码 0。验证了中立、工程师命令与抵达、首个 5 秒周期、远处己方坦克、敌方坦克与己方步兵筛选、易手、满血上限和摧毁。工程师定位到入口后推进实际占领指令，维修周期由测试定量推进。单位分类另核对了 HARV、DEST、DLPH、ORCA 的原版类型。冷启动读档和发布包属本轮验证范围之外。日志在 %TEMP%/it-shop-repair.log。

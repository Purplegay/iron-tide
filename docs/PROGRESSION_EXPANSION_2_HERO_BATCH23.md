# 英雄第二十三批：契约结算落盘与失败重试

2026-11-18，v0.29.34。本轮从第五稿3.6四份契约及共用存档边界开始核对，发现真实对局结算入口忽略保存失败；现已修正普通对局入口并验证。总目标仍active，游隼完整32向机身、其余要求的逐项审计及使用者视觉／自然对局确认尚未完成。

## 问题与改动

原入口先标记battle.ended，再依次结算生产／英雄契约、外观及货币。生产记录和战斗奖励调用忽略save返回值；临时文件不可写时，内存已得到卡牌、货币与防重标记，仍显示成功。重启读取原文件后本局进度丢失，同一未退出对局也被ended阻止重试。

新增 `scripts/rules/battle_rewards.gd` 在普通对局入口集中处理这几项：先保存academy、currency、stats、unlocked_skills、owned_cosmetics、settled_matches的修改前副本，在内存计算全部结算，最后调用一次现有临时文件替换保存。失败恢复以上字段，不发布meta_changed或battle_ended；成功后才发布一次养成通知、结束战斗并显示结果。计算使用原来的契约任务与奖励函数，没有改费用、数值或资格。

`production_counts.settle`、`MetaProgress.apply_battle_result`、`award_victory_skins` 增加内部persist参数，默认仍为true；只有新的普通对局事务传false。独立调用这些旧入口不等同于本次原子结算入口。远征先提交独立run文件的既有路径保留；本批没有解决或声称提供远征run与永久meta两个文件间的原子事务。

## 实际审计证据

| 要求 | 当前来源与证据 | 本轮结论 |
| --- | --- | --- |
| 谭雅双枪、原生C4及胜利生存资格；本人归属 | commando_contracts.gd、tanya_contract_regression（182项） | 当前专项通过 |
| 鲍里斯步枪、原生米格建筑战果及实际投弹编队次数 | commando_contracts.gd、boris_contract_regression（171项） | 当前专项通过 |
| 游隼直接载具击杀、普通命中后有效补满、不同真实目标 | peregrine_contracts.gd、peregrine_contract_regression（199项） | 当前专项通过；W不能代做普通命中补满任务 |
| 雷铸主电击击杀、实际生命损失及四击杀胜利资格 | leizhu_contracts.gd、expansion_contracts.gd、leizhu_cards_regression（206项） | 当前专项通过；护盾和追加区域伤害不冒充对应任务 |
| 四契约／八卡真正持久化，失败不出现虚假成功 | battle.end_battle → battle_rewards.commit；hero_settlement_regression | 原入口复现失败，本批修正后通过 |
| 真实旧战斗快照重载不得重复结算 | 新专项保存二进制快照、新建战斗场景并恢复同一match_id后再结算 | 通过；不是仅重复调用纯函数 |
| 其它卡、天赋、全部演示、外观与自然平衡 | 本轮未逐项重新审完 | 保留总目标，不以本表替代全量完成审计 |

新专项给真实对局注入已达标的四份当局任务账本和生存英雄，以隔离结算入口；不声称通过该夹具证明真实战斗任务归属，后者由上表四个现有专项覆盖。

## 验证及限制

本轮7个通过专项共12790项、0失败、0 SCRIPT ERROR／ERROR；其中远征已有专项占11851项。明细 `.validation/hero-settlement-20261118/summary.json`：

- hero_settlement_regression：57项。覆盖真实存储不可写、内存／磁盘回滚、成功重试、通知顺序、四份契约八卡、三类防重复标记、二进制重载，以及失败／平局／经典／GM强制／局中开启等非合格结果。
- 四英雄任务专项：182／171／199／206项。
- savegame_regression：124项。
- expedition_regression：11851项，保留当前远征行为；不证明跨文件失败原子性。

另跑base_recovery_regression：135项中4项断言失败，另有6条脚本错误；不能标为通过。在隔离源码副本恢复本批修改前end_battle入口后，重复得到同4项失败与同6条错误，见base-comparison.json及baseline-base_recovery_regression/godot.log。失败为旧“短局结束无需清理防御建筑”预期和AI恢复夹具的失效对象／缺produced字段。未改这些断言、未删除检查、未把已有失败纳入通过总数。

修复前新专项19项中17项失败，原始结果保留before-fix.json。修复后扩展到57项全部通过。源码无新增表现资源；0截图，所有运行使用Godot4.7.2 --headless。独立APPDATA／LOCALAPPDATA，主验证工程的源码与资源连接当前IronTide；隔离旧入口仅用于失败归因，不冒充当前实现验证。服务／DB／网络为none。结束后本批Godot／Python进程为空，见post-run-audit.json。无玩家档案修改、打包、提交或推送。

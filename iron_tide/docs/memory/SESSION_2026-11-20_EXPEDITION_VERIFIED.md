# 2026-11-20 肉鸽优化阶段验证与AI头像阻塞

接续EXPEDITION_ACTIVE与DISCOUNT_BADGE，本轮背景回调：gpt-image-2.5任务2e42228d-d581-4476-988b-642a464b2aca失败API403。此前gpt-image-2.6为403、Seedream5.5为400。无成功AI图，不能宣称头像完成，不自动无限重试。用户要求RA3感觉，谭雅鲍里斯原版。

已将hero_portraits.gd的PATHS清空，所有8英雄回退原版GameData.ra2_cameo_path，停止使用用户否定的SVG；SVG仍在磁盘但不显示。真实autoload核实谭雅res://assets/ra2/cameo/TANYICON.png，鲍里斯res://assets/ra2/cameo/BRISICON.png。新头像接入接口仍在，待成功AI资产后填PATHS（不填谭雅鲍里斯）。

验证副本 C:/Users/admin/AppData/Local/Temp/IronTideExpedition-20261120 ，独立user dir IronTideExpeditionReview20261120；assets/data junction生产资源；.godot/imported junction生产缓存以免全量重导入。只跑headless功能回归非性能验收，外部用户游戏PID24848未停止。

已完成且日志无ERROR/FAIL：
- tests/expedition_insights_regression.tscn：49 checks failed0，reports/insights.log。真实UI与战场，奖励受益人数/节点、增援时间、原版头像、精英路线确定性、筛选折叠、购买流水/磁盘读/重复保存、战损含英雄真实死亡、待到达和自产兵不误计、失败/胜利/撤退提交、旧记录无新增字段仍有效、自动出售收入和同次购买支出分开。不是人工整局/完整精英checkpoint重放或HUD分组点击验收。
- expedition_shop_pricing_regression：25/0
- expedition_production_unlock_regression：4/0
- expedition_reinforcement_regression：23/0
共101项通过，各报告日志在副本reports。result.json被每个测试覆盖，完整结果以各log为准。

本轮修复：run.commit将自动出售收入与保存前主动变化分开记账，胜利报告追加本次自动出售；撤退也记录报告和80支出；runtime撤退确认框60→80同步实际。已同步上层docs/EXPEDITION.md旧生产许可文字，未改其他并行修改。

当前生产新增功能可审阅：insights.gd（军团受益/增援/战后报告/收支）；elite_tactics.gd三种战术；screen界面与shop_card黄色-XX%角标；run/runtime/objectives/campaign接入；hud英雄分组区分身份；英雄养成和远征头像接口（当前原版）。经济只补自然游玩数据采集，没有足够数据做平衡结论或宣称完成实测调参。精英词缀读档幂等用special标记，尚未完整checkpoint测试；归属变化额外加成是否保留需审计。AI头像仍阻塞。

禁止把先前49项中的头像唯一性解释为AI头像验证：现用原版fallback，测试已修改为原版路径一致。两次新增测试类型推断错误都已修正后重新跑49通过。

持久记忆满100条，先前写入报限，交接以此文档为准。所有任务授权继续有效，未提交未打包。

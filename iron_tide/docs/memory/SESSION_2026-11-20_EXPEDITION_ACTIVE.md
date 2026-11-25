# 2026-11-20 进行中：六项肉鸽优化与英雄头像

本窗口头像后续结果：Seedream 5.5任务facd6e4b-891a-4346-a6d9-b30b6a41fe91回调失败API 400；随后尝试gpt-image-2.5，Chatbox自动审批因45秒未收到用户响应而拒绝，未实际运行。当前无生成图片、未替换生产头像；后续需用户在绘图确认卡确认后再生成，不能宣称完成。

本窗口11:08用户再次要求「英雄换成ai头像」。查询image history发现上轮任务4fd21b5f-d56f-4c18-b4aa-ca5cf0d98f22（gpt-image-2.6）API 403，generatedImages为空；头像未生成也未接入。计划换Doubao Seedream 5.5生成3列2行六宫格（按行E1/E2/MTNK/HTNK/ORCA/TTNK），成功回调后切分PNG、更新hero_portraits.gd和manifest并查看及验证。谭雅/鲍里斯保留原版。不能把触发生成当成完成。

用户已授权全部六项优化和全部英雄单独头像。最新纠正：必须用AI绘图能力，RA3感觉；谭雅、鲍里斯用原版。矢量头像已被用户否定，不可宣称头像已完成。准备调用chatbox_cli image generate出六宫格，回调后切分并接入；按工具要求接受后必须结束本轮等自动回调。

生产工作树已有大量并行修改。已新增 scripts/expedition/insights.gd、elite_tactics.gd、scripts/ui/hero_portraits.gd、assets/ui/heroes八张SVG与manifest（六张将换AI，两张弃用）、tests/expedition_insights_regression.gd/.tscn。已修改screen/run/runtime/campaign/objectives、unit_icon、hero_progression、hud，均尚未通过运行回归！不要宣布完成。

功能：奖励受益人数/兵种及3/6/9节点，营地增援时间表复用Plan，装备折叠/军团筛选/营地待办，战后报告和补给流水，三种公开精英战术。经济只做数据记录未凭空调值。所有生产改动需要进一步审计验证。

已知工作项/风险：
- run.commit流水目前按净补给变化归类，同一提交自动出售与购买合并会失真，需分开记录自动出售与主动交易；战斗report缺自动出售明细。需补胜利和撤退报告测试、旧存档验证。
- elite_tactics.apply速度会改move_speed和_base_speed，max_hp修改；需验证存档恢复幂等、归属变化、真实任务波。当前已有special标记。建筑筛选weapon非空。
- hud分组key改为unit_id:hero，点击组也改，需验证没有其他key依赖、按英雄隔离和普通单位不串头像。
- hero_portraits已把TANY/BORIS改为GameData.ra2_cameo_path原版；谭雅有assets/ra2/cameo/TANYICON.png；鲍里斯没有明显BORIS文件名，需查真正原版cameo配置，绝不能用新画SVG冒充原版。
- assets/ui/heroes目前SVG未按要求视觉查看，用户已否定，不交付。
- 文档上层docs/EXPEDITION.md旧生产限制尚未修。
- runtime撤离按钮80但确认框60已有漂移，应修。

验证副本 C:/Users/admin/AppData/Local/Temp/IronTideExpedition-20261120 ，scripts/scenes/tests/shaders复制，assets/data junction指向生产资源；project独立user dir IronTideExpeditionReview20261120，不读写玩家存档。首次editor --import超时被终止，日志reports/import.log约31%，无已见脚本错误但未完整加载！应复用生产.godot导入缓存（复制.godot/imported和class cache等）再做editor扫描避免全量重导入。

Godot C:/Users/admin/AppData/Local/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe 。生产editor import已成功但不足以验证未挂接新脚本。测试以真实场景+autoload独立用户目录运行。环境IRON_TIDE_REPORT_DIR=<副本>/reports。新增测试40左右检查尚未跑。已有测试expedition_reinforcement_regression、reward_level_display、shop_pricing、production_unlock等应回归。

沙箱脚本 implement_expedition.mjs / wire_portraits.mjs 已运行，不可重跑（非幂等）；make_hero_portraits.mjs被用户否定，不重跑。prepare_validation.ps1可复制当前源码但会再次全量导入应改。持久记忆已满100条，本轮save_memory报限额；必须依赖此交接并可替换上轮机会审阅记忆（上轮写入因限额失败，无ID）。

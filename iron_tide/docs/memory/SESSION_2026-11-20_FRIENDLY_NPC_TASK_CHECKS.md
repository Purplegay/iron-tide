# 2026-11-20 支线绿色/任务打勾/任务NPC阵营

用户要求支线左上描述绿色，任意任务完成打钩；救援工程师不应是敌人，拯救/守卫NPC阵营错误。

已改field_operations.gd：救援NPC spawn ally替代neutral。setup在新局/恢复后repair_npc_sides(world)，对存活expedition_contact或expedition_mission_unit非同盟单位通过AlliedAbilities.change_side改ally，同步groups/视野/AI等；临时mission标签保留，不参与占点、不加入军团。覆盖救援人员/护送车队旧checkpoint；defend主线原本玩家基地，无另中立NPC。未运行中每tick强制归属，只setup修复。

runtime.gd：hud_detail_status绿色#80ef9a，主线完成outcome1前缀✓否则○；追加tasks.completed_items。
field summary完成✓、失败✗、未完成○；失败联系人显示“支援已取消”，不再继续展示未来约定。objectives救援与研究每个完成项✓；新completed_items列已摧毁补给设施/首领节点和到达车队。主线其他单任务整体完成✓由runtime处理。已有救援进度条和完成世界圈隐藏保持。

验证独立副本C:/Users/admin/AppData/Local/Temp/IronTideExpedition-20261120，完整同步当前生产scripts（本轮未对性能代码做隔离修补），multi-front GUI32/0含NPC友军、旧中立纠正后allies/enemies组、真实HUD绿色与✓，field23/0，rescue11/0，共66。日志reports/friendly-hud-visual.log、field-friendly-final.log、expedition_rescue_progress_regression-friendly.log，全部无脚本错误。view_image已看friendly-npc-green-tasks.png：左上支线绿色、完成军需✓，失败救人✗。截图之后去掉失败者后续支援承诺，再跑field23干净。UI失败者仍提示胜利+35是潜在语义瑕疵（用户本轮未提，后续可把失败奖励写未获得）。

源码未打包提交，不写玩家档。持久记忆100条满，项目交接已落盘。

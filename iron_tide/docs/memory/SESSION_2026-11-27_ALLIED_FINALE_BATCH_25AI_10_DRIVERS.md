# 《脑死》批量：25 地图 AI / 10 正式触发

续 BARRACKS_RETURNS，Steam `ALL07SMD` 解包索引 SHA `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`。双表 `ALL07SMD_SCRIPT_RECHECK.tsv`、`ALL07SMD_AI_RECHECK.tsv`：新增 10 条正式任务驱动 60→70/88，剩余 18；新增 25 条地图 AI 选队 23→48/84，剩余 36。任务新增是把已有编队与航行适配移进原图驱动，不是另造十支队伍。未逐条证明全等价。

- `export_allied_script_slice.mjs`、`allied_finale.gd`、`allied_finale_ai.gd`、`allied_retail_script.gd`：步兵 `0960D93C/0464C5FC/0B7AE1EC/0B2E9EDC/0B829CAC` 和装甲 `09713F3C/0B8000CC/0B80C2BC/0B82737C/0B807B1C` 由新开局真实任务表驱动，条件、计时、后续 ID 从零售表走；完成卸载将对应联锁变量送给驱动，动作7调用已有编队及航线。允许原图显式重启这些行和 Confed_Check，不给无关触发器统一清锁。卸载联锁适配及失艇推进不宣称原版逐帧，尚未跑完五队回环；返航触发仍保留此前单次+兜底。存档无 raid_driver 继续原调度，不追刷初始指令。
- `export_allied_finale_ai.mjs` 加25条南极两房队，选队数据留权重、条件、编组、脚本。兵营/车厂按可供应产品排队，混编不再只能由车厂处理队首。其余已有条件、前置和房经济适配不变。未逐队验全部比较、行动与抵达交火，未碰新贴图或声音。

Godot 4.7.2 菜单、隔离 APPDATA、隐藏无头，`tests/allied_finale_playable.tscn` 主线 59/59、兵营40/40、第三房车厂42/42、支线59/59、新版 `--enemy-ai` 28/28、`--cold` 5/5、slot4/slot5真实副本各8/8。测试用夹具加速、放厂等；证据首个步兵登陆正式驱动触发、实际航行卸载命中及 AI 编队真实下单扣款与出厂。旧档复跑最初命中并行修改的苏军07未导入资源产生的解析日志，Godot编辑器重新导入后两旧档重跑均退出0、stderr空，未改苏军代码。日志 `.validation/finale-25ai-10drivers/`。未验装甲新档全循环、十条和25条逐项自然通关、未改玩家档或发行包。
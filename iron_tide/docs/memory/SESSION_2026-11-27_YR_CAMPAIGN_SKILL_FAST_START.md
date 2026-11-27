# 尤复战役移植技能：快速入口

用户澄清目标是把《脑死》经验变成后续可直接学习和调用的移植技能，而非继续验剩余 AI。更新 `docs/skills/yr-campaign-porting/SKILL.md`，入口按新关／续作、地图、存档与 CG、AI 批验分流；`references/workflow.md` 提供最小真实战场链、双表和交付模板，`references/headless-evidence.md` 提供逐 ID、固定步长、超时分流和 seed/cold 方法，`references/full-checklist.md` 保留仓库原完整规范（仅移除技能元数据）。具体关卡进度留在项目记忆，不写进技能主流程。

从沙箱暂存目录用 `install_skill` 覆盖安装同名技能，随后 `load_skill` 实测读到新版及三份参考文件。未改游戏代码、未动存档、未跑 Godot；尚未用另一张新地图端到端试跑新版流程。《脑死》余下 44 条继续挂起。

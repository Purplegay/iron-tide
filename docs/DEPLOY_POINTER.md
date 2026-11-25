# 大兵鼠标部署（2026-10-23）

后续：GGI 已增加 Q 部署与 W 固守固有技能，见 [GGI_SKILLS.md](GGI_SKILLS.md)。下文“没有技能栏”是本次鼠标部署改动前的历史诊断。

用户反馈重装大兵无法通过鼠标部署，并要求悬停时显示部署标记。
实际 GGI 的 D/命令栏入口和部署双武器已经存在；缺口是战场鼠标只有选择语义，
cursor 的可交互判断也始终返回 select。GGI 的状态和移动拒绝提示还沿用了 GI 的卧倒文案。

本次更新：首次点击选中；选中单个己方可部署步兵后，再次普通点击自身切换部署/收起。
只有单击释放时才执行，按下与悬停都不改变姿态。框选和 Shift 加减选继续只改变选区。
350 ms 内的第二次选择点击仍优先选择同类，不额外切换姿态；该窗口内光标保持选择提示。
鼠标和点击共用 pointer_deploy_target：单选、己方、存活、可见可点中、无眩晕/维修，
且没有技能瞄准、建造或显式命令。运输、基地车、返航等其它 D 操作不因本次被加入鼠标部署。
多选仍用 D 或命令栏部署，不会因点某个已选成员意外部署整组。

GGI 的实际行为为部署导弹：固定、反装甲/防空；收起后恢复机枪和移动。
GI 仍是卧倒据守。GGI 状态文字与移动拒绝提示改成部署导弹/先收起，
不再提示寻找该单位没有的技能栏主技能。部署不消耗扩展技能的冷却。

从本地 RA2 MOUSE.SHP / MOUSEPAL.PAL 补充 deploy（110/9）、deploy_infantry（239/10）、
undeploy（120/9）三组动画；原有 45 帧全部保持原位置，最终 73 帧。
帧位参考 [OpenRA RA2 cursors.yaml](https://github.com/OpenRA/ra2/blob/master/mods/ra2/cursors.yaml)，
只取帧位语义，不复制其交互实现。原始 SHP / PAL 哈希与此前一致。

已确认的旧选择测试按本次用户新要求调整：选中后普通点击从“只选择”改为“部署”；
首次选择、框选、加减选、双击同类、技能冷却、D、HUD、鼠标拖图的独立断言继续保留。
验证使用实际 Viewport.push_input → battle/HUD，GGI 战斗专项另查真实弹体、武器和生产。
截图及最终验证记录：`C:/Users/admin/Temp/iron-tide-deploy-pointer-20261023/`。
用户旧游戏不被关闭；重开原启动脚本加载。体验待使用者确认：`pending_user_visual_confirmation`。

最终同一源版本 590 项通过：部署鼠标 102、GGI 真实生产/部署/武器/弹体 152、
原有鼠标 62、选择与输入归属 274。鼠标与输入三项使用真实 OpenGL 渲染，GGI 战斗专项为 headless。
四轮独立工程/custom_user_dir；端口、网络服务与 DB none。实际工程 editor import 通过，
四轮源指纹一致且交付时再次逐文件核对；最终日志无 SCRIPT ERROR / ERROR / WARNING。
早期 GGI 运行曾出现 ObjectDB 退出警告，本轮最终日志无警告不等于修复全部历史泄漏。
详情见外部 `delivery-audit.json` 和 `*-final/reports`；不将早期候选计入最终 590 项。

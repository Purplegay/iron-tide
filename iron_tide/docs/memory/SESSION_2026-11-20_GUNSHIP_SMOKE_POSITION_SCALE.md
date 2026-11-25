# 先锋炮艇烟雾位置与比例修正

用户指出先锋武装炮艇 R3HARBINGER 烟雾位置不对且仍太大。此前淡入处理没有解决该问题。

生产修改 scripts/units/ra3_damage_state.gd：
- 炮艇专属烟雾尺寸系数 0.24→0.08（直径为上一版三分之一），其他单位保持0.24。
- 粒子记录 bone；炮艇使用当前 model.bone_world(row.bone)，不再使用出生时缓存的世界位置。其他单位仍使用原 birth origin。
- 炮艇 tick 先 model.sync_pose()，使挂点使用当前航向和飞行高度。
- 不重复更改1.5投影比例：model.project本身的比例与粒子比例一致，未证实二次放大。

tests/ra3_mirage_conditions_regression.gd 增加专属比例与真实炮艇粒子回归：生成粒子、移动180/100并转向90度后旧粒子依附当前损伤骨骼、实际直径符合0.08比例。

证据 C:/Users/admin/AppData/Local/Temp/iron-tide-gunship-smoke-20261120-c/reports：渲染44 checks/0failed，exit0，godot.log无脚本错误；source_unchanged=false（并行源修改），因此不是完整干净验收。前一b运行有无关uprising_threat_meter.gd类型推断错误，不计干净通过。已查看c/gunship-smoke-corrected.png，炮艇可见，没有先前巨型黑云，烟雾非常淡；单帧不证明动态视觉完全满意。

本轮只修改上述生产脚本和条件回归对应位置，未提交、未打包、未动玩家存档。保留用户其它并行改动。

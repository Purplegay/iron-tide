# 远征战斗信息面板紧凑化

用户反馈远征状态/支线/操作大面板遮战场。scripts/expedition/runtime.gd::install_hud 将面板从(270,100)移到(8,112)，默认宽300逻辑像素，默认三行：可点击的关卡/维修包/展开标题，目标摘要，增援摘要。支线详情及全部原操作移入默认隐藏的VBox，展开时两列按钮、支线自动换行；再次收起将panel.size归零触发最小尺寸恢复。status对过长文字裁切并提供完整tooltip。护送车队按钮放在详情区。未改任务、增援、维修、存档、撤离规则。

tests/expedition_compact_hud_regression.gd/.tscn真实远征启动、默认紧凑bounds、增援可见、展开窄宽、收起恢复共9/9通过exit0。已查看compact.png与expanded.png，左上三行与窄列详情符合预期。证据 C:/Users/admin/AppData/Local/Temp/IronTideCompactHud-9d54472df1994f43992766fc749cf1f3/report/，最终日志 .validation/compact-run2.log 无脚本错误。

验证限制：第一次复制当时生产scripts，Unit._enter_tree调用Battle不存在的_place_simulation_lane_deferred，属于并行单位调度改动，首跑不作验收。最终采用上一轮已验证OriginalSoviet副本scripts为底座，仅叠加当前runtime.gd及新测试，9/9为该隔离组合结果，不宣称当前全部工作区集成通过。未修改调度代码、玩家存档，未打包提交。未测12关原存档、多分辨率和展开情报栏的碰撞。

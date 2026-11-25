# RED ALERT 原生槽体与上弹按钮

用户要求完整起义进度指示器、按钮从上方弹出，最后截图验收。修改 scripts/ui/uprising_threat_meter.gd、uprising_red_alert_button.gd、expedition/runtime.gd。

使用 experience_panel.png 完整阵营槽体（218x94，233,0 / 233,96），仅在原生玻璃区域裁剪点亮威胁进度，移除自绘20段框。槽体保留比例；移除外层自制面板与横排文字。固定警戒dock占位（left8 top-416 bottom-226 right226），与小地图及选择栏分开。按钮可用时以约0.26秒从槽体上方升起，未就绪/总攻时隐藏收回并忽略鼠标。就绪/激活音效与原玩法保留，不修改威胁计算。

新增 tests/red_alert_ui_acceptance.gd/.tscn，通过正常场景加载真实战斗、远征runtime与HUD。独立 project.godot 开启 custom_user_dir CodexIronTideValidation/RedAlertFinal，资源目录junction，共享现有资源，玩家正式存档不操作。副本路径 LOCALAPPDATA/Temp/CodexIronTideValidation-RedAlertFinal。

最终正式远征GUI检查14/14通过，exit0，包含充能隐藏、就绪上弹、选择单位不移动/不激活、dock不交叠小地图/选中栏、主动按钮激活、进行中收回，以及三张渲染截图保存。证据 .validation/red-alert-ui-acceptance/{charging,ready-selected,active}.png、result.json、final.log。已实际查看三张截图。初次副本仅缺icon.ico窗口图标提示，无脚本错误。截图为盟军远征夹具；未测苏联截图、完整玩家操作整局、多个分辨率。UI依原素材实现，未逐帧验证原版动画完全一致。

此前桌面黑屏截图ui_acceptance.png与临时skirmish red-alert-ready.png不是最终验收；起初裸SceneTree脚本无autoload失败，改正常Node场景解决；第一次基于环境变量的存档隔离检查exit2，未执行写档。最终使用独立项目配置隔离。

生产项目存在大量并行未提交修改，未回滚覆盖，未提交打包。用户最终截图视觉验收待回复。

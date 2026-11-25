# v0.25.49 · 技能顺时针冷却进度

技能按钮新增 `skill_cooldown_clock.gd` 绘制层：从顶部开始，顺时针经过右、下、左，青蓝圆环显示已恢复进度，尚在冷却的扇区压暗。中央原有剩余秒数和热键保持在上层，并为秒数增加暗色描边。冷却结束恢复完整图标，无冷却的开关、空槽与单纯受控禁用不显示计时。

覆盖技能栏单位 Q/W/E 以及磁暴线圈 W。读取技能现有 `cd_left` 与冷却时长；装配技能按原有 `Training.card_scale` 冷却缩短规则计算分母，原生技能使用原有运行时描述。切换选择、读档重建按钮均直接读取当前值，不另建倒计时。绘制层忽略鼠标事件，仅在进度变化时请求重绘，没有新增每单位计时器、存档字段或战斗规则。

## 验证

- `skill_clock_regression`：21 项通过；实际 HUD、四个方向节点、剩余秒数和禁用、就绪隐藏、受控不虚构冷却、重建选择和磁暴线圈进度。
- `tesla_pulse_regression`：77 项通过；新增覆盖层未破坏 W 释放、冷却、存读档或装配入口。
- 通过 `CreateDesktopW` 私有桌面、`CREATE_NO_WINDOW` 运行实际 Godot 渲染，不切换用户桌面。确认 0／25／50／75% 对应上／右／下／左，100% 恢复图标；日志无渲染异常。
- 全部测试使用隔离 APPDATA。建筑 UI 回归退出时仍有原有 FontAdvanced／CanvasItem／ObjectDB 释放警告，无脚本异常。没有打开用户可见窗口，没有修改真实存档。

证据目录：`C:/Users/admin/Temp/irontide-tank-heroes-20261105-133253/` 下 `skill-clock-check`、`skill-clock-coil`、`skill-clock-visual`；实际渲染截图为 `skill-clock-visual/clock.png`。

本轮未打包、提交或推送 Git。保留并行更新 v0.25.48.1 的天赋购买改动。

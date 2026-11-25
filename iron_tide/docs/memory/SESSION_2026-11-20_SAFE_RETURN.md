# 2026-11-20 远征安全返回

- 战斗 HUD 的远征返回按钮改为“保存并返回”，进行中的远征通过 runtime.save_and_leave 先写 checkpoint，成功后回远征界面；失败留在战场并显示错误。
- Esc 同样调用 HUD._leave，因此也走保存路径；回调尚未就绪时拒绝离开。非远征行为不变。
- Godot headless editor 启动输出未发现 SCRIPT ERROR、Parse Error 或 ERROR；尚未实测完整战斗、存档失败及冷读档。

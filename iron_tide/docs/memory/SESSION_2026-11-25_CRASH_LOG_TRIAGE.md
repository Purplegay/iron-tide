# 闪退日志核对

附件 logs.zip 内两个文件的修改时间为 2026-10-23 19:33 和 19:41，设备为 RTX 3070 Laptop GPU。godot.log 中 14 个 RA2 JSON 加载失败，mouse.png 缺失导致 SHEET 解析失败、战场脚本编译失败，另有 727 次矿石和宝石贴图加载错误。结尾在生成矿点，没有进程崩溃栈。当前工作区抽查 mouse.png、ore-1.png、ra2_allied.json、warheads.json 均存在，脚本行号已经变化。

本机为 RTX 5060 Ti。2026-11-25 18:58 的玩家日志仅有引擎和 CPU 设置，最近三次启动导入日志未见 ERROR 或 SCRIPT ERROR。Windows 事件中 12:14:43 的 IronTideRuntime.exe 有访问冲突 0xc0000005，偏移 0x2d3ee83。尚待用户提供事故设备、时间和操作来匹配。未复现或修改游戏和玩家存档。

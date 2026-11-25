# 2026-11-20 启动解析错误修复

用户启动日志 C:/Users/admin/AppData/Local/IronTide/startup-logs/20261120-133117-2b70ae06-import.log 报 scripts/expedition/campaign.gd:128 Cannot infer type of request_multi。

仅将 var request_multi:=... 改为 var request_multi:bool=...，表达式与多敌军路线规则不变。route==result[-1]涉及未定类型数组元素，显式bool避免推断失败。未覆盖已有并行改动。

实际执行Godot 4.7.2 --headless --editor --path C:/Users/admin/IronTide/iron_tide --quit，退出0，自动加载及脚本类注册完成，无SCRIPT ERROR或ERROR。日志保留于本会话sandbox startup-typecheck.log。属于启动导入检查，不代表完整游玩/路线行为回归。用户可重新运行原启动入口。未打包提交。

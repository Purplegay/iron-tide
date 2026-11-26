# 洛杉矶尤里基地

依据本机 ALL02UMD.MAP 按原房号与格坐标布置九类敌设施，落点沿用任务可建地搜索。新开局实测 YAGRND 4、YAGGUN 32、YABRCK 3、YAPOWR 20、YAWEAP 2、YACNST 1、NATBNK 9、NAPSIS 1、CAOILD 1。钻油井使用原有收入机制，地图布景跳过对应中立副本。生物反应炉取关卡覆盖值 300。回收厂挂既有居民路线、资金箱、侦察及渗透流程。盖特机炮使用原版主体和旋转炮塔，按目标域与持续跟踪时间选择武器。坦克碉堡用一辆 LTNK 取代前次 INIT 驻军，使用坦克自身火炮和原版碉堡加成。当前驻堡车型限狂风。本次为任务专用单位及建筑定义，可用 tools/hollywood_yuri.mjs 从游戏档案和原图重新导出。

Godot 4.7.2 隔离 APPDATA 从大厅任务卡进入，tests/hollywood_campaign.tscn 胜利 47/47，失败 48/48，退出 0，日志无 ERROR。含九类数量和主体贴图、狂风驻堡及伤害加成、四厂闪烁和资金箱、快照校验及胜负。首次胜利发现钻油井 NewUrban 废墟缺图，修正城市废墟回退后复跑通过。日志 %TEMP%/it-hollywood-sites-final-win.log 和 it-hollywood-sites-final-loss.log。未逐项实测盖特三档实弹、渗透、逐栋动画或冷进程读档。兵营、工厂、建造场以任务设施接入，完整生产树、心灵感应器专属探测和反应炉装载仍待后续工作。未打包。

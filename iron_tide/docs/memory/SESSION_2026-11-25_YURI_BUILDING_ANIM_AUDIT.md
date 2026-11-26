# 洛杉矶尤里建筑动画检测

从任务大厅进入 yr_hollywood，对原图实际加载的 8 类尤里设施及共用钻油井，在满血和 40% 血量读取主体帧、图层可见性、健康变体和帧区间。对照本机 Steam artmd.ini。八类尤里设施均声明 Buildup，实测 _buildup_art 全空。任务导出器 tools/hollywood_yuri.mjs 仅枚举 idleanim、activeanim 和后三个 active 变体。主体在两个血量档均从 0 切换到 1。

|建筑|实测及原版差异|
|---|---|
|回收厂 YAGRND|漏 idleanimtwo、specialanim。已加载 idle 正常及损伤均选 0..11，但前景仅 11 帧。active 正常仅 0..1。|
|战车工厂 YAWEAP|已有健康/受损 active 贴图，漏 deployinganim、underdooranim、roofdeployinganim、underroofdooranim。|
|建造场 YACNST|漏 productionanim。idle、active 受损末帧分别选 2、6，各自前景数仅 2、6。|
|坦克碉堡 NATBNK|任务已载入驻堡狂风坦克，建筑动画层为空。原版定义 specialanim 一至四。未判定四层的驻车时序。|
|心灵感应器 NAPSIS|正常 0..39，受损 40..80，前景只有 80 帧。|
|兵营 YABRCK|常驻层正常 0..7、受损 8..15。|
|生物反应炉 YAPOWR|空炉显示 A 和灯光 C，B 隐藏。正常、损伤帧分开。已有按 occupants 切换 A/B 的逻辑，本轮未实际装兵。|
|盖特机炮 YAGGUN|原版无常驻动画图层，项目独立绘制炮塔。未逐档实弹验证。|
|科技钻油井 CAOILD|原图尤里所有，定义为 civilian。共用已有油泵及旗帜图层。|

Godot 4.7.2 headless 从 tests/hollywood_campaign.tscn 进入，新增用户参数 `-- --building-animation-audit`，独立 APPDATA。日志 `%TEMP%/it-yuri-anim-audit-console.log`，18 条 SITE_ANIM，退出 0。返回码只代表场景和既有断言正常，帧区间用于诊断。检查的是运行时选层和帧数据，未进行逐帧屏幕像素对照。此次只加检测入口，未改游戏资源、生产逻辑或玩家存档。范围为任务已实例化设施，不包含原版尚未出场的尤里全科技树。

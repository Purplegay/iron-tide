# 战役小地图互动核查

未改生产代码。战斗 HUD 共用 `scripts/ui/minimap.gd`：左键点地图有效区或拖动调用 `Battle.center_on`，不改选择；任务提示可悬停。没有右键下令入口。战役选关 `scripts/screens/campaign_command.gd` 的作战地图是静态 TextureRect。好莱坞雷达依照 `hollywood_mission.gd` 的雷达建筑/供电状态启停；暂停、剧情简报门控和风暴干扰限制输入。战役小窗影片 `scripts/ui/hollywood_film.gd` 在雷达上加独立 ColorRect 与播放器，未转发地图输入；与已支持点击穿透的远征通讯头像不同。参考 `refs/ts-ra2/src/gui/screen/game/worldInteraction/WorldInteraction.ts::executeMinimapClickCommand` 区分移动键设定、指令和镜头定位，尚未移植到此控件。

Godot 4.7.2 隔离用户目录，运行 `tests/minimap_regression.tscn`：headless 133/133；图形窗口 144/160，失败 16 项全部为四种机位的镜头框像素断言，非交互断言，未排查像素失败根因。此现有回归用遭遇战加载共用 HUD，未实机逐关核验雷达、战役影片和供电切换。结果在 `%TEMP%/IronTideHeroMinerBox-20261126/campaign-radar-audit{,-headless}/`。未改存档或打包。

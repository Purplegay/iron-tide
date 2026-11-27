# 盟军首关：主战场保护时光机黄点

玩家澄清截图问题是主战场没有黄色任务目标提示，不是模型错位；同图小地图已有目标。检查 `AlliedFirst.marks` 确认防守阶段仍生成 CATIME01 的目标。旧主战场标识和命令预览共用 Node2D 层，位置从美术中心减固定像素；不能从无头断言旧图缺显的唯一原因。

`battle.gd` 将支持的战役主战场任务点移到独立 `CampaignObjectiveCanvas`（层 1，战场/迷雾上、HUD 和影片下），不与命令预览共享画布；正常帧和窗口尺寸变化刷新。`campaign_objective_marks.gd` 用战场相机投影真实建筑可见轮廓上边缘，黄菱形抬高 48 屏幕单位避开血条；未公开对象不取隐藏精灵数据。小地图仍用地面坐标。没有改模型、占地、任务阶段或存档。

Godot 4.7.2 隐藏无头隔离 APPDATA，`tests/allied_first_playable.tscn` 29/29，独立进程 `-- --cold` 5/5，退出 0、stderr 空。前者由供电夹具进入阶段，断言任务实体、独立层、坐标和小地图不漂移；冷读验阶段恢复。证据 `.validation/allied01-playable/marker-{write,cold}.{out,err}`。未开图形窗口、未验截图最终像素或其他战役完整显示、未修改玩家存档/发行包。

# 用户存档2/3性能与源码对照（未完成）
用户明确要求对2/3号档优化，尽量依Yuri或网页RA2源码解析，允许重构。此授权持续，不必再问是否开始。任务尚未完成，生产未合入任何优化。

输入复制于iron_tide/.validation/save2-save3-20261120/inputs：原路径APPDATA/Godot/app_userdata/Iron Tide RTS/battles/slot2.itsave SHA ec911749e4c2effb5ae4885b4dd7c35e98185aa4ccab6befc1314e4ea388e125，slot3 SHA8a9bb4d7b37eb8689bfca8be9e291318fc739875dc1bc602ba28fabc8de003ca，meta59511字节SHAa8d9643ec06bfe917300f4190161608fce422cacf1d20fd4a2eeca24b8abec90。最终原档hash未变。

参考已读refs/ts-ra2/src/game/gameobject/GameObject.ts（cachedTraits.tick、addTrait注册、update仅遍历注册trait）、engine/RenderableManager.ts（spawn/remove/position events）、engine/gfx/OctreeContainer.ts（视锥与位置更新）、gfx/RenderableContainer.ts（renderQueue）、util/QuadTree.ts。并读refs/ra2yr-resource/src/structure/building.cpp的Update、unit.cpp的PerFrameUpdate、system/cell.cpp的局部对象列表入口。Yuri复原库很多stub/反编译片段，不能把Building.Update两行stub当完整引擎。此前commentary误称OpenRA：本机未找到OpenRA，只用了ts-ra2与Yuri复原代码。

首次base-slot2错误传编辑器为--release-template，私有桌面无窗口，数据无效。headless-slot2与profile-slot2用了mirror-player-growth改变AI卡牌，仅辅助诊断，不是玩家原场景基线。调试headless每帧数秒；native profile仅6帧、36.161墙钟/17.8模拟，不能精确推收益。slot2初始371单位218建筑5AI。

real-slot2-base正确Release IronTideRuntime.exe，无mirror，meta副本，私有桌面30s：mean77.235/P95128.671ms。配对slot2 a1/b1/b2/a2 mean76.244/80.739/81.803/76.855，P95120.173/126.535/140.360/120.159；slot3 a1/b1 mean72.943/72.642，P95115.390/110.863。host-cpu审计发现外部用户IronTideRuntime PID34736，不能作干净验收；发现后停止自有runner25884及匹配本轮命令行的python42872/GodotRelease51488，未动用户游戏。slot3 b2/a2未完成，不宣称ABBA完成或收益。

候选candidate/scripts/units/auto_w.gd：仅Expansion.SUPPORTED分支按需调用contacts（13种中只有tidal_decoy/bomb_nests/ink_mine读取enemies）；其它不查询。回归auto_w402/402、unit_neighborhood121/121，exit0无ERROR。整帧无证明收益，不推广。不是先前禁止的eligible固定名单/空状态早退。企图改contacts复用neighborhood未实现/未验收；顺序与跨epoch语义尚未证明，不要直接换。

重大操作纠正：误整文件write生产auto_w.gd，范围超出目标；已从base-slot2冻结副本逆转soak_player_growth wrapper与side/tech hooks并按原source-sha256完全恢复，最终生产auto_w SHA4c5de4bf13319202ae17c6ec52b408a6121c35691d6ce9e8207033dab18d4e58。不要用git HEAD覆盖，其与本轮开始文件不同。control/candidate仅隔离实验，不可整体覆盖生产。

saved_probe.gd及saved_probe.py工作量计数三次work/work2/work3超时且脚本preload循环失败，无有效计数，所有结果作废。最初怀疑静态字段错误，移除后仍错，确切根因未解。使用已有成功soak入口或auto_w_regression夹具继续，不再复跑坏夹具。

后续：当前玩家外部游戏存在时不做整帧验收、不要求停止游戏，可继续代码审计/行为测试；干净环境下重建两个存档正确Release基线，按实测热点做结构候选。不得重复eligible固定名单、空状态早退、碰撞局部复用、depth微优化等已否决方向。用户授权重构；不能把改AI卡牌、关建筑、降兵力或降模拟速度算优化。新增改动须控制变量与回归。全局持久记忆100条满，本记录为交接。

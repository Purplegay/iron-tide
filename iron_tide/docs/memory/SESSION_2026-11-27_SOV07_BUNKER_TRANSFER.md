# 首脑游戏：开局进堡与解放时驻军保留

用户截图已解放 1/2、步兵围在战斗碉堡门外。零售 SOV07（eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4）的 BG3/BG1/BG2 Bunker Boys Go 为 `09389BBC/093A68FC/093A633C`，见 SOV07_TRIGGER_INDEX。项目 `head_games_orders.gd` 原已读 `data/head_games_orders.json` 发 `allied_garrison`，不是完全没脚本。未用截图推断是哪批确切人物或读取玩家档。

复现：真实开局试把苏军步兵登记进苏军预置堡，初始通用建造动画让 is_operational=false 导致失败；另旧通用 change_side 对带驻军建筑易手先紧急撤出，解放一翼因此会把同翼守军也弹出。`head_games.gd` 预置设施一开始就完工；解放时仅当活驻军全归同一翼、且实际在该建筑内，跳过通用撤出，两者按原有解放循环一起换边。异房驻军及普通占领不改撤出。`allied_abilities.gd` 在已搭载单位换边后同步非地面可攻击目标组，不把堡内人员加入地面目标。

Godot 4.7.2 无头真菜单隔离 `tests/head_games.tscn -- --bunker-transfer` 4/4（首次登记失败，修后测试直接调用真实入堡操作夹具，摧毁对应信标并核对保持堡内）；`-- --orders` 18/18，额外验开局脚本经物理步派兵进入碉堡（至少一座，不是八座逐个）。退出0、stderr 空，`.validation/s07-bunker-transfer/`。未验玩家已空堡的旧档自动重入（不替玩家强制下令）、逐堡容量/寻路或独立冷读，未动玩家档或发行包。其它既有进驻触发、地图 AI 与素材未作整关验收。

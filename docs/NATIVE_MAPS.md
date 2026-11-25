# 尤复原版地图导入

当前读取本机 Steam 安装中的 `IsleLand.yro`、`Ice_Age.yro`、`CrctBrd.yro`、`DeepFrze.yro`、`RiverRam.yro`、`MojoSprt.yro`，不是用原版名称包装随机地图。安装目录只读。

v0.29.0 另导入 Unrepent.yro、IrvineCa.yro、MonsterM.yro、Transylv.yro、HighExpR.yro、MoonPatr.yro，共十二张。新增六图用于遭遇战和远征；远征明确显示原图触发器由本轮目标替代。

远征地图池现有十八张尤复原版地形。下表末六张取自 Steam 版 `multimd.mix`。在上述导入器后加 `--multimd` 可按原始成员文件名提取，之后沿用相同的烘焙和 Godot 导入步骤。地图数据分别保存容器名称、容器哈希和地图成员哈希。

| 菜单 | 原名 | 地貌 | 原图出生点 |
|---|---|---|---|
| 尤复 · 陆中群岛 | Islands on the Land | 温带 | 6 |
| 尤复 · 冰河世纪 | Ice Age | 雪地 | 6 |
| 尤复 · 电路板 | Circuit Board | 都市 | 4 |
| 尤复 · 深度冻结 | Deep Freeze | 雪地 | 4 |
| 尤复 · 狂暴河流 | River Rampage | 温带河谷 | 2 |
| 尤复 · 魔力之魂 | Spirit of Mojo One | 雪地海岛 | 4 |
| yr_unrepent | Unrepentant | TEMPERATE | 6 |
| yr_irvineca | Irvine, California | NEWURBAN | 8 |
| yr_monsterm | Monster Movie | TEMPERATE | 8 |
| yr_transylv | Transylvania | NEWURBAN | 6 |
| yr_highexpr | High Explosive Round | DESERT | 6 |
| yr_moonpatr | Moon Patrol | LUNAR | 4 |
| 尤复 · 隐秘山谷 | Hidden Valley | 温带 | 2 |
| 尤复 · 沙丘巡逻 | Dune Patrol | 沙漠 | 2 |
| 尤复 · 干热沙地 | Dry Heat | 沙漠 | 4 |
| 尤复 · 零点城区 | Ground Zero | 新都市 | 4 |
| 尤复 · 四角战区 | Four Corners | 温带 | 4 |
| 尤复 · 埃及之旅 | Tour of Egypt | 沙漠 | 6 |

目前适配双人遭遇战：使用首个和距它最远的出生区；原始 waypoint 不保证预建基地占地完整可建，因此在该出生区内找可用落点。保留原图地形格尺寸，不应用自制地图的小／中／大缩放。地图选择使用稳定 ID 保存，新开局消费选择；载入旧存档仍是旧地图。

## 处理链

1. `ra2pipe/native_map_source.mjs GAME_DIR OUTPUT_DIR` 使用既有 MIX 解包器读取 `.yro` 地图、theater INI、TMP、桥梁 SHP、调色板、rulesmd/artmd。
2. `python ra2pipe/native_maps.py OUTPUT_DIR iron_tide` 解码 IsoMapPack5 / PreviewPack 的分块 LZO，以及 OverlayPack / OverlayDataPack 的 LCW；需要 Pillow、lzokay。
3. 输出 `data/maps/yr_*.json`、`assets/maps/yr/*_terrain.png`、`*_preview.png`；JSON 记录原文件和 archive SHA-256。
4. `native_maps.gd` 将原始水陆、障碍、桥面、矿格、出生区和已支持的中立建筑交给当前 Godot 战场。地表与战术地图使用同一张烘焙图；原图自带缩略图用于大厅预览。

地形字段参考本机 FinalAlert2 Source Code 中 `MissionEditor/Defines.h`、`Loading.cpp` 和 XCC TMP 头：`0x0c` 是土路，不是岩石；`0x0f` 不可通行，`0x09/0x0a` 为水域。OverlayTypes 的索引按条目顺序，不能把 INI 的数字键直接当索引。IsoMapPack5 记录数按实际解压字节数读取，不能强制等于地图面积：River Rampage 原文件省略 28 个 clear 格（可玩区域内 12 格）。参照 FinalAlert `MapData.cpp` 的 `Unpack` 和 `FIELDDATA` 默认值，以 0 高度 clear 格补齐缺省格；保留已存记录顺序。TMP 透明像素不直接绘制调色板 0；额外地形图层与桥梁覆盖层需要另行合成。

上游格式说明：[EA Mission Editor](https://github.com/electronicarts/CNC_TS_and_RA2_Mission_Editor)、[OpenRA Gen2 importer](https://github.com/OpenRA/OpenRA/blob/bleed/OpenRA.Mods.Cnc/UtilityCommands/ImportGen2MapCommand.cs)。本工程使用现有 Godot 战斗规则，并未移植原版游戏引擎。

## 已知适配边界

- 地形高度和坡道数据保留在 JSON，但移动、碰撞及地表仍为平面适配，未实现原版逐格高低差遮挡。
- 桥梁损毁按本工程 55 世界单位的一格桥段处理，修复恢复原始烘焙贴图；断口使用本机 Yuri 的 LOBRDG08/09、17/18 及损坏桥头 SHP，桥下露出原 TMP 地形。仍未实现原版桥下高度遮挡。
- 只生成已有可用模型的中立建筑，开局基地占用处跳过；尚未完整接入原图树木、围墙、全部都市物件和任务触发器。部分科技建筑只有建筑实体，未实现其原版特殊收益。
- 水面是原始地表贴图，没有原版逐帧水面动画。不是尤复完整地图渲染器。
- 后续变更导入地形 JSON 会触发新原版地图存档的地图指纹校验；不静默把旧对局载入另一套地形。非原版地图旧存档不新增此要求。

`SinkSwim.yro` 暂未上架：它依赖定时扩大 LocalSize 的脚本，静态裁剪会缺少后续区域和中立设施，部分出生区陆路不连通。不能将静态小图冒充完整复原。Deep Freeze 的地图自定义炮台及其他地图局部规则覆盖也尚未移植；本轮只增加地形适配地图。

## 桥梁损毁素材

`python ra2pipe/bridge_art.py SOURCE_DIR iron_tide OUTPUT_DIR` 复用上述只读提取结果，输出桥梁地图的 TMP 底图、桥梁帧图集和独立元数据。导出器必须先验证完整桥面重新合成与现有 `_terrain.png` 逐像素相同；仅接入新增的 `*_bridge_ground.png`、`*_bridge_atlas.png`、`*_bridges.json`，不修改地图 JSON、存档地形指纹或原始地图贴图。

运行时 `native_bridge_art.gd` 在载图时预载底图，桥梁状态变化时合成受影响桥梁的小区域；删除断段并按邻接断口选择原版边缘，保留原 OverlayData 的空白占位帧。修复后移除补片。原版地图禁止再叠加 `civilian_site_visual.gd` 的程序桥面，自制地图仍沿用原有显示。专项入口：`tests/bridge_art_regression.tscn`，覆盖温带／都市、横竖桥、单格／连续断口和保存恢复后的实际修复入口。

## 验证入口

格式夹具：`python ra2pipe/test_native_maps.py`。运行态：`tests/native_maps_regression.tscn`，必须在 `CodexIronTideValidation` 独立用户目录无窗口执行。覆盖地图选择、真实开局、路径连通、双层桥面、双方矿车出口、基地车开局、扩展模式、实际保存及新场景恢复、地形指纹拒绝与资源去重。搭配 `lobby_preferences`、`authored_maps`、`savegame` 回归。

## 六图扩展导出

`native_map_source.mjs GAME_DIR OUTPUT_DIR --expedition` 读取上述六个档案；`native_maps.py` 输出地图和预览，`bridge_art.py` 补齐 Unrepentant 原生高桥，`native_ore_art.mjs GAME_DIR OUTPUT_DIR --expedition` 导出新都市、沙漠、月球的真实矿物调色板资源。新都市扩展名使用 ubn；不同矿物变体画布尺寸按最大画布居中，月球没有矿井地物段是合法输入。

原图包含的触发、部队脚本、特殊胜负和任务事件没有执行：Irvine、Monster Movie、Transylvania、High Explosive Round 的场景语义不可当作完整原版关卡复刻。当前交付是实际地形与资源适配，配合 Iron Tide 的遭遇战或远征规则。

## v0.30.35 高桥补齐

Unrepentant 的 43 个 BRIDGE1 桥面格此前漏烘焙，导致两处长桥仅有桥头、车辆看似行驶在水上。高桥资源通过 Image 别名读取 BRIDGE/BRIDGB SHP，两个方向分别使用 0～8、9～17 帧，排除后半阴影帧；导出时归一化为各自的 0～8 帧。高桥平面锚点上移 45 原图像素，与现有平面道路及通行格对齐，不引入立体高度导航。

v0.30.43 补齐桥头／桥墩平面处理：Ovrps（包括 Ovrpsb）TMP 的扩展像素需补偿该子块到本文件最高道路子块的高度差，每层为 TMP 菱形半高。Unrepentant 的低层与道路差四层，即60原图像素；仅移动低层扩展像素，地面菱形、道路顶层和普通悬崖不改。`native_maps.tile` 为完整地形与 `bridge_art` 断桥底图共用入口，二者必须一起重新生成，避免损毁后重新出现错位。地图JSON、桥面SHP图集及元数据保持原字节。测试源 `ra2pipe/test_native_maps.py` 覆盖混合高度、木桥族及普通悬崖排除；本轮产物与验证在 `.validation/bridge-alignment-20261118/`。旧“补齐桥面”报告不代表桥头拼接已获用户确认。

导出单图可用 `native_map_source.mjs GAME_DIR SOURCE_DIR --expedition --map=yr_unrepent`。首次补漏时 `bridge_art.py SOURCE_DIR iron_tide OUTPUT_DIR --repair-missing-high` 只允许原地形与无桥底图逐字节相同时重建桥面；后续普通导出仍要求完整贴图逐像素相等。缺少高桥帧现在明确报错，避免再次静默导出空桥。地图 JSON、通行格和地形指纹保持不变。

高桥断口选择本方向的 7/8 帧，低桥仍使用既有 LOBRDG 资源。`high_bridge_regression` 覆盖两种模式下四段通行桥、43 格真实贴图、四类高桥方向与断口、坦克实际跨桥、损毁阻路、暂停读档和桥头维修；`high_bridge_visual_regression` 可通过 `IRON_BRIDGE_SAVE` 复制玩家存档到隔离目录，走正常读档入口并输出桥梁/断桥/修复画面。画面仍是平面地图适配，表现待用户试玩确认。

读取新增机场维修计时字段之前的存档时，仅接受除该字段外规则完全相同的指纹，缺省计时补为 0；校验和、其余字段及地图指纹继续校验，不改写原存档。

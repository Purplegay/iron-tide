# 单位模型显示与来源

## 0.32 原版体素单位的金属高光

盟苏载具沿用好莱坞关盖特坦克和狂风坦克的烘焙方法。依据是本机尤复零售引擎 `gamemd.exe` 的 `0x7586F0` 和调用点 `0x706F23`（参数 3），以及零售资源 `VOXELS.VPL` 和 `unittem.pal`。在每个朝向上，将原模型法线与主光、半程向量分别做点积。令漫反射为非负的主光点积，令 `h` 为截在 0～1 的半程点积，高光贡献为 `h / (3 - 2h)`。两项相加后乘 16、向下取整并限制在 VPL 可用行内，用该行映射体素颜色。主光按本项目图集相机的左上方向换算，房色沿原调色板索引换色。

车体、独立炮塔、炮管后坐与已登记的换装、部署、空架状态使用同一查表规则。原生和 2× 彩色图集烘焙后以 `palette_lit: true` 交给运行时直接显示，避免再次自动提亮。阴影单独绘制。SHP 步兵和生物使用原画各帧的明暗。此规则取代下文 v0.3.4 记录中对这些体素层使用的 0～8 级近似光照。

从仓库根运行 `node ra2pipe/vehicle_surfaces.mjs <尤复安装目录> <新候选目录> faction-voxels` 和 `node ra2pipe/defense_surfaces.mjs <尤复安装目录> <另一新候选目录>`。本次有 51 个盟苏模型及派生状态、4 座防御炮塔，共 70 个受光图层、142 张彩色图集。巨炮包含后坐图集，哨戒炮和防空炮保留用于点选的原生轮廓。

好莱坞关两份单位表共登记 7 种尤里单位。狂风坦克、盖特坦克、移动奴隶矿场各有车体和独立炮塔，加上固定盖特机炮，共 7 个 VXL 彩色图层，均有 32 个方向、原生图集和 2× 图集。两种盖特炮塔各保留 2 个转管姿态。奴隶矿场曾由任务人物导出器写成旧光照，现由 `hollywood_cast.mjs` 调用 `hollywood_turrets.mjs` 统一烘焙。部署后的 `YAREFN` 复用 `SMIN_turret`，按原版建筑挂点（−25，15）叠在 SHP 厂体上。尤里新兵、复制人、工程师和奴隶矿工沿用 SHP 帧上的明暗。

VXL 解析与光栅化测试 10 项通过，第二关 `--unit-states` 回归 110 项通过，包含矿场部署、采矿、收起和矿工保留。Godot 总览场景 `res://tests/faction_roster_gallery.tscn` 一次绘制 92 个条目，最下一排包含移动和展开矿场以及固定盖特机炮，采用本关敌军房色和材质。观感由使用者检查整张总览。[0.32 单位总览原图](fixes/v0.32/faction-roster.png)

## RA2／尤复专属皮肤开发准则

后续盟军、苏联专属皮肤，包括旧款重做，均以坦克杀手「猎隼外骨骼」作为创意与制作基准。每款都要回答两个问题：在正常战斗倍率下，玩家凭哪个部件认出这款皮肤？操作这个兵种时，哪个动作能让人记住它？

### 立项时先定部件与动作

- 从兵种本身选一个有辨识度的主部件，如固定主炮、矿斗或部署背架。画清它的轮廓、材质、如何固定，以及活动时跟随谁。只有换色、加亮或增加通用粒子的方案，继续打磨后再立项。
- 为这个部件选一个兵种常用动作，写清触发、变化和收尾。猎隼用起步带动叶轮高速旋转，蓝火先绕轮缘一圈，再汇成贴近车尾的短粗喷焰。焰腹在喷口后方，转弯只让尾端适度偏摆。进入射程停车开炮时收掉尾焰，原地瞄准和两发之间的装填也不喷火；重新行驶后再次点火。以后审查喷流轮廓时，用同朝向、同倍率的满推力画面比较长度和厚度。[猎隼尾焰前后对照](fixes/v0.25.21.1/jet-comparison.png)。矿车可以围绕装卸设计，部署步兵可以围绕展开和收起设计。新方案要有自己的动作和节奏。
- 在方案图上分别标明主件与辅件。猎隼的**主灯管在炮上**：四路插管从炮根绕至炮口，各自强跳、弱跳、回落。**两侧护板上的四灯慢呼吸**，约 5 秒一轮。战场选中或交火时持续心跳、呼吸和换色；未选中且脱战后用 3 秒逐渐减频并定格，再次选中从当前进度继续。工房可直接预览。八根灯都有贴近玻璃的亮边和向周围金属逐渐衰减的柔光外晕。以后做发光装具，逐部件说明位置、节奏和受光表面。[主炮与侧灯同屏动图](fixes/v0.25.20.1/tank-lights.gif)

### 制作与验收

- 外装甲的精细度应支持工房近看。让抱箍压住管壁、接头接入炮套、叶轮嵌在壳内；在金属、玻璃和发光芯之间做出可见的材质差异。适合用 AI 的高清表面、叶片或火焰可生成或复用，再贴到有挂点、朝向和遮挡的部件上。复用时保留素材来源和重建入口。
- 从该型号的 VXL／HVA 或 SHP 定位宿主。车体、独立炮塔、炮管和部署件分别跟随自己的朝向或动作。转向时焰根贴住喷口，焰梢按运动拖曳；停车有收尾。保持原生炮口、选取位置、阵营识别及战斗数值。每换一个型号，重新测挂点。[涡轮起步与转向动图](tnkd-turbine-ignition.gif)
- 交付时同时看**默认倍率的战斗辨识度**和**工房近景的材质与连接**。体素载具覆盖全部 32 向，SHP 覆盖实际使用的方向和动作。用真实命令验证招牌动作及过渡，尤其看正背面遮挡、转向或停车时是否脱离主体。保留一段能看清主辅部件的游戏内动图，分开记录工房演示、战场验证和玩家观感确认。

### RA2 人物皮肤的逐帧挂点与遮挡

- **先看人物实际画出的帧。** 对照该兵种的 SHP 和动作序列，在原图帧坐标内为背包、肩甲、镜筒标出肩背或关节挂点。站立、步行、开火、姿态转换都要跟随身体起伏。每个兵种重新选取可靠部位；重装大兵可用上肩甲的房色像素定位，其他兵种需按自己的素材测量。
- **位置和朝向分别校准。** 八向动作使用人物当前图帧的方向。对于所有指令朝向共用、但画面中人物自行转身的待机片段，要为片段标出逐帧身体朝向。重装大兵的 Idle1、Idle2 各 15 帧；即使从相反方向进入，同一待机帧上的背包也应贴在同一侧。
- **按姿态选择固定位置，再做前后遮挡。** 行军时镜筒贴紧背架；部署时沿动作从肩背过渡到阵地后沿，收起时反向衔接。远侧装具先画，近侧装具按深度叠加，重点查看正背面是否穿过人体、侧面是否挡住武器。其他人物按自身装具决定部署后仍随身还是固定到阵地。
- **验收既看八向，也看完整动作。** 留站立与部署八向对照、完整待机动图；对共用的单向待机分别从相反指令朝向进入，逐帧比对。再用真实命令检查待机被移动、部署或开火打断时是否立即接回对应姿态。用户观感与自动验证分开记录。[岸防导弹手八向与待机案例](fixes/v0.25.24.1/README.md)

## 全量精细化制作标准（2026-11-02）

后续新增或重做的建筑、步兵、载具、飞机和舰船，随功能一起交付高清素材。逐项覆盖实际会切换的形态与动画，包括建造和收起、炮塔换装、挂弹和空架、受损状态。交接时分开记录“已有 2 倍图集”和“已补模型或逐帧细节”。

用户要求逐批精细化 RA2／尤复单位。盟军以 v0.9.1 灰熊样车为第一件，下一批做多功能步兵车和超时空采矿车。苏联已接入和今后新增的单位也采用这套标准，新单位在首次制作时一并做美术对照。

- 从该单位自己的 VXL／HVA／SHP 与调色板出发，保留能认出兵种和阵营的比例、轮廓、房色。按用途选择局部细节，例如矿车的驾驶室和矿斗、步兵车的换装炮塔、苏联重坦的炮盾与履带。
- 体素载具按本体、炮塔／炮管、替换部件与阴影重烘 32 个朝向，核对世界尺寸、HVA 动作、炮口与点击位置。步兵及建筑 SHP 按原有动作帧加强剪影、持枪姿态、门洞和活动层。
- 每批在同一阵营色、朝向和倍率下留新旧对照。默认倍率检查战斗辨识度，2 倍检查局部，实际移动或工作动画检查帧间跳动。交接逐单位记录已生成、已接入和已验证的范围。

灰熊样车的可重建入口为 `ra2pipe/grizzly_detail.mjs` 与 `ra2pipe/vehicle_surfaces.mjs` 的 `grizzly` 模式。

v0.9.2 已将 FV 本体、基础和三套换装炮塔、CMIN／CMON 车体的专用细节接入 `vehicle_surfaces.mjs` 的 `allied-support` 模式。部件定义在 `ra2pipe/allied_support_detail.mjs`。原输入仍取本机尤复 MIX。此批候选和游戏中原数据比较共替换 19 张图像，帧参数与炮口文件字节相同。交互对照保存在 `refs/allied-support-detail-v1/compare.html`，可切换模型及全部朝向。

2026-10-26 用户提供原版画面与放大后的游戏截图，要求检查其它模型。
截图的缩放、朝向、阵营颜色不同，不能由此断言尤复更换了高清模型。
本项目 ROBO 已使用本机尤复 ra2md.mix/localmd.mix 中的 ROBO.VXL；SHA256：
1bb13bf3223c4765b1d66b2898a9a28485b8e656c4fcd2fdd0fa954285e6b4b5。

本轮处理的是全部 61 个单位 VXL 目录项及 FV 的 3 个换装炮塔，含地图/场景单位；不因此开放它们的生产资格。
步兵、海豚和建筑主体使用 SHP，没有套用体素重绘。建筑防御炮塔另有 defense_art/defense_recoil 管线，本轮未重烘。

## 已核实的导出问题

- HVA 旧读取器把文件名开头当作节数，没有读取位于 16/20 字节处的帧数/节数。
- 旧批量导出未消费 HVA，夜鹰使用自行制作的 4 姿态；现读取本机 HVA 的 2 个姿态，保留现行 20 fps 适配速率，不能称为原引擎时序复刻。
- 旧 VXL 解码连续推进，不使用各列 span 偏移；现按开始/结束/数据表寻址，并验证范围与截断。
- HVA 变换替代对应静态姿态，平移乘 VXL multiplier，不叠加第二次静态位移；实际 HTK 的节名不同，按节序关联并检查节数。
- 旋转节的法线也跟随旋转；旧法线始终按未旋转姿态照明。
- 阴影旧实现只横移体素，保留了模型高度在画面上的投影，且分别取车体/炮塔最低点。现取消高度投影，投射至共同 z=0 平面。
- 车体和炮塔阴影分开随各自朝向取帧，再取 alpha 并集后统一绘制为 50% 透明度；不双层叠黑。帧组合缓存最多 128 项。
- 公用画布包含阴影空白，旧 art_center 取画布中心可能落在透明处。VXL 单位现缓存当前车体可见边界中心附近的实像素，SHP/建筑路径不变。

## 再生成与验证

```powershell
node ra2pipe/vehicle_surfaces.mjs '<本机尤复安装目录>' '<新的仓库外候选目录>' all
node --test ra2pipe/vxl_lib.test.mjs ra2pipe/voxel_surface.test.mjs
```

`all` 枚举已有单位 VXL 描述，排除专用建筑炮塔及派生层，读取本机对应 VXL/HVA/PAL/VPL。
为 61 个目录项统一生成 32 朝向；FV 三种乘员炮塔与车体使用同一画布并重算炮口。
v0.3.4 输出 393 项资源（76 张两倍密度细节 PNG，以及原生 PNG/元数据/炮口文件），所有输入来源与产物哈希写入候选 source-audit.json。
只有完成整批生成后才写候选文件；输入缺失不会部分覆盖工程。导入逐项校验哈希。
历史原始专项导出器不作为新全量模型发布入口；以后重导单位应使用这个入口，避免旧专项覆盖 HVA/split_shadow 元数据。

运行检查使用现有隔离 runner，目标套件：model_render、vehicle_motion、unit_muzzle、naval、flight_motion、selection、box_ui_release。
实际命令添加 `_regression` 后缀，均 `-Render`。最终次数与结果见 VERIFICATION.md。

## 参考与边界

文件布局参考公开的一手实现，独立编写 JS 读取器和 Godot 显示适配，没有复制第三方渲染实现：

- [EA 发布的 FinalAlert2/XCC HVA 校验](https://github.com/electronicarts/CNC_TS_and_RA2_Mission_Editor/blob/main/3rdParty/xcc/misc/hva_file.cpp)
- [OpenRA HVA 帧/节顺序](https://github.com/OpenRA/OpenRA/blob/bleed/OpenRA.Mods.Cnc/FileFormats/HvaReader.cs)
- [OpenRA VXL 列寻址](https://github.com/OpenRA/OpenRA/blob/bleed/OpenRA.Mods.Cnc/FileFormats/VxlReader.cs)

仍是 Godot 软件烘焙精灵，不是加载原引擎；光照等级选择、房色映射、像素遮挡、相机缩放存在适配差异。v0.3.4 已读取原版 VPL 颜色查表，仍非原引擎光照完全复刻。
本轮未更换调色板或用任意锐化/放大替代源模型，也不声称与用户参考图逐像素一致。
姿态、阴影和点击检查的通过只能证明相应客观结果；实机外观状态保持 pending_user_visual_confirmation。


## v0.3.2 模型边缘柔化（2026-10-27）

单位和建筑原先在 `_ready()` 强制 `TEXTURE_FILTER_NEAREST`，放大后呈现硬像素阶梯。
现在由 `MetaProgress.register_model_display()` 注册战场对象；默认使用 `TEXTURE_FILTER_LINEAR`，设置关闭后恢复最近邻。
依据 [Godot CanvasItem 官方说明](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)：线性采样混合相邻四个像素，只改善像素边缘，不补充源图细节。

- `MetaProgress.model_smoothing` 为独立显示偏好；to_dict/load_save/reset_save 均处理，新旧存档默认 true。
- `model_display_controls.gd` 共用在主菜单设置与 HUD 战斗设置；signal 同步多个控件，group 更新已存在对象，不改共享 ShaderMaterial。
- 只修改 actor 的采样方式；原图集/UV/炮口/体积/速度/血量保持。UI、独立原版维修图标/载员格仍用既有显示路径。
- 新的 RA3 真三维模型仍走原 SubViewport 3D 渲染，不重烘其资源；当前父对象过滤切换不是 RA3 几何质量设置。
- 需留意线性插值的柔软观感与源像素分辨率限制，不称高清重制。后续真高清车辆需要另做高分辨率体素渲染或实时模型；建筑和步兵需要相应高质量源素材。

专项 `model_smoothing_regression -Render` 覆盖双模式、蓝/绿队色、坦克/矿车/步兵/电厂/战车工厂、1/2/3 倍显示，检查真实模型像素变化和侧栏像素保持；另回归 model_render 与 temporal_visual。实际观感 pending_user_visual_confirmation，结果与证据见 VERIFICATION.md。


## v0.3.4 体素表面与细节图集（2026-10-27）

- 原管线每个体素只投影一个像素，源模型中存在的立体表面会变成离散像素。独立 `voxel_surface.mjs` 现在按体素包围盒构造外露面，使用 HVA 变换、深度遮挡、2×2 覆盖率下采样；同节相邻内部面跳过。共面表面用稳定颜色优先规则消除遍历顺序差异，非共面按深度取前表面。
- 读取本机 `ra2md.mix > localmd.mix > VOXELS.VPL`（8976 字节，SHA256 `2d75fff8a6872ffe98308c7009858a9e904696e1529bc649181a44993979081c`）。16 字节头 + 768 字节嵌入调色板 + 32×256 查表；颜色实际仍用 unittem.pal 及已有蓝色房色映射。方向光法线选择 0～8 级暗到中性表是本项目适配，并未验证原引擎的所有场景光照等级。既有 sprite_grade 自动提亮保持，不能声称输出就是原版最终颜色。
- 61 个模型条目、76 个车身/炮塔层生成 `_detail.png`；2×密度增加的是从原 VXL 表面重算的采样，不是对旧 PNG 插值拉伸，也没有增加原 VXL 不存在的几何细节。最大图集边长 13188，导入前检查 ≤16384。现有 Godot OpenGL 渲染器运行验证仍必需。
- 原生 PNG 保存覆盖率，继续提供 alpha 点击、轮廓中心、自动亮度和阴影。`RA2Art.draw_sprite` 只把源矩形乘 detail_scale，目标矩形保持逻辑尺寸；单位和独立炮塔使用细节纹理。公共画布、32 方位炮口从实际表面边界重新推算，不把碰撞/移动/攻击尺度翻倍。缺失细节图报错并回退原生坐标，不能把回退当作验证通过。
- 防御建筑炮塔、步兵/建筑 SHP、RA3 模型未进入本次重烘。原始低分辨率几何、建筑动画分层与原引擎逐像素遮挡仍有独立工作；此版本不代表全部美术已达到 100%。

正式全量单位重烘使用上方 `vehicle_surfaces.mjs`，旧 `vehicle_facings.mjs` 是点投影历史管线，不得覆盖此批资源后直接发布。候选目录记录每个 MIX 输入来源和 SHA256；校验全部产物后才导入，并保存旧资源 zip 以便回退。

本批候选与旧资源备份：`C:/Users/admin/Temp/iron-surface-all-20261027-v2/`。运行证据追加在 VERIFICATION.md。外观仍是 `pending_user_visual_confirmation`。

## v0.3.6 建筑、人物与防御炮塔（2026-10-27）

本节补充 v0.3.4 尚未覆盖的建筑/人物 SHP 与专用防御炮塔；前面的“未重烘”描述是历史批次范围。飞机、运输机和 VXL 舰船已使用 v0.3.4 的真实体素表面采样，本轮保留该管线。RA3 真三维素材不进入 SHP 增强。

- 建筑、人物、海豚等现有 SHP 共111张有效源图集、11181帧，独立生成2倍密度边缘增强。使用公开 [Scale2x 算法说明](https://www.scale2x.it/algorithm) 中的邻接颜色比较思想，独立实现，并限制原透明像素仍透明；保留原调色板颜色、房色、动作帧、原生占位与点击遮罩。不是生成高模或恢复原图不存在的纹理细节。
- 每帧独立处理，透明边界裁剪后保留1个原生像素边距，以2像素图集间隔打包为118页，每页最大2048×2048。新增PNG合计20,180,489字节；所有页的未压缩RGBA合计606,183,040字节，并非同时驻留的承诺。原PNG、原SHP帧描述保留，逐项输入哈希可复核。GAGREEN为既有0×0占位，记录跳过，不把它称为有效模型。
- `shp_detail.gd` 延迟载入页面，公共页面缓存上限64MiB；当前绘制对象另外持有当前及上一轮绘制页，避免缓存淘汰使静止对象变黑，也防止动画永久保留所有历史页。因此64MiB不是整个游戏显存上限。
- `RA2Art.draw_sprite` 使用每帧裁剪偏移还原原始逻辑尺寸。人物动作、建筑主体/叠层/阴影、围墙、建造/出售、放置预览与基地收起过渡均接入；模型柔化开关仍控制显示采样。原生图用于已有点击与轮廓计算，寻路、速度、伤害及生产规则未因本批显示增强更改。
- 巨炮与爱国者专用炮塔读取本机 GTGCANTUR/GTGCANBARL/SAM VXL 和原 VPL，沿用体素表面光栅化。生成32方位静态图及巨炮8档后坐×32方位的原生覆盖/2倍细节图，保留原画布、模型原点、炮口和后坐时序。全方向表面越界检查通过，运行回归另见 VERIFICATION.md。
- SQD仅留有描述与攻击特效，没有当前可用的主体PNG，运行兵表也未开放；不把它算作本批已完成的模型。建筑和人物仍受原始SHP分辨率限制，真正增加五官、材质或几何细节需要新高质量源素材。

再生成（候选目录必须不存在，且在仓库外）：

```powershell
node ra2pipe/shp_details.mjs '<新的SHP候选目录>'
node --test ra2pipe/shp_detail.test.mjs
node ra2pipe/shp_detail_audit.mjs '<SHP候选目录>'
node ra2pipe/defense_surfaces.mjs '<本机尤复安装目录>' '<新的炮塔候选目录>'
```

SHP入口消费当前已提取的原生PNG/JSON，不依赖未知在线资源；炮塔入口直接读取本机MIX。候选及可逆备份分别为 `C:/Users/admin/Temp/iron-shp-detail-20261027-v3/` 和 `C:/Users/admin/Temp/iron-defense-detail-20261027-v2/`。导入必须逐项核对source-audit文件哈希；不要用历史点投影导出器覆盖新资源后直接发布。

显示验收状态：`pending_user_visual_confirmation`。本轮功能记录为v0.3.6，保留并发RA3补丁后的工程版本v0.3.6.1；未提交、推送或制作新试玩包。

## v0.11.1.4 · 尤复待机核查

来源为本机 rulesmd.ini、artmd.ini、实际 SHP／VXL 图集。核查入口为 `node ra2pipe/yr_idle_sequences.mjs "<尤复安装目录>"`。范围为两个阵营的 42 个单位条目（含 V3 火箭），加上 HORNET、ASW、SUB、CTECH、INIT 五个派生或支援条目。

| 类型 | 核对的单位 | 待机表现 |
| --- | --- | --- |
| 盟军步兵 | E1、ENGINEER、JUMPJET、GHOST、DOG（盟军）、CLEG、SPY、CCOMAND、PTROOP、SNIPE、TANY、GGI | 各两段陆地动作。海豹、谭雅另有两段水中动作，火箭飞行兵在空中保持 Hover／Fly |
| 苏联步兵与乘员 | E2、SHK、FLAKT、SENGINEER、CTECH、INIT | 逐单位核对非空序列；CTECH 只有一段多帧待机。两阵营与乘员共 39 段 |
| 车辆与船只 | AMCV、MTNK、CARRIER、DEST、AEGIS、LCRF、TNKD、CMIN、SREF、MGTK、FV、CDEST、ROBO、BFRT、HARV、APOC、HTNK、V3、HTK、SMCV、SUB | 已接入主体 VXL 各有一个 HVA 姿势，区分炮塔、悬浮、伪装、采矿等独立状态 |
| SHP 车辆与海豚 | DRON、DLPH | 恐怖机器人每方向 1 张站姿；海豚停留时播放原游泳帧，15/8 帧每秒 |
| 飞行器及弹体 | SHAD、ORCA、BEAG、HORNET、ASW、V3ROCKET | 夜鹰沿用空中旋翼动作，其余主体为单姿势，飞行高度、轨迹与机体骨骼动画分开处理 |

单位的静止动作只影响渲染。步兵各用独立的随机计时，在 4.5–9 秒的等待窗口后播放一次；不改变朝向、命令、寻路或战斗随机数。苏联 4 个步兵及 CTECH、INIT 的 3398 个原图帧新增 2 倍边缘增强。

另核对扩展模式的 RA3／起义六个模型的默认状态。幻影、未来、天启和收割者使用各自骨骼待机；磁暴坦克原版默认状态显示静止履带，先锋炮艇使用飞行路径并无具名待机机体片段。此处只记录源码核对，未重新制作或逐台验收这些模型。

## v0.25.13 · TNKD 固定战斗室外骨骼试验

原版 TNKD.VXL 的单一部件 DUMMY01 包含主炮。护轨甲以同一局部模型镜像安装在车体两侧，测距仪安装在固定战斗室上方。挂点在 VXL 模型坐标中定义，随该部件 HVA 变换。使用 ra2pipe/tnkd_exoframe.mjs 读取本机尤复目录，只输出配件的 2 倍分辨率透明叠层。原车、炮口、阵营色和战斗数值继续使用原资源。烘焙时将配件与宿主逐像素比较深度，并复用原朝向帧原点及图集间距。其他车型需实测部件名、原点和挂点；有独立炮塔的车需分别处理相对运动和遮挡。

重建命令为 node ra2pipe/tnkd_exoframe.mjs "<尤复安装目录>"。同一输入重复烘焙的 PNG 哈希一致。32 个方向均有可见配件且没有裁边；两个相对侧视方向近侧护轨甲各有 824、822 个可见采样，远侧均为零。展示专项覆盖全部 32 个方向、原炮口不动以及固定车身单转瞄准角，合计 703 项通过。工房截图见[原车与外骨骼对照](tnkd-exoframe.png)。仅记录已验证的刚性挂点与遮挡，玩家观感待确认。

## v0.25.14 · 尤复高清皮肤与 Godot 烘焙样片

尤复新皮肤按玩家要求做高清外装甲或整套新外观，保留原车动作、朝向与功能挂点。原车的像素密度不作为新皮肤的美术上限。AI 可用于材质或整套外观的美术设计；以同一份可定位的几何和材质生成各方向，检查旋转连贯与遮挡。整套外观替换仍应独立检验其动作和各朝向。这次实装的是外装甲。

坦克杀手沿用猎隼外骨骼的购买和装配记录。ra2pipe/materials/tnkd-neon-armor.png 是 AI 创作输入，ra2pipe/tnkd_neon_panels.mjs 把金属压框、磨损、分段灯罩和白色芯线按局部 UV 投影到侧裙折面、端盖和肩甲，再与原车和其他附件比较深度。按每个逻辑像素 8 个采样宽度烘焙 32 向静态金属与玻璃。主炮四根交错插管逐根错拍心跳，侧板四灯逐根缓慢呼吸；各管的柔光与灯芯由独立遮罩控制。[同屏灯效演示](fixes/v0.25.20.1/README.md)。尾涡轮在运动时发出固定蓝白尾焰。工房可放大和旋转查看。

RA3 以幻影坦克做第一份 Godot 静态朝向样片。tools/ra3_mirage/render_fallback.gd 使用现有转换几何、贴图和 FX 武器点输出 32 个方向，已检查每格有像素、32 张帧内容相异及 32 个炮口投影均在画布内。本次结果保存在 refs/ra3-godot-bake-v02514，用于比较，不替代实时骨骼动画和特效。

<details><summary>坦克杀手外甲的内置 imagegen 最终提示词</summary>

Production texture for a high-definition cyberpunk tank flank. Landscape 3:1 aspect. Completely flat orthographic side elevation, tight edge-to-edge crop of ONE continuous side skirt: three overlapping beveled graphite titanium armor plates, heavy angular silhouette, broad satin silver chamfers catching light, small recessed bolts, worn polished edges, precise milled grooves and contrasting dark inset panels. Across all three plates runs one clearly recognizable continuous insulated neon light pipe, near horizontal with two shallow angular offsets, occupying about one sixth of panel height. The glass of the tube is bright saturated magenta with a slender white-pink core, covering about 15% of the surface. Show individual glass sleeves, black gaskets dividing the tube, silver retaining clips occluding the light, secondary thinner parallel tube low on the panel. Use magenta ONLY for luminous glass, never on surrounding metal, no colored spill; the game extracts this into an emissive mask. Crisp physically rendered hard-surface concept texture, defined large bright/dark shapes that survive at RTS scale. Neutral studio lighting, brushed metal, crisp ceramic insets, restrained wear. Orthographic UV material swatch, no perspective or backdrop, no tank, tracks, lettering, diagrams, labels, grid, logos. Fill image with the surface from left to right and top to bottom without margins.

</details>

## v0.25.17 · 猎隼主炮插管

ra2pipe/tnkd_cannon.mjs 以 TNKD 原炮口模型坐标为局部原点，按原固定炮架投影钛合金套筒、四路反绕供能管、锁环与炮口。炮套材质来自内置 imagegen，位于 ra2pipe/materials/tnkd-cannon.png。烘焙检查两个正侧面炮根、中段、前段均有红蓝两路可见；战斗继续读取原炮口数据。

<details><summary>炮套生成提示词</summary>

Game-ready UV material, a single long rectangular unwrapped cladding for a precision cyberpunk tank cannon. Landscape 3:1. Entire canvas filled edge to edge by the surface; flat orthographic UV sheet, not a perspective drawing of a weapon. Length runs from breech on the left to muzzle on the right. Brushed blackened titanium structural sections, chamfered silver locking collars crossing vertically at x=15%,50%,86%; slim horizontal grooves for external energy lines. Tiny brass compression fittings embedded in collars, readable contrasting large machining, heat-darkened metal closer to right end. Neutral illumination. No colored pipes, no glow (actual engine adds moving red and blue pipes on top), no text, logos, diagrams or background, no hole in the image. Detailed convincing industrial construction with satin machining and subtle wear. Restrained and premium; should stay legible on a miniature.

</details>

### 坦克杀手尾涡轮的起步与转向（v0.25.18）

[工房实渲动图：起步、环焰、全喷、转向与停车](tnkd-turbine-ignition.gif)

沿用 TNKD 车体当前帧的投影原点和 32 向索引。此型号的涡轮安装点在 DUMMY01 的 (-20, 0, 13.5)，喷口端面位于 X = -26.37，外沿半径 6.85。叶盘和火根使用同一个 YZ 平面。将已有 AI 涡轮材质左上图块缩取为 256 × 256 的运行时纹理，单独旋转内盘 UV，保留外壳。已有 AI 蓝白喷流纹理按曲线铺到焰带。由车体朝向决定尾焰绘于车体前或后，叶盘仅从后端可见。

起步时内盘最高约 3.2 转/秒。焰根在 1.2 秒内绕轮缘一圈，随后用 0.7 秒向后展开大尾焰。线速度和实际车身角速度都能驱动点火，焰根绑定当前帧，转向偏移随轴向距离的平方增加。停车后油门与喷焰衰减。运行态与工房共用同一表现脚本。移植至新车先核对该车模型坐标、宿主部件与遮挡，重新测定喷口端面和半径。

验证入口为 unit_showcase_regression。工房覆盖 32 向和原炮口、红方车身的尾焰颜色、叶轮起转与大尾焰伸出；战场覆盖实际移动命令造成的零速转向、直行和停车。动图为工房按指定朝向与油门采样，战场指令另行验证。

### v0.25.22 · 岸防双目镜与日冕车体血脉

岸防导弹手沿用 GGI 的八向 SHP 步态与部署帧。收拢的双目镜随背架轻摆，部署时两根滑轨带动镜头分开，升降立柱与支脚连接。按当前朝向分别投影镜面、防护盖、散热面与顶盖，先画远侧再画人体与近侧。运行时 512 × 512 素材取自 imagegen 生成的四区光机材质原图 `ra2pipe/materials/ggi-coastal-optics.png`。

日冕玻璃的暗红分支只绘在 SREF.VXL 车体可见的上层装甲，按本体方向换帧，在独立炮塔之前绘制。停车后光从外围朝发射座依次增强，射击时反向回闪。重建用 `node ra2pipe/sref_solar_veins.mjs "<尤复安装目录>"`。本次原车 32 向车体图集合计 31,676 个有色采样，落在全透明车体像素上的采样为 0。展示与部署控制两项隔离回归分别通过 762 与 114 项。[工房状态对照](solar-coastal-skins.png)。
### v0.25.38 · 北辰／铁脊英雄机甲外装

玩家要求英雄皮肤采用 RA3 式机械构件与尤复像素主体结合，避免整块长方体护甲。`ra2pipe/hero_tank_armor.mjs` 在 GTNK／HTNK 各自 VXL/HVA 空间生成分段斜切履带护板、液压杆、管夹、独立炮塔护肩、发光导轨和散热结构。灰熊增加后掠陶瓷鳍，犀牛采用双炉排气冠，保留两者本体轮廓与阵营色。炮管套环高度读取实际 barrel VXL 包围盒，不复用其他车辆坐标。

AI 源材质保存在 `ra2pipe/materials/hero-tank-armor.png`；生成结果结合平滑金属底色，避免把整张纹理缩进小护板造成噪点。每车的车体、炮塔分别离线烘焙 32 向、4 倍细节，按宿主原模型深度遮挡；运行时绘制两层外甲及两层灯罩，不在战斗中生成网格。灯轨、后掠鳍和排气冠都来自模型空间，随各自部件转向。

英雄养成页独立试穿与装配。模型验证必须同时包含原车体朝向、炮塔相对车体转向、正常阵营色和残骸停用状态，不能只用同朝向的工房截图代替。当前八视图见版本文档；这是实际 Godot 渲染截图，玩家风格认可仍单独保留。

### 单兵种专属抽取卡的演示模型（v0.25.68）

任务许可卡例外（v0.25.71）：装配对象与实际事件执行者分开。超时空许可卡装在 CCOMAND／CIVAN，任务由 GHOST／IVAN 执行；演示左侧显示装配对象，时间轴中按卡配置 objective_unit 显示真实任务执行者，不要用超时空单位演示普通单位的前置任务。

仅适用于一个兵种的抽取技能／被动卡，演示区域中的施放者必须显示该兵种模型，不得使用三角头代替。按 SkillScope.exclusive 与 allowed_units 动态读取，不维护第二份卡牌名单；新增卡也必须沿用。多兵种不标专属。敌方靶子与一般事件符号可以继续使用示意图形。

模型必须使用隔离展示世界并禁用战斗／物理，保持演示轨迹、朝向、透明度与时间轴同步。切换等级保留播放位置，拖动暂停；切卡释放旧模型，同卡复用。冻结展示的原生特效若依赖实时生命周期，需要显式关闭或按时间轴初始化，不能把未初始化的 Viewport 黑底带入演示。图形检查在不切换前台的独立 Windows Desktop 完成。

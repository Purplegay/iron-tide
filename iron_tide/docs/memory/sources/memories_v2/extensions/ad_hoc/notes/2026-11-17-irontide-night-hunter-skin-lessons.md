# IronTide：夜枭／猎蛛皮肤制作避坑

2026-11-17，用户明确要求“这次皮肤制作过程写入记忆，方便后续避坑”。项目 `C:/Users/admin/IronTide`，Godot；不是当前常驻的 KFramework Unity 工程。该项目目前没有独立 `.codex/memory/`，本条写入既有长期记忆入口，不新建 Unity 式系统目录或修改 skill/AGENTS。

## 用户确定的要求与交付边界

- 现代风格，接近认可概念图；用户否定过方块化模型和难看的整图融合，最后选定直接 32 向独立图，不恢复方向交叉淡化、光流形变或模型投射。移动位置／转向仍应流畅，步态不能假装是连续骨骼动画。
- 夜枭（SCHP，obsidian_night_owl）保持原版大小；猎蛛（DRON，rift_hunter）最新是原版 **140%**，覆盖早期 115% 和 300%。比例按原版八个代表方向的平均可见宽度标定，不是整张透明画布倍数；外观缩放不改碰撞、生命或战斗规则。
- 呼吸灯必须在游戏运行时变化；夜枭有独立旋翼、展开／收拢、火炮伸缩和动态火焰气流。用户要求性能不倒退。RA3 多部件搭配仅预留，不因此扩大适配范围。
- 尽量少截图，先决定方案再做；必要皮肤核对使用小对照图，默认后台／未激活桌面，不启动可见游戏窗口。默认只改工程，不擅自打包、提交或推送。
- 最新工程 v0.29.10。步态、落地、清晰度、气流及阵营色观感仍待用户试玩确认；测试通过或用户继续提需求不等于视觉验收通过。养成扩展目标仍暂停，记忆或皮肤后续工作不自动恢复它。
- 用户追加最终目标：本轮可购买皮肤收尾必须设置正常价格，结束临时免费体验。当前夜枭／猎蛛仍在 FREE_SKINS；普通皮肤现有标准 6000 钻石及皮肤券只是定价基准，不是已完成最终定价。购买、所有权、装备、读档与保存失败回滚也须验收。任务已记入实施目标第 7 批。

## 已核实的故障原因与修复经验

1. **模糊与过大是不同问题。** 原稿每格约 222 像素，旧打包缩到 128 丢细节；改为 224 纹理像素，但保留 128 逻辑坐标，纹理增密不能顺便放大单位。使用带 mipmap 的线性采样、无损 WebP，并逐字节验证解码像素。无损 WebP 比相同新版 PNG 小约 22%，但仍比旧 128 图集大。不要声称固定 AI 原稿放大后能保证所有缩放下达到 RA3 模型清晰度。
2. **透明残留会抬高机体。** 猎蛛原稿极低 alpha 像素让 get_used_rect() 误判整格有效，旧脚底锚点低于可见脚尖，实际绘制表现为悬空。离线按 alpha > 0.2 求可见边界／宽度，96 个方向和姿态分别以可见最下缘落地；迈步姿态只保留横向主体对齐。不要仅按红灯中心的纵向偏移对齐动作，也不要在每帧扫像素。该阈值用于几何测量，不代表应硬切所有半透明抗锯齿边缘。
3. **步态频率要独立调。** 当前猎蛛只有两张迈步关键图：移动时交替，不夹回站姿；按真实位移推进，40 世界像素／循环，上限 3 循环／秒。堵住、原地转向、停止、瞬移不推进，预览显式提供展示位移。不要用 velocity 非零当作真实移动，也不要直接继承随机重置的单位 idle walk phase。增加贴图像素不能补出缺失动作。
4. **切图会带入邻格机身。** 夜枭选中后左侧黄边碎片来自相邻机身串入，不能仅调描边阈值掩盖。检查全部 96 格发现 10 格有此问题：飞行 1/14，中间 1/2/14，展开 1/2/3/14/15（零起始）。编译器 HELI_LEFT_GUTTERS 在碎片与机体之间的透明间隙裁切，保留坐标；清除 278 个 alpha > 0.15 碎片像素，全部保留区域逐字节一致。改变原稿或格尺寸后须重新核对这些裁切值，不能通用套用。
5. **独立材质会绕过阵营色。** HouseColor.apply_to() 设置通用材质后，NightHunterSkin.configure() 又换为呼吸灯材质，导致原房色丢失。现在把同一次解析出的 col 直接传入 configure(node,col)，设置 house_color；不要读取尚未完成赋值的 actor._col。shader 将夜枭暖金饰边／猎蛛红装甲映射为玩家色，保留金属明暗、灯光；独立炮管、旋翼和火焰不参与映射。初次装备、预览、已有单位换色都要验证。
6. **“没用粒子”不证明没有性能成本。** 初版气流绘制曾变慢，最终把机身＋两股气流合为一次提交，旋翼缓存 ArrayMesh；普通绘制用离线边界，像素读取延迟到点击／检查时。避免每帧重建多边形、额外 canvas transform 或 CPU 图像回读。v0.29.7 同机 64 单位混合专项 P95 6.119→5.464 ms，提交 449→225；仅为当时 RTX 5060 Ti / GL Compatibility 渲染专项，不是六家长局或 v0.29.10 性能验收，也不代表已达到暂停的 33 ms 目标。

## 权威路径与可复用验证

均相对 `C:/Users/admin/IronTide/`：
- 原稿：`docs/concepts/progression-expansion-2/direct32/`；离线编译：`ra2pipe/night_hunter_pack.gd`。修切图在编译入口处理，不能只修输出而让重编译复发。资源改动后重新导入 Godot，避免测试读取旧 import 缓存。
- 输出：`iron_tide/assets/cosmetics/night_hunters/*_direct32.webp` 与 JSON；夜枭最后一行存气流。炮管仍用独立 PNG。逻辑姿态锚点与纹理格尺寸分开。
- 运行时：`iron_tide/scripts/units/night_hunter_skin.gd`、`night_hunter_clock.gd`、`night_owl_exhaust.gd`、`night_owl_rotor.gd`；材质 `iron_tide/shaders/night_hunter.gdshader`；房色入口 `iron_tide/scripts/core/house_color.gd`。
- 购买：`iron_tide/scripts/rules/cosmetic_catalog.gd`、`iron_tide/scripts/autoload/meta_progress.gd`、`iron_tide/data/meta.json`。目前目录中的“1.15 倍／免费体验”等旧文案不能当作最新尺寸或最终商业状态的依据。
- 回归：`iron_tide/tests/night_hunter_skin_regression.tscn`、`refit_skin_regression.tscn`；部署相关另有 `siege_chopper_collision_regression.tscn`。v0.29.10 实际 GPU 1281 项＋改装 148 项通过，不能重复累加复测次数。颜色测试通过真实选色入口，覆盖 12 色同步、红蓝在三姿态四朝向的像素差异以及 alpha／包围盒不变；其余覆盖尺寸、脚底、裁切、灯光、气流、改装与快照。
- 渲染专项：`iron_tide/tests/night_skin_render_bench.tscn`，1280×720、64 单位、预热 180／采样 1200 帧。比较相同环境且避免同时跑其他测试；记录最终资源的结果，不挑最低值。旧版基线额外保留新纹理，不能据该基线进程总显存比较资产显存。
- 原始验证缓存：`.validation/night-hunter-detail-20261117/`；现有 `run.py <输出名> night_hunter_skin_regression` 使用隔离资料目录、未激活 Windows 桌面及 Godot 4.7.2。复用前确认 Godot 路径、wrapper project 和 junction 依然有效；它是本机脚手，不是可跨机直接运行的保证。GPU像素检查不能冒称纯 headless。
- 详细依据及历史版本：`docs/NIGHT_HUNTER_DETAIL_0297.md`；范围／暂停／定价收尾：`docs/PROGRESSION_EXPANSION_2_ROLLOUT.md`。不把缓存路径或报告当作已交付可玩包。

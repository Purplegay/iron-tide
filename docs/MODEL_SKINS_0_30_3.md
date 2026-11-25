# 三款模型外观 · v0.30.3

## v0.30.28 黑曜夜枭提亮与金属高光

2026-11-18 使用者反馈直升机皮肤过黑、反光不明显。`night_hunter.gdshader` 为夜枭机身及独立炮管增加中间色提亮和沿既有受光面分布的冷色高光，保留暖色饰边、阵营色和灯效处理；旋翼与轴毂的绘制色同步提亮。没有新增贴图采样、图集或逐帧生成材质；猎蛛不进入新的金属处理分支。尺寸、碰撞和游戏规则保持。

隔离 GPU 对比覆盖两个飞行方向及一个部署方向，材质开关0/1的金属采样亮度分别增加62.66%、62.32%、62.74%，三组透明度变化像素均为0。对比图两列均使用新版旋翼色，专门显示左侧旧机身材质、右侧新机身材质；已查看图中装甲、尾梁与炮管层次。`night_hunter_skin_regression` 在实际GPU通过4755项，覆盖两款皮肤、32向、姿态、阵营色、灯效、隐身隐藏及轮廓等现有断言。此次观感仍为 `pending_user_visual_confirmation`。

证据根 `.validation/night-owl-brightness-20261118/`；`gpu.py night_owl_brightness_preview` 为本轮临时渲染探针，`gpu.py night_hunter_skin_regression` 为既有回归，`run.py audit` 核对作者源码和资源前后指纹无变化。独立项目快照、每次运行独立 APPDATA/LOCALAPPDATA，Godot 4.7.2 OpenGL兼容渲染；服务、端口、数据库、协议为none。两次均使用已存在的隔离桌面工具，`input_before=input_after=Default`、`activated=false`。仅保存一张引擎渲染对比图，不抓取用户桌面；未打包、未提交推送。

## v0.30.10 共享光晕编译修复

2026-11-18。当前源码重新运行 `leizhu_base_regression` headless，117项业务断言通过，但出现 `shader_compiler.cpp:1329` 的 `!actions.custom_samplers.has(function->arguments[j].tex_builtin)` 报错，故该次运行判为失败。共享 `mechanical_halo` 将内置 `TEXTURE` 传给自定义函数的 `sampler2D` 参数，触发该编译路径。`leizhu_copper.gdshader` 与 `night_hunter.gdshader` 均使用它，影响雷铸及两款夜猎皮肤。

修复只把四个邻域采样移至各自的 `fragment()`，向共享函数传入4个已采样的vec4；发光提取、采样坐标／顺序、强度、颜色和透明度计算均保持。没有新增uniform纹理、灯光节点、渲染提交或采样次数；未改素材、尺寸、游戏玩法或购买规则。

修复后共9663项检查通过：雷铸基础headless117、两款夜猎headless4490、雷铸实际GPU外观181、两款夜猎实际GPU4755、固定像素探针120。三款皮肤各4朝向×2透明度×4灯光／阵营状态，共96组GPU像素SHA全部与修复前一致，日志无脚本／引擎错误。探针只存哈希，不保存截图。未做新的全局帧耗时测试。

缓存 `.validation/skin-shader-compiler-20261118/`，`headless-before/`保留故障日志，`before/`与`after/`为像素基准，`pixel-comparison.json`记录96/96一致，`summary.json`汇总通过证据。Godot4.7.2；headless与未激活私有桌面OpenGL均使用本工程隔离验证项目和当前源码，APPDATA／LOCALAPPDATA逐运行隔离；服务／DB／协议均未使用。退出审计 `post-run-audit.json`零残留，输入桌面前后Default。编译错误已验证消除；整体皮肤美术观感仍待用户确认，未打包、提交或推送。

---

2026-11-18。用户重新授权武装直升机与恐怖机器人采用模型烘焙路线，并确认磁暴坦克指英雄雷铸；随后两次要求增加贴图细节、避免简约外观并添加光源特效。此批只改外观与模型炮口，不更改兵种数值、技能规则、皮肤价格或解锁资格。状态为 `pending_user_visual_confirmation`。

## 资源与动作

| 单位 | 图集与动作 | 实际大小 |
| --- | --- | --- |
| 黑曜夜枭 | 每格256像素，5个展开阶段×32向；独立192像素32向炮身，实时旋翼沿原时钟旋转。悬浮和尾喷保留，气流根部由模型投影定位，部署后收束。 | 与原生武装直升机的8个代表方向平均宽度一致，包含旋翼。 |
| 缝隙猎蛛 | 每格192像素，站姿＋8帧步行＋收腿／伸腿扑击，各32向。只有一个四腿骨架；步行保持40像素步幅、最高每秒3周期，阻挡和原地转向不走步，寄生后隐藏。 | 原生恐怖机器人平均可见宽度的140%，不改变碰撞半径。 |
| 铜冕雷炉 | 每格256像素、32向。独立路轮、履带块、装甲接缝／铆钉、铜线圈绕纹、陶瓷绝缘子、琥珀炉芯与后置电感鼓。 | 沿原雷铸入口按原生TTNK可见宽度校准，普通磁暴坦克保持原版。 |

机器人的地面支撑使用同一模型地平面和固定枢轴，站立／步行每个姿态至少两条腿落地，扑击按真实 `pounce` 状态切换并复用原生跃起高度。所有姿态都由同一四腿模型投影，遮挡仍可能让某个角度只看到部分腿，不为凑可见数量增加肢体。

## 细节与光源

- 共用作者工具 `ra2pipe/mechanical_mesh.mjs`，分别由 `night_hunter_models.mjs`／`leizhu_model.mjs` 制作模型。沿用固定等距相机，32次旋转独立烘焙；各姿态32帧的像素哈希均不同，不融合方向、不镜像补帧。
- 装甲使用英雄灰熊现有的 `hero-tank-armor.png` 金属材质，以模型坐标采样，结合几何接缝／铆钉／格栅、金属高光、烘焙自遮挡和紧邻缝隙暗部。源材质指纹记录在图集JSON中。
- 直升机补光学探头、座舱侧灯、机首和翼尖暖灯、尾部航行灯、旋翼帽灯，保留双尾喷动态气流；机器人补前部扫描灯和背部红灯；雷铸补暖色炉芯／车灯和冷色线圈触点。
- `mechanical_glow.gdshaderinc` 在同一机身绘制中做四次局部采样生成光晕；不是照亮所有地形的真实全局光照。没有新粒子系统、灯光节点或额外渲染视口。阵营涂装和发光材质分开识别。
- 断电时夜枭／猎蛛灯效关闭；雷铸停堆时熄灯，供电时增强光晕并在铜冠内部绘制两段短电弧。电弧不会指向敌人，也不模拟实际攻击。雷铸灯光改由可暂停外观时钟驱动。
- 四份运行图集PNG共4,760,056字节，使用无损导入和mipmap。新资源为 `night_owl_mesh32`、`night_owl_mesh_gun`、`rift_hunter_mesh32`、`leizhu_copper_model32`，旧图集不再被这三个运行入口消费，未删除历史候选。

复现：在仓库根执行 `node ra2pipe/night_hunter_models.mjs`、`node ra2pipe/leizhu_model.mjs`，随后让Godot重新导入对应PNG。作者工具不访问外部AI服务，本批没有新生成AI图片；使用的是已有材质与新建机械几何。

## 验证

12个专项／关联套件共6399项断言通过，最终日志无脚本或引擎错误：

| 套件 | 检查数 |
| --- | ---: |
| `night_hunter_skin_regression` | 4755 |
| `leizhu_art_regression` | 181 |
| `peregrine_art_regression` | 212 |
| `night_skin_purchase_regression` | 86 |
| `leizhu_base_regression` | 117 |
| `leizhu_station_regression` | 68 |
| `leizhu_safety_regression` | 75 |
| `leizhu_card_demo_regression` | 121 |
| `hero_arrival_demo_regression` | 311 |
| `hero_combo_demo_regression` | 256 |
| `progression_expansion_2_drone_regression` | 161 |
| `siege_chopper_collision_regression` | 56 |

覆盖实际购买／装备／档案、经典及扩展模式的尺寸／颜色、每一方向与姿态的非空边界／透明留白、固定四腿及地面支撑、真实展开与起飞、扑击视觉高度／选框、寄生隐藏、战斗快照恢复、英雄停堆／供电灯效、普通兵种与游隼关联回归。`node --check`、图集方向唯一性、材质指纹、mipmap与目标diff空白检查通过。首次测试中JSON数字数组与整数数组相等比较失败，改为二维坐标值比较后重跑通过，未删除实际枢轴断言。

## 性能和环境边界

同一台RTX5060Ti、Godot4.7.2/OpenGL兼容渲染，64单位（直升机／机器人各32），1200帧、关闭垂直同步的专项场景：

| 指标 | 修改前 | 最终细节／光晕版 |
| --- | ---: | ---: |
| 帧时间P50 | 7.440 ms | 5.009 ms |
| 帧时间P95 | 9.992 ms | 6.587 ms |
| 绘制调用 | 225 | 225 |
| 绘制CPU P50 | 4.848 ms | 3.166 ms |
| 进程渲染纹理内存监视值 | 436,368,073 B | 475,820,925 B |

此场景没有观察到帧时间退步，新增光晕未增加绘制调用。更高分辨率／新增动作使纹理监视值增加约37.6 MiB；不把文件压缩体积当成显存占用。本结果仅适用于该64单位绘制负载，不是六方战斗性能验收，不能推导所有机器都加速。

证据根 `.validation/model-skins-20261118/`：`summary.json`、`assets.json`、各套件日志，`before_mixed/result.json`和`final_lights/result.json`，以及`post-run-audit.json`。实际源码来自当前工作区；独立用户目录逐次隔离；无服务、DB或网络协议依赖。GPU测试在未激活的私有Windows桌面完成，输入桌面保持Default。退出后检查本批Godot进程为零残留。

仅导出两次同一总览用于新增灯效前后检查，最终保留一张 `preview/models-runtime.png`。还需要用户在目标游戏环境确认精细度、模型造型、步态、大小与光源观感；不把GPU检查通过写成已达到概念图还原度。没有打包、提交或推送。

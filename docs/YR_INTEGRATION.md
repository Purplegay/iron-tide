# 尤里的复仇单位接入

## 2026-10-26：战斗要塞与盟军清单核对

补入此前完全缺失的 BFRT：战车工厂/实验室前置、原版资源和语音、5 人车内独立射击、
卸载、载具碾压、存读档与旧存档兼容。GGI、ROBO、GAROBO 是既有实现，并非此次重复添加。
完整名单、秘密科技和能力缺口、来源及复现见 [YR_FORTRESS.md](YR_FORTRESS.md)。
以下数量均是历史批次快照。

## 2026-10-23：机器人坦克与控制中心

ROBO/GAROBO 已增量接入真实生产、供电控制、两栖移动、武器、模型和声音。
当前为 43 个单位、22 个建筑；原版声音覆盖随 ROBO 入场增至 29 个原版 ID 加 3 个别名，
共 32 个目录单位。范围、剩余差异和本轮证据见 [YR_ROBOT.md](YR_ROBOT.md)。
以下批次的数字和阻塞均为对应历史时点，不能覆盖本段最新进度。

## 2026-10-23：原版单位语音扩展

从本机 Steam 尤复的 rulesmd.ini、soundmd.ini、audio.idx/audio.bag 生成独立
`data/ra2/yr_unit_voices.json` 与 `assets/ra2/sfx/yr_full/`，不修改单位规则和生产科技。
157 个源单位定义中，144 个有可导出的声音；共 362 组、1,400 段 PCM WAV，约 74.8 MB。
8 个原版零音量、无 Sounds 的事件记录为 intentional silence，不视为丢失素材。
双声道 grexselb 的最后一组存在 8 个未配对左声道采样，只输出完整立体声帧，不补造右声道。

当前 28 种原版 ID 单位全部获得映射，包括尤复谭雅、GGI、矿车、坦克、战机和海军。
扩展模式的征召兵、磁暴坦克、恐怖机器人仅按声音别名映射到 E2 / TTNK / DRON，
合计覆盖当前 31 种单位。铁锤、双刃、帝国和虫群等 11 种无直接原版对应的单位保留现有声音。
尤里阵营等尚未实现的单位只有预备语音映射，没有被加入生产栏或宣称机制完成。

载入顺序为基础 RA2 → 旧社区补充语音 → 原版 YR 按单位、事件合并。
没有可用覆盖时仍回退单位原有 voice 字段；武器和 EVA 保持现有来源。
选中/移动/攻击等玩家命令沿用全局声音；死亡/部署效果保留位置衰减和原有节流。
手动采矿命令使用 ChronoMinerHarvest，混选时只由实际接受采集命令的矿车回应。
VoiceEnter/VoiceCapture/VoiceCrashing 等扩展事件已导出，其中未有运行时触发入口的事件
仅准备数据；没有额外增加自动返场播报、捕获或坠机机制。

重建（输出必须为工程外的新目录，Python 3.12 用于独立 audioop 验证）：

```powershell
node ra2pipe/yr_voices.mjs '本地尤复目录' '新的外部候选目录'
python ra2pipe/yr_unit_voices.py '新的外部候选目录'
python ra2pipe/verify_yr_unit_voices.py '新的外部候选目录'
```

发布仅复制候选 project 下新增的声音目录与清单，然后执行实际 Godot 工程 editor import。
原始商业资源继续受项目忽略规则保护；本机转换不等于允许重新分发游戏素材。
1,400 段输出 PCM 与独立 audioop 解码逐字节一致。
本轮验证 2,014 项通过：yr_voice_regression 1,860、audio_lifecycle_regression 78、
command_voice_regression 76。覆盖全部 WAV 在 Godot 加载、当前 31 种单位的选中/移动/攻击
真实 WASAPI 输出、声音覆盖与缺失回退、两模式混选采矿声音、GI/GGI 部署攻击、位置衰减、
节流、EVA 及退出清理。独立 custom_user_dir；网络、服务、端口、数据库 none。
三轮工程指纹一致且交付时复核一致，发布的每段 WAV 与验证候选哈希一致，5 个源 MIX 未改动。
audio_lifecycle 退出有 6 个 ObjectDB 实例残留警告，未宣称无资源泄漏；其播放状态清理断言通过。
证据：`C:/Users/admin/Temp/iron-tide-yr-voices-20261023/delivery-audit.json` 及各专项 reports。
声音的实际音色、音量体验仍为 `pending_user_visual_confirmation`（听感待使用者确认）。

## 2026-10-23：第一批重装大兵已接入

实际运行目录 `C:/Users/admin/IronTide/iron_tide` 已加载独立 `data/yr_allied.json`，
在两种既有规则模式的盟军兵营中增加重装大兵 GGI。价格 400、生命 100、速度 3×15、视野 6×55，
前置 GAPILE；生产沿用本工程逐步扣费、每兵营独立队列和现有模式时间规则。

站立 M60 / 精英 M60E；按 D 或命令栏部署后固定使用 MissileLauncher / MissileLauncherE，
射程 8 格、最小射程 1 格，可对地/对空，使用 GUARDWH 的护甲倍率、追踪导弹和 DRAGON 弹体。
部署不可移动、不可被普通 Crusher 碾压；收起后恢复移动、机枪与可碾压状态。
GGI 的部署不等同卧倒，不额外获得 ProneDamage 折扣；扩展模式也没有给 GGI 添加 GI 的部署攻击/防御倍率。
切换姿态即时刷新射程、防空、最小射程、精英武器及碾压属性。

资源：744 帧原始 SHP（372 主体帧及阴影），原始图标，10 组 / 36 段语音与音效，
含选择、移动、攻击、受惊、死亡、部署/收起、机枪和导弹开火。蓝色/紫色八方向站立、部署与开火截图已人工检查。
部署按钮提示改为导弹、防空及近距盲区，避免让它沿用美国大兵的卧倒提示。

数据从 Steam 本地档案生成；复用原工程规则解析、美术解码、音频解码，不复制参考 GitHub C++。
武器、弹头、弹道和声音 ID 采用 YR_ 前缀，原 RA2 同名数据和补充语音包不被覆盖。
只发布 GGI 所需数据和素材；候选目录中完整 YR 归一化表不覆盖运行目录的 RA2 表。

重建（输出必须是工程外全新目录）：

```powershell
node ra2pipe/yr_guardian.mjs 'C:/Program Files (x86)/Steam/steamapps/common/Command & Conquer Red Alert II' 'C:/Users/admin/Temp/新的GGI候选'
python ra2pipe/yr_guardian_audio.py 'C:/Users/admin/Temp/新的GGI候选'
```

发布仅使用候选 `project/data/yr_allied.json`、`project/assets/ra2/shp/GGI.*`、
`project/assets/ra2/cameo/GDGIICON.png`、`project/assets/ra2/sfx/yr_ggi/`。
实际游戏目录已完成 Godot editor 资源导入，使用原有 `启动游戏.bat` 重启即可加载。

验证共 692 项通过：GGI 154、美国大兵部署 22、智能选敌 60、多工厂生产 192、旧单位开火 188、
美国大兵与 GGI 的真实 WASAPI 指令音频 76。GGI 专项覆盖双方、两种模式、实际兵营扣费出兵、
真实弹体命中、空地目标/最小射程、普通/精英武器与碾压。36 段 PCM 与独立 audioop 解码逐字节一致。
测试均使用独立 Godot 副本与 custom_user_dir；无服务、数据库、协议连接。回归后源档案哈希一致，
各专项记录的运行代码/数据/素材与当前版本一致；早期专项后仅扩展音频测试源码和产生 Godot 导入元数据。
智能选敌回归仍有 2 个 ObjectDB 退出泄漏警告，本批未处理该既有问题。
证据：`C:/Users/admin/Temp/iron-tide-ggi-20261023/delivery-audit.json` 与各 suite/reports。

范围限制：这是首个可生产尤复增补单位，未加入机器人坦克、控制中心或完整尤里阵营。
IFV 乘员变武器、开顶运输射击、部署/收起过渡动画仍未实现；既有运动、弹道几何与老兵规则的近似保持。
站立/部署与开火动作、语音资源已客观验证，最终体验状态为 `pending_user_visual_confirmation`；不宣称完整尤复复刻。

## 2026-10-23：Steam 原版资源已就绪

用户请求下载安装并在 Steam 确认后，app 2229850 已安装完成，BuildID 15918130。
Steam 日志显示 Fully Installed / No Error；BytesDownloaded 与 BytesToDownload 均为 1522404256，
BytesStaged 与 BytesToStage 均为 2090337575。安装路径：
`C:/Program Files (x86)/Steam/steamapps/common/Command & Conquer Red Alert II`。

真实资源执行 `yr_intake.mjs` 成功，输出
`C:/Users/admin/Temp/iron-tide-yr-steam-20261023/inventory.json`。
rulesmd.ini 来自 expandmd01.mix，artmd.ini 来自 ra2md.mix / localmd.mix；源文件哈希经工具末尾复核一致。
扫描 157 个单位定义，其中 67 个条目有依赖缺项，待区分非生产/历史条目与工具覆盖缺口，不能解释为 Steam 安装损坏。
GGI、ROBO、INIT、BRUTE、YTNK、YURI、YURIPR 的本工具依赖存在性检查均通过。
这解除了下文的历史资源阻塞；尚未接入 Godot 生产栏，也未证明模型动作、音频或特殊机制可用。

## 2026-10-21 接入准备记录

2026-10-21：用户要求在现有 Godot 工程接入尤复单位，并指定 RA2YR_ReSource。
本批完成参考仓库固定与资源接入检查；**尚未接入可生产的尤复新单位**。

## 已核实的输入与缺口

- 参考版本与许可事实见 [SOURCES.md](SOURCES.md)、source-lock.json。它提供逆向工程代码，不能代替游戏素材包。
- 现有 Chatbox `refs/ra2pack/full` 只有 RA2.MIX、LANGUAGE.MIX 等原版文件，实际读取未发现 rulesmd.ini / artmd.ini。
- `refs/yr-voices` 是原版 RA2 使用尤复语音的补充包；其 rules.ini 不含完整尤复兵种表，不能更名后用作尤复规则源。
- 当前项目、原 Chatbox 资源目录、已登记 Steam 库未找到尤复安装资源；这不代表扫描了整台磁盘。
- 真正接入仍需本地尤复游戏目录，通常包含 ra2md.mix、langmd.mix 及基础 RA2 资源。已经通过异步问题请求用户提供路径。

## 本批工具

```powershell
node ra2pipe/yr_intake.mjs '本地尤复目录' 'C:/Users/admin/Temp/新的候选目录'
node --test ra2pipe/yr_intake.test.mjs
```

候选目录的父目录必须已存在，目标目录必须全新且位于游戏源目录和本工程之外。
工具只读输入，输出 inventory.json；规则识别通过时另保存原字节 rulesmd.ini、artmd.ini。
不会改游戏运行数据、生产按钮、资产或玩家存档。

检查内容：单位清单、阵营 Owner、价格、科技等级、普通/精英/多段武器、弹头/弹道引用、
通用前置建筑候选、主体/图标/VXL 配套 HVA 的存在性、步兵动作序列引用和来源哈希。
炮塔/炮管可以内嵌在主体 VXL，单独组件只记录不强制判缺。
保留全部单位原始规则字段，供后续逐机制审查；不擅自将未知特殊字段转换为普通伤害。

读取顺序：RA2.MIX → LANGUAGE.MIX → RA2MD.MIX → LANGMD.MIX → EXPANDMD01.MIX → 同名松散文件。
后层覆盖前层，不按文件大小决定优先级。只递归已登记的 MIX 容器名称，未知容器需扩展并测试。
不自动加载其它 mod 档案；松散规则可包含修改，清单不认证原版纯净性或补丁版本。
复用原工程已有 MIX 解码器，未从本次 GitHub 仓库引入解码或游戏实现。

状态：

- `blocked_missing_yr_inputs` / `blocked_invalid_yr_inputs`：缺输入或无法确认为完整可盘点的尤复规则；CLI 退出 2。
- `inventoried_not_integrated`：已完成清单，不等于可玩；单个单位仍可能 `blocked_dependencies`。
- `requires_mechanism_and_render_validation`：依赖存在检查通过，仍须解码、模型/动作、武器、生产、特殊机制验收。
- 损坏 MIX、源文件变化、非法路径或已有输出目录：明确失败，CLI 退出 1。

资源存在不等于图片有效。本批尚无真实尤复资源，因此没有验证尤复加密档案、完整兵种美术或游戏内表现。

验证：`node --test ra2pipe/yr_intake.test.mjs` 的 8 个测试通过，覆盖嵌套档案与短文件覆盖优先级、
松散文件优先级/输入变化、武器和通用前置、缺件归因、原版伪装尤复、损坏档案、外部原字节暂存及 INI include 拒绝。
真实本地 RA2 档案读取结果为预期缺少 rulesmd.ini/artmd.ini（退出 2），不是尤复导入通过。
测试后重算两个档案哈希，与输入记录一致；环境仅本地 Node.js，无服务、数据库、端口或 Godot 运行态参与。
证据：`C:/Users/admin/Temp/iron-tide-yr-intake-20261021/audit.json`、`tests.tap`、`local-ra2-check/inventory.json`。

## 后续实施顺序

1. 拿到尤复目录，盘点实际版本与单位依赖。先接现有盟军生产体系的重装大兵；核对部署双武器、对空/对地和精英升级。
2. 机器人坦克及控制中心：同时处理断电/控制中心失效、机动与目标判定，避免只增加模型。
3. 苏军尤复增补与其生产科技前置；现有工程的苏军原版体系也需补齐，不能将其单位塞到盟军兵营。
4. 尤里阵营生产体系及单位：分别实现心灵控制/释放与免疫、加特林升档、磁电、奴隶采矿及归属转换。
5. 分批接语音、图标、完整动作与特效，在 RA2/扩展模式下各自回归；保持现有矿场造矿车、多工厂队列、QWER 技能约定。

上述是待执行范围，不是完成清单。每批以实际规则数据和行为断言确定边界，不采用参考仓库空函数作为“实现”。

# 《放学后，雨停以前》 · v0.31.40

## v0.31.50 礼物每日加价与折扣

每件礼物按本地日期和礼物 ID 独立报价。加价与打折的概率为 95% 和 5%，取代 v0.31.47 的十二档等概率规则。原价 500 战略核心，最低七折（350），最高原价的 150%（750）。一百个等概率结果中的加价合计与优惠合计各为 500 核心，所以长期均价仍为 500。多数加价幅度较小；按钮显示实际核心价格及涨跌百分比，例如「501 战略核心（加价 0.2%）」。物品购买后入库，已持有物品可以直接赠送。

Godot 隔离手记回归 1208 项通过。穷举了一百个报价结果，并按三种礼物采样 366 个日期，核对同日稳定、独立涨跌、商店两端价格与小幅加价文案、跨日旧报价拒绝、实际扣款和写盘失败回滚。日志在仓库根 `.validation/yuriko-score/gift-markup95-accept-console.log`。

## v0.31.49 说话人同步与玩家名字

阅读器从当前台词或选项取得一个说话人，同时决定右侧人物和对白框头像。百合子沿用场景服装，小满、陈姨和四个通用路人使用从原画导出的 1024 × 1024 WebP。旁白只显示场景和文字。指挥官（含港口递饭时署名「男人」的台词）和由指挥官回答的选项只显示玩家名字。这一规则取代 v0.31.46 给指挥官展示头像、右侧固定显示百合子的做法。

主菜单设置可保存个人名字。自定义名为空时 Windows 读取 USERNAME，macOS 读取 USER、其次 LOGNAME；只有自定义名写入本地个人存档。两者都为空时，设置按钮显示红点，剧情临时称呼「指挥官」。重新输入或清空名字后，菜单和阅读器均重新取值。

Godot 4.7.2 在 Windows 隔离档验证手记 962 项、残章与赠礼 266 项通过。覆盖修车阿姨等配角的两处纹理相同、服装随章节切换、旁白和玩家回合收起人物、设置红点、设置起名及清空后恢复账号名。macOS 的取名优先级使用模拟环境变量验证，未在 Mac 实机运行。日志在仓库根 `.validation/yuriko-score/speaker-name-accept-console.log` 与 `speaker-choices-console.log`。

## v0.31.48 远征残章《潮线以外》

此前记录的三篇残章保留为第 1–3 篇。《潮线以外》占第 4–14 篇，讲百合子为搬家的港区居民画投递地图。十一篇各有两个选择，依次用到港口、面包房、泳池、屋顶菜园、图书室、家政教室、广播室、鱼市、海边站台、教室和夜间观星台。阅读器按篇目配置取整图或九宫格图块。手记目录中的「远征残章」可直达「私信与礼物」。

普通地面小队完成带战利品的远征目标并获胜，会带回首个未收集的残章。集齐后仍可带回礼物。取得新章时开放阅读；首次读到结尾并保存才增加一级好感，与赠礼共用现有等级和三选一加成。满级 100 仍能阅读。已读、所选分支和首读奖励在同一次档案保存中提交。主线与日常继续提供原有灵能点。

Godot 4.7.2 无窗口隔离档案验证，远征残章 266 项、校园手记 922 项断言通过。覆盖从驻防基地和手记进入、实际远征胜利拾取、11 处阅读背景及两条分支、15 个灵能天赋已学满时首读、重读、保存失败后重试、读档和好感上限。日志位于 `.validation/yuriko-score/tide-letters-20261125015118/` 的 `yuriko_bonds_regression.log` 与 `yuriko_school_regression.log`。画面观感留待试玩。

## v0.31.47 章节衣装和礼物每日价格

实验服初始可用，校服 II 需要已读第五章《靠窗第三排》（desk），校服 III 需要已读第八章《放学以后也能找到我》（letter）。拿到章节但未读完时仍锁定，首读结束提示解锁。试衣间、默认出战装、战场换装菜单与旧存档角色模型按相同资格取值，已解锁可免费切换，GM 剧情全开包含两套校服。替代旧版三套从开局就能免费换的规则。剧情立绘仍按场景服装展示。

「私信与礼物」中三件礼物既可从远征委托带回，也可购买。支付现有局外战略核心（cores）。按本地日期和礼物 ID 确定当日价格，基准 500，上下 5%、10%、15%、20%、25%、30% 十二档等概率；每种礼物的理论均价为 500，同一天三种礼物的算术均值可有波动。页内显示持有数量、核心余额、价格与涨跌幅。跨日旧报价须按新价格重新点击。购买只入库；另行送出才增加好感，赠送高中制服也遵守穿戴的章节要求。

Godot 4.7.2 隔离回归：手记 922 项，远征残章与赠礼 247 项，战斗 182 项通过。检查 100 个日期的稳定报价和涨跌、余额不足、跨日点击、实际购买三个品种、存档写入失败时扣款和库存一并回滚、读档与章节切换、战场锁定和 GM。存档失败警告来自专项注入。日志在仓库根 `.validation/yuriko-score/wardrobe-market-final-console.log`、`gifts-bonds-console.log` 和 `gifts-score-console.log`。本轮用后台运行验证，未接管玩家窗口。

## v0.31.46 剧情对话头像

八章主线、九项日常及三篇残章共用同一个阅读器。对白框左侧显示当前发言人的 96 像素头像。小满、陈姨和指挥官有各自的面孔。早期送饭的「男人」沿用指挥官的头像，名字在剧情揭晓前仍显示「男人」。百合子沿用本场景衣装，旁白收到一整行文字空间；选项显示作决定的人，《末班车还早》由指挥官选择。剧情正文、分支和阅读书签沿用原数据。

四张通用头像依次为路人甲（成年男性）、乙（男学生）、丙（成年女性）、丁（女学生）。九种未具名说话人按固定的身份表分配，其中剧本未指定性别的配角按年龄和场景选角。姓名栏例如「路人乙 · 园艺委员」。说话人映射位于 `scripts/screens/yuriko_school.gd`，运行资源位于 `assets/ra3/yuriko/school_days/cast/`，七张均为 384×384 WebP。

Godot 4.7.2 隔离验证通过。手记测试经主菜单读完所有主线与日常、重读另一条分支并核对实际对话节点，896 项通过，覆盖全部 13 种配角说话人标记、百合子和旁白。残章与赠礼测试 103 项通过，包含六次选项的头像与姓名检查。报告位于仓库根 `.validation/yuriko-score/npc-cast-school-console.log` 和 `npc-cast-bonds-console.log`。七张原图和头像总览在 `.validation/yuriko-score/npc-import/`。本轮没有启动可见游戏窗口或抓取游戏截图。

<details><summary>头像生成提示词</summary>

内置 ImageGen 分别生成七张图。每次使用下面的共同提示，再接对应的角色描述。原图为方形，以 Godot Lanczos 缩小并编码成游戏头像。

Use case: illustration-story. Create one square dialogue speaker portrait for a Japanese slice-of-life visual novel set in a recovering coastal town. Hand-drawn anime with restrained clean graphite-brown outlines, matte watercolor colors, soft daylight from upper left, warm fair paper background. Single centered ordinary East Asian person looking nearly forward, full crown and shoulders comfortably in frame, face large and instantly readable at 80 pixels. Modest everyday clothes, natural proportions, quiet facial expression. No scenery, props in front of face, letters, badge, frame, text or watermark.

- **xiaoman**　Xiaoman, a cheerful high-school classmate with a tidy chin-length dark chestnut bob tucked behind one ear, a small ochre barrette, lively eyes and a slightly crooked grin. Navy school blazer with white collar and muted burgundy ribbon.
- **chen**　Aunt Chen, a practical woman around fifty who runs the harbor resettlement desk. Gently weathered face, gray streak in dark hair tied into a small low bun, sea-green knit cardigan over a sand-colored blouse, attentive expression.
- **commander**　A young adult male commander on his day off, kind and unassuming. Short wind-tousled dark hair with a soft side part, warm dark eyes, faint tired smile, faded olive work jacket over an off-white crewneck. No cap, insignia or weapons.
- **passerby_a**　Generic male townsman, about forty, broad roundish face, short cropped hair, slight smile lines, a faded indigo work shirt over a neutral undershirt. A very ordinary local tradesman.
- **passerby_b**　Generic male youth, senior high school age, straight dark hair with a center part and slender oval face, an ordinary grey cardigan over a cream collared school shirt. Quiet friendly expression.
- **passerby_c**　Generic female townswoman, around forty-five, short wavy dark-brown hair, softly squared face, practical ochre collared shirt. Sensible and approachable; an ordinary local woman.
- **passerby_d**　Generic female high-school student with a plain low ponytail, wispy bangs, small round spectacles and a reserved half-smile. Plain muted blue cardigan and white collared shirt, understated.

</details>

## v0.31.45 雨棚初遇、破碎残章和送礼

驻防基地的独立栏初始显示带锁的「？？？」。远征 Oceanside（`yr_oceansid`）有一座能被地面单位走到的雨棚，探索后能看到实物，任务列表和小地图都不给线索。自有地面小队走近后触发已有录音 YurikoTensionb。若正在播核弹提示，先播放完提示。听见线索且该关获胜才永久开放栏目和第一章。已经有已读主线的档案会保留入口。

- 读完当前章以后，第二至第四章分别由普通小队完成附带遗物的远征委托并获胜带回。第四章重逢后，可接「没有编号的回信」情报委托，获胜招募本轮的百合子。再往后的四章需要先读当前章，由百合子接近战场的粉色秘密档案，再赢下该关。档案有独立的定位按钮和粉色小地图标记。所有主线解锁后停止生成。
- 普通小队在初遇前就能拿到破碎残章和礼物。每个带遗物的委托在本关胜利时给一件礼物和第一份尚未收集的残章，残章集齐后继续给礼物。战斗存档保留现场情况；远征先保存胜利，每个远征 ID 与关卡编号只向个人档案补发一次。
- 基地和主菜单进入同一份手记。「私信与礼物」可逐句阅读《瓶底的纸条》《袖口留一寸》《末班车还早》，每篇两种回答，记录首选。玻璃瓶可乐、南汐高中制服、旧电车纪念票均有专属图标、库存、首赠和再赠台词；首次送出一种好感 +2，再送同种 +1。每篇各记得一件礼物，好感达 4 时末班车上她会主动约指挥官一起走。好感与灵能点分别记录。GM「一键解锁百合子栏目与剧情」开放章节、残章阅读与远征召唤；原有阅读选择、礼物数量和好感保留。
- 本节取代下文 v0.31.40 的「新档即可进入」和「期末才开始远征招募」；读完主线后自动切到日常仍生效。三篇支线文本、赠礼回响与好感台词在 `data/yuriko_side_letters.json`，后续可按稳定的残章编号续写。
- Godot 4.7.2 隔离存档验证通过。新支线 97 项（含真实基地按钮、三篇六条对话分支、未探索获胜、探索战败、读档后胜利，以及第四至第八章）；手记 531 项，远征百科 824 项，综合战斗 161 项，超武警报与侦察存档 196 项。录音验证经过 Dummy 音频驱动，战斗使用真实结算入口，胜负由测试注入。没有打开玩家窗口或截图。证据可查仓库根 `.validation/yuriko-score/` 中的 `bond-accept-console.log`、`bond-school-accept-console.log`、`bond-guide-final-console.log`、`bond-combat-final-console.log` 和 `bonds-fog-report/result.json`。

## 故事和玩家入口

主菜单 → 百合子手记。新档即可进入，四页分别为手记、日常活动、灵能练习和试衣间。最后离开研究所、回到地面望向东京，是《起义时刻》百合子战役的收束。港区安置点、南汐高中、小满、陈姨及与指挥官交换晚饭，是 Iron Tide 从这个时刻起写的续篇。[终章梗概](https://cnc.fandom.com/wiki/Ruin_and_Reunion)

八章依次为《门从这边开》《铝盒里的锅巴》《不在地图上的星期三》《这次由我请你》《靠窗第三排》《预演的铃声》《把灯留到八点》《放学以后也能找到我》。指挥官把饭放在百合子选的位置。重逢时她请他吃饭，问复学手续；他陪她选联系人，填表和上学的决定由她自己做。日常包括面包店、泳池、天台种番茄、借书、缝校服、广播、买鱼做饭、错过电车与观星。脚本在 `data/yuriko_school.json`。190 段独立对白与旁白，含两个分支与回响共 7,643 个汉字，排除人名标签、标题、选项按钮和标点。每篇两条路线，共 34 个选项。首次晚饭和演习的选择分别在重逢与开放日被提起。

## v0.31.44 读完主线后切页

终章《放学以后也能找到我》首次记入手记并保存成功后，界面切到「日常活动」。已完成主线的档案下次进入时也落在日常页，可以手动回到手记重读。两页的「继续阅读」各自优先续读本页中断的篇目，其次推荐本页可读的未读篇目。Godot 隔离回归从主菜单读到终章、切页、返回主菜单并重新进入，共通过 529 项断言。日志为 `.validation/yuriko-score/school-tabs.log`。

## 读档、练习和战斗

本地 MetaProgress 的 `yuriko_school` 记录各篇的首次选择、当前句和分支、习得节点与衣装。故事逐句保存，可从中断处继续或重读另一条路线。前两章给读者认识她的时间，从第三章起每章首读得 1 点，另有九项日常各给 1 点。总共 15 点。读完不同分支不会重复发点。六系、等级、前置和消耗取自起义商店已导入的树。已习得的护盾持续 5／7／9 秒，心控上限 3／5／7，念力投掷随等级扩半径、缩冷却；速度、生命、攻击各两级。灵能练习可打开原有技能演示。战斗菜单读取已习得状态，养成购买在手记。

期末由她主动寄信。远征至此才会生成她的专属情报委托，百科同步打开信件内容。完成该委托且赢下该关才会入队。已承接且存下的有效委托仍可交付。该条件适用于远征，扩展遭遇战可从完工兵营直接召唤。战斗存档保留当前战场的状态。开启新战场会取个人档案的习得节点及默认衣装，历史远征里已习得的节点一并沿用。v0.31.39 中关于点数来源待定及随地图购买的记录到此截止。

## 画面和证据

校园与港口用原创场景图。v0.31.40 在阅读及试衣时均使用《起义时刻》的原版 3D 骨骼模型。自 v0.31.43 起，阅读页改用按剧情指定的正面立绘。实验服 52 骨，两个校服版本同一套 36 骨网格，保留各自的章节动作与灵能色。试衣间可选衣装、切换待机／走动／施法、拖动旋转或用按钮旋转与缩放。服装选择落入本地档案，可在新战场召唤时核对。

Godot 4.7.2 私有验证目录 `.validation/yuriko-score/`。场景 `res://tests/yuriko_school_regression.tscn` 通过 484 项断言，从主菜单逐篇读完两个分支，验证续读、防重复发点、全部 15 项练习、W 三级演示、换装和存读，再从实战兵营召唤并施放九秒护盾。战斗专项 `res://tests/yuriko_score_regression.tscn` 通过 152 项，含远征招募和阵亡。百科 `res://tests/expedition_field_guide_regression.tscn` 通过 824 项，覆盖寄信前后情报的显隐。日志见 `school-vn-final.log`、`school-combat.log`、`school-guide2.log`。独立图形桌面在 RTX 5060 Ti 上验证对话场景与三种衣装渲染、旋转后的像素变化和对话按钮边界；结果在 `school-gpu/render.log`。图形验证只读内存像素。阅读节奏和最终观感留给玩家试玩。

## v0.31.42 试衣间旋转方向

试衣间的横向拖动与左右转按钮采用相同的屏幕方向。按住模型向右拖时，面向镜头的一侧向屏幕右方移动，松开后停止转动。三种衣装各验证左右拖动、松开和左右按钮；依据模型表面参考点的相机投影判断实际方向。Godot 4.7.2 无窗口与独立 GPU 桌面各通过 499 项手记断言。日志在 `.validation/yuriko-score/rotation.log` 和 `.validation/yuriko-score/rotation-gpu/render.log`。

## v0.31.43 剧情正面立绘

阅读页显示日系动画正面大头立绘。前两章用毛边旧实验衣，第三章领钥匙时已换上陈姨借的青绿开衫，重逢时沿用。入学后换藏青校服。鱼市、周末电车用开衫，泳课用训练服和泳镜。17 篇各自的 `portrait` 字段决定衣着，重读和续读可还原该场景。试衣间与战场继续使用原版 3D 模型。

内置 imagegen 生成了两张透明 PNG。前三套衣装共用 `assets/ra3/yuriko/school_days/story_portraits.png` 的三个 724 × 724 区域。泳课立绘 `assets/ra3/yuriko/school_days/story_swim.png` 使用该图集作为人物参考。校验了 RGBA 通道与分格边缘。Godot 手记回归 518 项通过，覆盖每篇实际显示的衣装，以及装备第三章战斗衣装后重读救济所。RTX 5060 Ti 图形验证在四个场景各检查脸部位置和透明背景合成，八项通过。过程未保存游戏截图。日志位于 `.validation/yuriko-score/portraits.log` 与 `.validation/yuriko-score/portrait-gpu/render.log`。

《预演的铃声》续读复核：截图对应的窗口先于 v0.31.43 立绘接入启动。使用隔离档案、相同的 IronTideRuntime.exe 及 2210 × 1247 窗口，经「继续阅读」恢复该章并翻页，确认两页都显示校服正面立绘，脸在对白框上方。日志为 `.validation/yuriko-score/bell-resume-gpu/render.log`。

<details>
<summary>人物立绘生成提示</summary>

**旧衣、开衫、校服图集**

Produce one production RPG visual-novel transparent character sprite atlas, wide horizontal canvas roughly 3:1, exactly three equal side-by-side cells in ONE ROW. Each cell is a single front-facing bust portrait of the SAME character Yuriko Omega for a Japanese high-school slice-of-life visual novel, anime illustrator key art. Full alpha transparent background between and around all figures; no panel art, scenery, typography, UI, shadows cast onto background, frames, or swatches. All three portraits are aligned identically, centered at x=1/6, 1/2, 5/6 of canvas, same eye height and scale. Each figure fully fits its cell, including both pigtails, with a clean transparent gutter. Head-and-shoulders close-up with a noticeably large head, crop the torso just below the collarbones/upper chest; faces occupy most of the height. Perfectly FRONTAL straight-on head and shoulders, eyes meeting the viewer; both eyes and ears evenly visible, nose at midline, no angle, no profile. Memorable expressive dark violet eyes, black hair divided into two ribbon-bound high short ponytails, disheveled wispy bangs parted slightly off-center, small nose; the identical teenage Japanese schoolgirl throughout. Carefully art-directed shoujo / Japanese galgame cel painting, fine hand-drawn tapered ink, warm reflected light, restrained painterly edges, detailed hair highlights. Left: just rescued, guarded tired expression, modest faded off-white high-neck institution smock with frayed collar, sewn repairs and dusty scuffs, plain cloth ties; garment remains intact and fully covering her. Center: beginning to trust the world, slightly curious expression, wearing a borrowed moss-green cardigan over an ivory crew-neck tee, no school insignia. Right: same girl after enrolling in high school, hopeful subtle smile, neat navy Japanese school blazer, cream shirt collar, small burgundy ribbon bow. Goal is legible storytelling in three isolated oversize-head sprites; absolutely no props or writing. Clean alpha contours of the hair.

**泳课**

Use the attached approved three-stage portrait sheet as the exact character, rendering and crop reference. Generate ONE square, single-character, transparent bust sprite for the swimming-practice episode in the same Japanese visual novel. Match the middle portrait's facial proportions, same straight-on gaze, dark violet eyes, near-black hair in twin ponytails with small burgundy ties, same eye height at about 43% of canvas, same head scale and linework. One girl only, centered, looking directly at reader, full face and both ponytails visible, gentle concentrated expression. Instead of the cardigan wear a modest, fully zipped, high-neck navy swim-team rashguard with subtle pale blue shoulder piping, blue swim goggles pushed up into her hair. Crop just below collarbones, full upper shoulders, no arms or hands, no scenery, no text, no logo, no sheet grid. Keep transparent background and clean antialiased edges, match the reference's head-dominant square crop.

</details>

<details>
<summary>AI 场景图来源与生成提示</summary>

内置 imagegen 生成，资源在 `assets/ra3/yuriko/school_days/`。PNG 按原始输出保存。活动图在运行时按格取景。

**classroom.png**

Create one wide 16:9 background illustration for a premium Japanese slice-of-life visual novel titled After School, Before the Rain Ends. No lettering or text in the artwork. An empty small coastal Japanese high school classroom after a spring shower, viewpoint from the back beside the open classroom door. Beautiful precise hand-painted anime background art, luminous overcast pearl light and muted sea-green chalkboard, warm honey wood desks, tall rain-streaked windows with green plane trees and distant harbor hillside, a single folded transparent umbrella beside an empty chair. Quiet hope and postwar rebuilding, subtle repaired windowpane. Asymmetric cinematic perspective, main window light on the right, readable subdued left and lower quarter for Godot UI overlay. No people, no HUD, no labels, no lettering, no collage.

**harbor.png**

One cinematic widescreen 16:9 painted anime game background for a quiet Japanese slice of life visual novel, no people or text. A modest postwar Japanese harbor tram stop and small improvised canteen beside the breakwater at dawn after rain. Inside of a weathered open-sided waiting shelter, a warm glowing pot with stacked aluminum lunch tins and an enamel mug on the wooden counter on the right, glass door standing ajar; damp stone glistens, misty fishing boats and pale blue mountains beyond. Subtle signs of repaired storm damage. Painterly realistic details, delicate gouache textures, cool desaturated sea green balanced with amber light, carefully composed lived-in space. Large, uncluttered left-mid and lower quarter suitable for a UI overlay. No text, no logos, no graphic overlay.

**activities.png**

A single production-ready visual novel environment texture atlas, perfectly regular 3 columns x 3 rows of equal rectangular landscape panels, edge-to-edge NO gutters, NO frames, NO lettering, NO people. Overall canvas 16:9 horizontal. Softly hand-painted Japanese animation backgrounds for one coastal high school's first semester, gentle perspective, quiet signs of use. Each of nine full-bleed cells is a separate complete landscape composition. Top row left to right: 1) neighborhood bakery at 4:30pm, trays of braided bread, 2) blue tiled indoor swimming pool with kickboards in pale daylight, 3) breezy school rooftop garden with potted tomato vines. Middle row: 4) warm small school library with old borrowing cards at a wood desk, 5) sewing classroom with vintage machines and a school uniform button on a worktable, 6) a small school radio booth with analog mixer and microphone looking through a rainy window. Bottom row: 7) port fish market in morning light, 8) small quiet Japanese electric train platform at sunset, 9) night-time rooftop astronomy club with one telescope, azure night and a thin crescent moon. Consistent artist and perspective scale throughout, rich but readable, no human anatomy or characters. Exceptionally strict grid, all cells same dimensions.

</details>

## v0.31.50 剧情 NPC 透明立绘

v0.31.49 接入的六张 NPC WebP 原为无透明通道的纸底头像，在阅读器放大后会遮住场景。小满、陈姨与路人甲乙丙丁现使用带透明通道的 1024 × 1024 WebP；同一份贴图用于右侧人物和对话框头像。指挥官发言仍只显示名字。

六张图均以内置 imagegen 对原头像去底，统一提示为「只移除人物外侧的米色纸底，保留身份、表情、水彩纹理、服装与方形构图，用真实透明通道保留碎发边缘」。导出后逐图核对 Alpha，完全透明区域占 36.5%–44.0%。Godot 4.7.2 在六人的实际剧情台词上比较立绘开关，人物脸部可见，透明区域露出原场景，小头像与右侧人物引用相同。手记回归 1237 项通过。报告与小满在教室的实渲图位于仓库根 .validation/yuriko-score/npc-cutouts/。

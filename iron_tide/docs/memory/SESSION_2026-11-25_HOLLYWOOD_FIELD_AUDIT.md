# 洛杉矶武器表现、反应炉及字段核对

依据本机 ALL02UMD.MAP、rulesmd.ini、artmd.ini 和 MIX。tools/hollywood_field_audit.mjs 生成原图预置对象和 TaskForces 引用的 148 类型清单，保存源规则、地图覆盖、美术和武器引用至 HOLLYWOOD_NATIVE_FIELD_INVENTORY.json。tests/hollywood_campaign.tscn 的 --native-fields 在开局取实例定义，缺席时查询目录，记录于 HOLLYWOOD_RUNTIME_FIELD_AUDIT.json。核对生命、装甲、造价、供电、额外供电、驻军容量和主武器。原值保留供后续按行为追查。

111 类找到同编号定义，37 类缺同编号定义，含 YURI、YTNK、SMIN、YENGINEER、民车、平民及片场演员等。人物当前借用 SNIPE、GGI、GHOST，居民使用 CTECH。两座尤里基地完整生产和任务队调度、心灵感应器专属探测仍待实现。NAFLAK 的关卡造价及电力覆盖仍未应用到本关目录，开局同编号实例为零。缺失定义、可查询定义和实际在场人数可按编号查运行时清单。

武器包收录新兵、狂风和盖特机炮关联的 18 个武器与 7 个弹头。新兵 PsychicJab 的 SAFlame 在命中处播放 INITFIRE，狂风 ATGUN 播 GUNFIRE，盖特炮按方向取机枪火光。空炉 300，InfantryAbsorb、Passengers=5、ExtraPower=100、SizeLimit=15，满血满员 800。工程师可接管。入炉人员不在炉内开火，撤出后失去对应供电，满空两种炉体随人员切换。调整 CALA05、CARUS08、CARUS10、CARUS11 的关卡禁止驻军覆盖。上述新行为按新开局验证。

Godot 4.7.2 隔离 APPDATA，从战役指挥室进入。--native-fields 38 项通过，工程师接管、右键派人、实测电网与满载拒绝第六人、撤人扣电，捕获实战 INITFIRE，调用实际特效播放器检验六套盖特武器和狂风普通主炮。--city-house 30 项通过，胜利流程 58 项通过。日志 %TEMP%/it-fields-final-{native-fields,city-house,win}.log。精英武器逐项实弹、盖特连射节奏、全部音效、旧存档恢复和完整难度流程仍待运行验证。
## 工程师占领机械维修厂

2026-11-25，工作区版本 0.31.51。玩家确认目标是截图右上的 CAMACH。ALL02UMD 的该设施无占领覆盖，原版规则为 Capturable=yes、NeedsEngineer=yes。关卡按城市建筑生成它，通用建筑目录缺少 CAMACH 条目，旧工程师指令因而拒绝占领。现在洛杉矶城市建筑缺少显式占领字段时，工程师读取原版类型的 capturable。实例和通用目录已有的显式值继续优先。民房驻军有单独的兵种和容量判定。

Godot 4.7.2，隔离 APPDATA，从战役指挥室进入，tests/hollywood_campaign.tscn -- --shop-capture 共 34 项通过。侦察员提供视野，工程师从厂外街道接受右键命令，物理步推进后厂房加入玩家建筑组并消耗工程师，快照恢复后仍归玩家。普通步兵和显式禁占的实例均拒绝。验证使用新开战局及该局快照，未读取玩家存档。

本关回收厂掉落资金箱已接入 assets/maps/yr/field_crate.png（CRATE.TEM 第 0 帧、ISOTEM.PAL）。保留视野判定及“资金箱”文字。常规胜利回归 60 项通过，覆盖四座回收厂各自掉箱、拾取收益和结算。两次 headless 均退出 0。日志位于仓库根 .validation/camach-capture-20261125/{capture-ok,victory-ok}.log。未做窗口画面验收或打包。

## 第二关的科技医院与机场伞兵援助

2026-11-25，0.31.51 工作区。直接读取本机 Steam 游戏的 mapsmd03.mix / ALL02UMD.MAP 和 expandmd01.mix 内的 rulesmd.ini。原图 SHA-256 为 168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303，规则为 3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef。

- 原图 (114,178) 的 CALA05 是可维修、可由工程师占领、禁止出售、禁止步兵驻军的洛杉矶国际机场。关卡覆盖 BaseNormal=yes、SuperWeapon=ParaDropSpecial。玩家占领后取得机场建造范围和独立的机场伞兵按钮。规则 Type=ParaDrop、IsPowered=false、RechargeTime=4、ShowTimer=no、DisableableFromShell=no、SidebarImage=PARAICON。盟军每批 6 名 E1。原图还明确给 AMRADR 设 SuperWeapon=none，本关自建美国空指部无 8 人空降。原图动作清单里未发现 33/34 一次性或重复赠送超武的动作。普通遭遇战美国空指部仍使用 AmerParaDrop，每批 8 名。
- 原图 (64,129) 的科技医院 CATHOSP 有 Capturable=yes、NeedsEngineer=yes、Unsellable=yes 和 InfantryGainSelfHeal=1。原有关卡“靠近即持续治疗”描述已被取代。工程师接管后，每 50 规则帧为所属方受伤步兵恢复 20 生命，覆盖全图。医院中立、被毁或失去所有权后，原持有方不再获得治疗。
- 原版与带养成开局分别从战役指挥室进入，tests/hollywood_campaign.tscn -- --capture-aid 各 31 项通过。实测工程师右键进场和消耗、航站楼屋顶点击、普通步兵拒绝进驻、不可出售、医院治疗、低电充能、非法投点保留充能、实际运输机与六人着陆、两处归属及载员读档和丢失设施后的权益。普通空降专项 32/32，战役胜利回归 60/60。Godot 4.7.2 headless，隔离玩家目录。证据位于仓库根 .validation/hollywood-airport-1795587238961/{checked,checked-growth,checked-victory,final-normal}/。未打包或逐个实玩难度。
## 第二关的建造和生产科技封锁

2026-11-25，工作区 0.32。逐项核对 Steam 原图 ALL02UMD.MAP（SHA-256 为 168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303）。美国及本关实际生产的尤里基地科技等级均为 10。地图把 PCV、GAROBO、GAYARD、YAYARD、TANY、GAWEAT 提高到 12，把 GTGCAN、YURI、CIVA、YAPOWR 分别设为 7、4、-1、1。关卡配置 `data/waves.json` 保存这十项原图覆盖。

旧实现只在部分入口检查六个编号。修前实测谭雅仍列在兵营，机器人坦克指引仍推荐禁造的控制中心，已入队的天气控制器还会推进和交付。现在工厂、指令甲板、解锁路线、建筑下单、计费和交付使用本关科技规则。缺少禁造前置时隐藏对应产品。已有设施仍然可以提供前置。读档会重新过滤工厂目录，保留合法订单和已投入的生产状态。

Godot 4.7.2 headless，独立玩家目录，从战役指挥室出击。`tests/hollywood_campaign.tscn -- --production-lock` 原版 26/26，加 `--growth` 后 26/26。覆盖实际步兵按钮、正反下单、巨炮前置、队列与快照恢复、切换战役和遭遇战。既有 `--bridge-tech` 18/18，战役胜利流程 85/85。回归日志在仓库根 `.validation/hollywood-tech-1795594090970/`。本轮只验证工作区。


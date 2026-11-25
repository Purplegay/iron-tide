# v0.4 特殊机制与 AI 交接

2026-10-28，实际工程 `C:/Users/admin/IronTide/iron_tide`，共享分支 `codex/ra2-independent`。按“先做1–2，然后AI强化”推进：盟军特殊机制、风暴细节、盟军遭遇战策略。保留 Godot 独立实现与 RA2/扩展模式分离；没有实现完整苏联、尤里阵营或完整原版 AI 脚本解释器。

## 玩法入口

| 内容 | 当前实现与操作 |
|---|---|
| 超时空传送 | 选源区域再选已探索落点；3×3原始格尺度内可见的双方地面单位一起处理，保留相对位置。普通有机步兵死亡，Teleporter步兵例外；载具乘员随车存活。落在不适用水陆、建筑、障碍或边缘越界的单位死亡并耗掉充能，完全出地图的指令拒绝。 |
| 间谍 | 右键敌方雷达建筑，清除对方历史探索，当前侦察/卫星视野重新计算；右键敌方超武，重置该座充能，已经发射的风暴继续。既有资金转移、断电、兵营/工厂训练与实验室窃密保持。 |
| 民居驻军 | 新遭遇战在可用位置放置至多两座 CAHSE01。美国大兵右键进入，容量5，使用 UCPara/UCElitePara 驻军武器；选中己方民居按D或点撤出。25%及以下血量撤军；满员、敌占或严重损坏拒绝进入。民居不提供建造范围，不充当短局基地资产。 |
| 桥梁 | 遭遇战内湖新增一座可通行的桥，另一处断桥可修复。完整桥可同时供陆军过桥、海军从桥下通行。伊文右键维修屋装弹，引爆后只关闭桥面陆路。工程师右键进入维修屋后消耗自身并恢复通行；存档保留每座桥的状态。 |
| 警犬 | 近距离扑跃，接触后才伤害。ParasiteDog对步兵按扑杀处理，保留免疫与调试无敌；扑空/受阻不会隔空造成伤害。当前使用原有狗攻击序列加短跃高度，不是完整LimboLaunch动画系统。 |

## 风暴时序和边界

`LightningStorm` 保存世界级生命周期；`storm_clouds.gd` 按事件截止时间推进，云本身无独立伤害计时器。原始 Deferment=250、Duration=180、HitDelay=10、ScatterDelay=5 按15帧规则秒换算；散云在CellSpread×CellSpread区域生成并检查曼哈顿间距，中心云不参与间距拒绝。云以原始WCCLOUD贴图显示，完成后消散。发射源被摧毁或出售不会终止风暴。

**独立适配，不宣称原引擎逐帧一致：**当前以云动画中间帧作为伤害时刻；原始地图 Lighting 缺失，使用固定战场色调，HUD不变暗；干扰敌方小地图限定在风暴主体持续阶段，尾云消散不延长雷达干扰。配置带LightningRod的建筑可吸引附近散云，附近更近的非避雷针实体会阻止重定向；没有给未标记的建筑凭空添加避雷针功能，也没有实现Ares的自定义避雷针伤害倍率。

新风暴version=2保存所有云的出生/落雷/消失时间、是否命中与随机数状态，避免读档重放伤害。旧风暴version=1继续旧时序，结束后新发射使用新版。渲染节点只根据保存的状态重建，不承担判定。

## AI 策略

- 普通/困难：有基础战斗兵力后间隔决策补飞机，看到敌舰才考虑海军。选择可见且可攻击的目标，舰船检查水域路径/海岸射程；飞机停机满弹才接收新一轮出击命令，不改玩家飞机补弹后停机行为。
- 困难：逐步训练间谍、夜鹰、两名海豹；间谍先伪装，再按实验室/矿场/超武进度选目标；夜鹰使用真实登机、飞到合法陆地、卸人、返航流程，海豹下机后执行普通建筑攻击/C4。
- 伤车尝试返维修厂，受损建筑开启普通收费维修。天气控制器按可见目标价值选点并扣除己方附近资产价值，走正常充能消耗。
- 训练不绕过工厂、科技、国家资格、预算和实际扣款；船坞扩建先确认现有建造搜索范围内有合法落点。虫群AI保留既有规则。
- 策略阈值、编队数量、目标权重和投放点搜索是IronTide参数；不是原版aimd任务队伍的完整解释执行。还没有全地图长局胜率、海空联合作战强度或多难度平衡结论。

## 代码与存档

- 本机原始资源抽取：`ra2pipe/special_mechanics.mjs` → `assets/ra2/special_mechanics.json`、CAHSE01/CABHUT原始SHP导出。输入容器哈希与规则/美术哈希保存在清单，抽取结束复核原始文件未变化。
- 单位能力：`scripts/units/{allied_abilities,civilian_orders,dog_pounce,spy_operations}.gd`。
- 世界机制：`scripts/world/{chronoshift,civilian_sites,civilian_site_visual,lightning_storm,storm_clouds,storm_presentation}.gd`。
- AI：`scripts/world/skirmish_operations.gd`，由现有skirmish_ai调用，复用skirmish_tactics预算与普通单位订单。
- 状态保存在已有 `special` / `allied_state`；民居乘员、运输预留引用与桥面矩形进入快照。新增快照special_rules指纹；此前无该字段的存档仍需通过原有主内容/schema校验，新增字段存在但不匹配则拒绝加载。中立建筑仅放行CAHSE01/CABHUT两个已知ID。
- 地图民居和修桥仅新遭遇战自动生成；旧存档加载时不额外塞入对象。存档不会自动把旧地图改成有桥地图。

## 参考与剩余工作

本机Steam尤复rulesmd SHA256：`3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`；artmd：`e1f0378394313c04ebbd5073f47785ee3e46f1b3c62d65724e8f3c310ee7ba31`。本地RA2YR_ReSource部分函数仍是占位，仅作结构参考，没有把占位返回值当引擎行为。

交叉参考：[Ares超时空](https://ares-developers.github.io/Ares-docs/new/superweapons/types/chronosphere.html)、[风暴](https://ares-developers.github.io/Ares-docs/new/superweapons/types/lightningstorm.html)、[避雷针](https://ares-developers.github.io/Ares-docs/new/buildings/lightningrods.html)、[Phobos寄生弹头默认步兵扑杀类型](https://phobos.readthedocs.io/en/latest/Fixed-or-Improved-Logics.html#customizing-parasite)。这些是扩展引擎文档，不能把其可选扩展标签都宣称原版已有。

仍待补齐：原版完整可驻军房屋目录及窗口枪口/占领外观；原版高架桥模型、桥上桥下分层与桥梁再次破坏；警犬完整跳跃抛射体/落地序列；驱逐舰反潜机；完整原版AITrigger/ScriptType执行；苏联/尤里阵营能力；长局稳定性与难度平衡。桥目前为简化木板陆地通道，没有用装饰模型冒充桥下通航。

测试入口：现有 `tests/run-navigation-building.ps1 -Suite <名称> -RunRoot <独立目录>`，新专项为 special_mechanics_regression、skirmish_operations_regression；特殊机制视觉采样 special_mechanics_visual 需加 `-Render`。实际本轮独立Node runner、逐项结果与源快照核对位置见VERIFICATION。画面/音效/操作观感为 `pending_user_visual_confirmation`。

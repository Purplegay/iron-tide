# IronTide RA3差距补齐与GM动态靶标交接

用户明确要求“写之前功能的记忆”。本条更新旧RA3移植缺口记录；实际工程为 `C:\Users\admin\IronTide`，不是聊天cwd中的KFramework。2026-10-29核实分支 `codex/ra2-independent`、当前版本0.5.10；共享工作区有大量其他改动，继续前重新核对，不能清理／覆盖他人文件。本轮未提交、推送或打包。

## 权威与用户约定

- 官方起义XML最终定规则，Upheaval只查漏；EA源版本 `3aad8e412961ab543192ae70f8503dc8e178e095`，本机源位于 `refs/ea-modding-support/Uprising/Xml`，素材来自正版Steam起义1.1。
- 逐项追踪原XML与消费者，主动补缺，不让用户逐个找bug；保留用户确认的跨代伤害适配、尤复目标原血量。未来坦克普通／英雄炮口FX原声明相同，不为“变色”任意替换；英雄球／节点变化另算。
- 每次更新给版本与内容；现行项目记录区分修bug四段版本、新需求三段版本、新特征两段版本。
- 新增RA3单位必须自动加入GM靶标；本次已用代码实现，不是只写一条提醒。

## v0.5.9.1 已接入

- 幻影 `ra3_scatter.gd`：普通首跳最多5、英雄首跳7，英雄第二层每支最多3；第二跳75原单位射程、20 CANNON、0.1秒延迟，不能误当PRISM或重复乘晋升倍率。更新历史“英雄第二跳尚未实现”记录。
- `ra3_mirage_extras.gd`：LIGHTNINGFX/GLOWFX/PLASMAFX原骨骼网格、双耳伪装射线、树/雪树/岩石/卡车原模型。模拟层保存地形/附近道具伪装选择。关闭场TRANS_FromField按IDLA一次过渡，重新开启可打断。
- `ra3_gunship_mounts.gd`：前机枪、侧前炮、侧后炮各自目标、弹夹、装填、瞄准、闪光。切换保留装填；旧存档迁移；GM重置所有炮位。真实开火保留停机后勤门槛。两个侧炮不是左右两侧炮。
- `ra3_gunship_shell.gd`：炮口切线曲线、空中起点/地面终点、500原速度、300原单位每秒追踪、固定散布；15Hz距离累计、连续显示，命中才结算。
- `ra3_gunship_crash.gd`、`ra3_wreck.gd`：空中整体坠落，触地一次300 EXPLOSIVE、50原单位半径、友军半伤，再分块；坠落为可存档Projectile。停机死亡及超时空抹除不误触该死亡武器。
- `ra3_meta_impact.gd`：原冲击参数驱动有界水平击退与真实Godot碰撞，无额外伤害。`ra3_crash_fx.gd`导入原死亡爆闪、火焰/烟雾图集；LightSource作为照明，不能绘成巨大光斑。读档清理旧时间线爆炸。
- 未来坦克本轮未另调平衡，其普通球、Q、晋升、动画、存档继续包含在三单位回归内。

## v0.5.10 GM靶标

- `iron_tide/scripts/admin/gm_unit_tools.gd::target_ids()`每次从`GameData.unit_index`枚举R3前缀单位，排序并加在E1/MTNK后；不是固定写死三个RA3 ID。当前幻影、未来坦克、先锋炮艇都加入。
- `gm_unit_panel.gd`按钮为“生成静止靶标（含全部 RA3）”；走现有targets命令，每类1个，敌方、静止、禁止自动开火，保留合法地形/视野空间检查，空间不足按实际数量报告。
- 新增RA3单位沿用R3 ID命名空间并注册到GameData即可自动加入；若将来命名空间改变，需同步识别规则，不能声称任意命名都会识别。

## 证据与复用

- 当前长期文档：`docs/RA3_COMPLETION.md`、`docs/VERIFICATION.md`、`docs/CHANGELOG.md`；`docs/RA3_THREE_UNIT_AUDIT.md`的旧缺口表已标明历史状态，不能再把全部旧缺口当当前未做。
- v0.5.9.1：35套/2126项运行检查及245项来源检查通过，新增`ra3_completion_regression`42项。最终汇总`refs/ra3-expansion/completion/final-audit.json`链接原始完整批次与116项timing复测。旧首跳边界夹具把外侧目标放在新增二跳范围内；移到相反方向，保留原断言。运行代码/资源无漂移，只有该测试夹具变更并完整补测。
- v0.5.10：`gm_targets_regression.tscn` headless21项通过；实际GM按钮信号、单例、Battle hook生成现有靶标，临时注册R3探针验证自动纳入、注销不残留、静止禁火及清理。证据`refs/ra3-expansion/gm-targets/{result.json,run.log}`。
- 环境：Godot4.7.2；隔离项目`refs/ra3-mirage/integration-test/project`的junction指向真实`iron_tide`，独立用户目录`CodexIronTideValidation/ra3-mirage-20261027`，数据库/网络/服务均none。图形回归用Compatibility/WASAPI；靶标专项无图形窗口。未启停玩家游戏、未改玩家存档。
- 开发默认headless；确需图形验证时应按现行后台禁焦点设置，不打断用户。正常游戏启动行为不改。

## 明确剩余边界

- 炮弹三次曲线是显式Godot适配，原FIRE_STRAIGHT_THEN_CURVE完整分段CPU求解器未确认。
- 散射按距离、全链不回溯/不重复是显式候选仲裁，原CPU跨分支仲裁未确认。
- 坠落重力180、质量换算及0.25秒冲击衰减是适配；完整SAGE刚体/地形物理未复刻。DYING阶段持续骨骼火烟仍未完整接入COL骨骼，不能与死亡瞬间/触地爆炸混称。
- 完整地形分类、任意场景道具复制、组合动画优先级、昼夜车灯、HDR/折射/全3D深度仍有差异；2D灯不会自动照到独立3D子视口。自测截图不是用户已确认逐像素一致，不得记成完全复刻完成。

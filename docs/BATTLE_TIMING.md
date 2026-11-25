# 15逻辑帧战斗与独立生产 · v0.2.6

2026-10-27用户最新要求：战场恢复15逻辑帧节奏，生产继续独立调速，参考RA3让建造不要过快。本约定替代v0.2.4.2的30逻辑帧战斗和60帧等效生产；旧版本历史保留于CHANGELOG/VERIFICATION。

## 时间合同

- RULE_TICKS_PER_SECOND=15，NORMAL_TICKS_PER_SECOND=15，NORMAL_SCALE=1。×1时Engine.time_scale=1；×2/×3按这个基准加速。渲染FPS、物理刷新频率不改。
- 普通攻击现实冷却=原存储冷却/面板倍速。M60为20/15≈1.333秒，105mm为60/15=4秒。
- 非生产计时（移动、转向、弹道、技能、采矿/卸货、AI与波次）统一随战斗时钟恢复15帧基准。镜头、HUD长按使用真实delta，音频不变调。
- 生产没有跟随整体恢复为原工期：BattleClock.production_scale按生产对象给出独立工作倍率。GameData.ra2_build_time仍是原尤复规则时间，不覆盖数据、价格或BuildTimeMultiplier。

## 官方SDK参考与项目映射

来源为本机已安装官方RA3 SDK的refs/ra3-sdk/installed/SAGEXML/Allied。安装来源及原包指纹见RA3_INTEGRATION.md。测试夹具tests/fixtures/ra3_production_reference.json记录23个Godot对象对应的SDK XML路径、BuildTime和SHA256；本轮读前提取、结束后复核一致。SDK版本数据不是对所有RA3补丁/资料片最终平衡的声明，也没有把SDK代码或美术搬入运行资源。

同类角色映射为项目选择：基础步兵→Peacekeeper、重装大兵→Javelin、灰熊→Guardian、步兵车→IFV、超时空矿车→Prospector、入侵者/黑鹰→Vindicator等。SDK参考秒数与现有工期取较长者，避免此次调慢反而加速部分项目；不改变原伤害、装甲、费用或技能。

| 项目 | 新基础现实秒（×1） |
| --- | ---: |
| 电厂、兵营 | 10 |
| 矿场、战车工厂 | 21 |
| 空指部 / 船坞 / 作战实验室 | 15 / 20 / 30 |
| 美国大兵、重装大兵 | 5 |
| 工程师 / 警犬 / 间谍 / 谭雅 | 10 / 2.1 / 10.5 / 30 |
| 灰熊 / 步兵车 / 矿车 / 基地车 | 11.025 / 10 / 20 / 60 |
| 幻影 / 入侵者 / 黑鹰 | 15 / 15 / 15 |
| 海豚 / 驱逐舰 / 航母 | 10 / 20 / 30 |

条件：单厂、正常供电、无养成。灰熊有原版建造倍率，旧基础工期11.025秒长于SDK守护者10秒，保留11.025。矿场/战车工厂同理保留21秒。无直接映射的项目使用原生规则时间/2，相比上一版/4慢一倍，不冒称对应RA3单位。DOG只在faction=allied时使用该映射，避免未来苏军同名ID继承盟军规则。

计算：映射项基础秒=max(原规则时间/4, SDK参考秒)；生产工作倍率=原规则时间/(基础秒×NORMAL_SCALE)。未映射项工作倍率=30/NORMAL_TICKS_PER_SECOND。实际再叠加缺电、多厂和养成；两方阵营同样适用。HUD必须传入当前对象ID，不能只读取统一常量。

## 消费与兼容

Building.production_work_rate、construction_work_rate、Battle.structure_work_rate均消费同一对象倍率；建筑队列逐项传入id，HUD卡片/剩余时间/矿场技能及工厂开门预估沿用真实工作率。退款、按进度扣费、资金不足暂停不改。

存档schema与data content hash不改，累计progress/elapsed/paid不重新乘除；旧存档按已完成比例和新速度继续。×1重载规则保持。已经导出的朋友包不自动更新。

## 验证与后续边界

6套922项断言通过。真实Godot物理+单调时钟测得美国大兵4.991～5.024秒、电厂9.845～9.875秒；两模式E1/MTNK/CMIN/BFRT/JUMPJET/ORCA巡航位移符合15帧速度；M60约1.329～1.333秒、105mm约4.010～4.017秒、GAPILL约1.733～1.750秒。覆盖23项参考的双方实际工作率与HUD、保存加载、暂停、真实胜负结束、经济与自动防卫。结果见VERIFICATION.md。

本轮恢复用户指定时间基准，未声称空间单位、轨迹或全部移动控制与尤复逐帧相同。历史Speed×15像素适配仍在，未来如要逐格精确对照应单独测量。资源退出告警与实际手感pending_user_visual_confirmation均如实记录。下轮苏联、圆形生产进度应沿用独立工期接口，不再通过全局加速改变建造时间。

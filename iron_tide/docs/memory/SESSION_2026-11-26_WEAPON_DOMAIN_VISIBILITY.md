# 武器目标域下钻和可见性热路径（2026-11-26）

续 [函数耗时优先](SESSION_2026-11-26_HOTSPOT_TIME_FIRST.md)。本轮无生产代码、玩家存档或包变更。证据 `.validation/weapon-domain-hotspot-20261126/`，准备器 `.validation/prepare_weapon_domain_hotspot.py`、`prepare_visibility_hotpath.py`。

18点 `natural1`：同兼容 checkpoint（307单位、179建筑、5 AI）、同 meta、Release 4.7.2 私有图形1600×900，3×、约30秒，450步/263帧，92.808模拟秒；外部引擎需复核，exit0、无脚本/计时栈错误、无运行源漂移。函数总计/步：`_weapon_domain_valid` 3.414ms（自身余量1.460）；直系武器解析0.247、掩护约0.119（全域调用）、`AlliedAbilities.valid_weapon_target`0.541、`actor_visible_to`0.517、`NavalContact.weapon_allows`0.259。全入口 `actor_visible_to` 3.142（449355次，大部分在武器域以外），全入口 `_weapon_for_target` 2.016；父子不能相加。记账2.829ms/步，不能拿插桩绝对值与旧不同点位对比。优先可见性而不是掩护或强行跨帧缓存。

隔离候选 `visible/candidate.gd`：`Battle.actor_visible_to` 已验证实例有效后只做一次 Unit 转型，复用在载员、两种特殊隐身的类型门槛及潜航分支，不进入通用 `NavalContact.submerged -> underwater_type` 再校验对象/类型；名单与 `dive_remaining` 条件原样，未更改友军、即时揭露、追踪、浮标、迷雾和探测。未改其它 `NavalContact` 调用。四种潜航 ID 在候选内重复定义，推广前宜统一事实源（例如双方引用同一常量，不能改活体规则）。

- `visible1` 同场462,259次判定0差异；旧先旧/新568.571/378.232ms，新先旧/新406.663/538.711ms，顺序影响大，非独立收益。
- 独立计时 ABBA `time-A/B/B2/A2` 同只插桩可见性入口的口径、同checkpoint与meta；450/448/451/449步，冻结无运行漂移、exit0无脚本错。`actor_visible_to` 2.583/2.450/2.423/2.540ms/步；按次 2.452/2.261/2.174/2.354μs，比对应原版少7.8%/7.6%，候选调用数反而更多。其它 CPU 25.99/32.23/22.97/26.01%，四场都有外部引擎审计标记，属于同向观测，不是干净验收或整帧P95。`visible-summary.json` 保存原计时与计数。
- 候选原函数（无影子）专项苏军舰船112/112、强制开火201/201、索敌复用28/28（后者计数在 console），共341项通过、exit0、无脚本错。暂不合入；先统一四种潜航 ID 的事实源，复测真正干净的同源可见性计时；净收益约0.1 ms/步的观察值不足以让这条链长期占优先。下一更大目标是域判断自身余量与可见性在非武器入口的重复调用，用同步调用证据验证，不延长索敌/迷雾频率、不跳过特殊隐身或同队检查。

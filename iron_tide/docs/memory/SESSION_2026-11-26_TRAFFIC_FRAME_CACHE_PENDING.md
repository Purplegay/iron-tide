> 已被[整场缓存实施记录](SESSION_2026-11-26_BATTLE_LIFETIME_TRAFFIC_CACHE.md)替代；以下仅保留两帧候选历史，不再等待其P95。

# 邻居候选两逻辑帧缓存：实施完成，性能验收待独占窗口

用户明确先实施“邻居候选缓存改为2逻辑帧到期＋必要提前失效”，爆炸命中、AI派单/训练选兵、贴图预热三项顺延。随后用户补充：只要不延误逻辑，缓存可保留整个战场。当前尚未移除2帧保底，永久有效期未实测。

## 当前交付状态

只改隔离候选，**尚未合入主工程、未提交、未推送、未打包**。主工程四个目标文件仍是原时间缓存实现。本轮完整证据与可恢复候选：[报告](../../.validation/traffic-frame2-20261126/report.md)。

源码根为 `C:/Users/admin/IronTide/iron_tide`，Git HEAD `a4a6a4fe1dcef7b4f687f8bf19a6a07d0b3fa5b2`，既有脏改很多，未创建worktree。冻结代码在 `.validation/traffic-frame2-20261126/{baseline,candidate}`。生产差异仅 `scripts/world/battle.gd`、`battle_neighborhood.gd`、`scripts/units/local_traffic.gd`、`vehicle_steering.gd`。

## 实现机制

Battle每个有效物理逻辑步以优先级-1000推进瞬态logic_step，暂停/结束不推进。f构建仅f/f+1有效，f+2刷新。原精确圆查询及顺序不变；被圆或碰撞层排除的桶内单位进入watch。复用时以当前位置/半径/layer检查watch，覆盖同格瞬移和原地layer恢复。单位增删/跨格更新局部桶版本，空桶参与快照，全局单调序号防ABA；远处变化不使本区域失效。自身位移>24、半径增长、查询域变化、查询覆盖矩形越界也提前刷新。

拥堵、apply和转向共用ensure；卡住重寻路强制刷新。少于96单位走物理查询分支时，因为没有全部物理body的事件记录，保守每次调用刷新，不宣称跨帧命中。已保留候选只在消费时跳过不合法状态，不永久删除，确保layer恢复仍能参与。缓存不进存档，原三个yield字段保持。

性能风险尚待诊断：watch每消费者线性扫描、稀疏分支可能同一步多次intersect_shape，不能只凭命中率宣称优化。

## 行为结果

最终缓存边界134/134、passing_traffic872/872、unit_neighborhood121/121、vehicle_turn418/418、timed_congestion54/54、friendly_infantry400/400，共1999条专项通过。logic15_bridge本轮基线和候选均104条/8失败，完整checks数组相同；四组合各“24辆全部通过”和“无全图绕行”失败，到达数均8。保留既有失败，不标全通过。

首次缓存专项112条/4失败是测试用(1050,1000)→(1010,1000)跨桶，却期待同桶复用；改夹具为(1020,1000)→(1010,1000)，所有断言保留，112/112复跑通过，再补边界达134/134。原始失败在tests-expiry-1/reports。

维护runner是candidate/tests/run-navigation-building.ps1；首场完整复制、指纹和导入。后续复用其已隔离project，每个suite独立user://与报告，源码前后稳定且无脚本错误。测试仅在独立玩家目录运行。adapter在 `C:/Users/admin/KFramework_server/.harness-cache/irontide-traffic-frame2/run_reused_suite.py`。

## 性能状态

固定存档1、完整图形Release、1600×900、3×、15Hz、每场30秒，私有桌面从不激活；同save/meta。输入来自此前current32/input/slot1.itsave（381单位207建筑5AI，yr_isleland）。

| 样本 | P95 ms | 结论 |
|---|---:|---|
| baseline-1 | 267.166 | 有效 |
| baseline-2 | 286.729 | 有效；基线均值276.9475 |
| candidate-1 | 267.945 | 目前唯一有效候选样本 |
| candidate-2 | 280.077 | 外部time_shift测试并发，排除 |
| candidate-3 | 372.396 | 外部Godot再次并发，排除 |

每场host-cpu.json保留5秒进程抽查；不能以无并发抽查证明绝无短命进程。有效三场后台CPU估计均值21.46%/26.57%/23.81%，非全空闲机器。仍需另一场有效候选及诊断，不能宣称收益或通过保留门禁（两场均值和最好值均改善）。外部测试曾短暂退出后马上再启动，启动前空闲检查不足，已停止自动重试，等待用户协调持续窗口。

诊断已准备但**未运行**：diag-baseline、diag-candidate各自source/tools/points.json。两组分别7/12计时点，27项计数，含TTL/位移/region/watch/force/sparse刷新原因与父子计时。启动用各自tools/performance_soak.py --source对应source --engine-phases，其余同正式测量；不要--frame-only。分析器tools/analyze_traffic_profile.py读取frame-components.json和points.json。原始/插桩后SHA与AST已记录，但Godot运行解析尚待验。

## 恢复时的快照门禁

本轮期间另一项工作修改主工程american_paradrop.gd、time_shift.gd、house_remap.gdshader。4个本轮目标文件未冲突，但共享空降下降倍率8→4对yr_isleland不能证明无影响：slot1含AmerParaDrop/american_airfield状态，端点无para_height不足以排除中途空降。冻结旧轮结果不能直接认作新主工程的验收。

若旧冻结候选收益不达标，保留报告且不合入，无须为其它任务改动重测。若打算保留，应冻结最新主工程为新baseline，叠加4目标补丁形成candidate，补相关行为和同输入A/B；不混旧baseline与新candidate。不要覆盖其他任务变更。暂停其他Godot及相关源码变化后再启动，以运行中进程审计判定样本有效性。

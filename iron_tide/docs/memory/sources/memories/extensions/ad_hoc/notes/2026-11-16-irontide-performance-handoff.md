# IronTide 性能优化交接（2026-11-16）

用户明确要求记录，交给其他人继续。实际工程是 `C:\Users\admin\IronTide`，Godot 项目在 `iron_tide/`；当前分支 `codex/ra2-independent`，有大量既有未提交修改。不要套用聊天 cwd 的 KFramework/Unity 工作流，不要 reset、清理或覆盖无关改动。

## 当前状态与交付

- 原“五轮完整帧 P95 优化”只验收 **4/5**，**未达到 33ms**。用户先要求暂停，随后已清除目标；本次核对 `get_goal` 返回 null。不要自动恢复或把局部收益计作第五轮。
- 后续单独完成 RA3 天启**默认炮火**的 CPU/资源优化，尚待用户确认实机画面与卡顿改善。当前源码已不是此前 `accepted4` 快照，而是 accepted4 加这项特效修改。
- 最新可玩包：`C:\Users\admin\Downloads\IronTide-0.28.1-20261116-apoc-fire-fx.zip`，252805134 字节，SHA256 `4889d1a547904d27e28931b5e111a2ee76d257001a8f1a1286676420fc1ce504`。包含此前四轮、AI 公平调度修正和天启特效修改；实际 EXE 53 项检查通过。未提交或推送。

## 四轮已验收结果

以下是各轮各自配对的完整帧 P95，单位 ms，不能跨轮相减或当作当前稳定帧率。

| 轮次 | 修改 | 两组配对结果 |
|---|---|---|
| 1 | 迷雾侦察圆盘缓存 | 104.561→88.242；115.729→93.954 |
| 2 | 大战局 HouseAI 策略轮询 500ms 错峰，传完整 delta | 112.942→86.976；122.143→81.245 |
| 3 | 开火视野到期时，已被有效保留视野或当前友军侦察完整覆盖则不重复重建 | 257.350→227.970；243.228→238.642 |
| 4 | 大战局 AI 自主保留目标复查 0.32→0.64 模拟秒 | 156.985→150.160；157.206→152.752 |

第 4 轮保留玩家命令、显式攻击、还击、射击/移动时钟；额外等待期间目标死亡会提前复查。不要把局部扫描减半宣传为全场调用减半。第 3 轮反向对照平均帧时曾变差，仅 P95 门槛通过；CPU 不合格的旧对照及替换依据均保留。

证据根目录（均相对 IronTide 仓库）：
- 第 1/2 轮：`.validation/p95-five-after-package-20261113/round-1.json`、`round-2.json`。
- 第 3/4 轮及后续失败记录：`.validation/p95-resume-20261116/report.json`、`report.md`、`round-3.json`、`round-4.json`。
- `accepted4` 是旧正式快照；`base4` 实际只有前三轮，有警示文件，不能当第四轮基线。

## 复测合同与避免重复踩坑

- 同一六家快存（玩家 + 5 AI，`yr_isleland`）：`.validation/p95-resume-20261116/quick.itsave`，SHA256 `3bff03f5bff0a30563d7ec330c5e6465fca2dfe01587be1e1810eeac3756e90d`；同目录 `iron_tide_meta.json` 为养成输入，SHA256 `2925aafacd39e21f3ce6461631c7a973d3200b4968a7617ba45a31abeac51b31`。图中 ally/enemy/ai2 同队，敌对夹具用 ai3，不能把 enemy 名字当敌我依据。
- Python：`C:/Users/admin/AppData/Local/Programs/Python/Python312/python.exe -X utf8`。现有 `run.py freeze <唯一新名>` 从当前正式源码冻结；**先重新冻结当前源码**，别继续拿 accepted4 冒充最新版本。候选从该新基线复制。
- 同目录 `bench.py <基线> B1 <候选> C1 <候选> C2 <基线> B2`：Release headless、每场 60 秒、1 倍速、保留玩家单位、相同快存和养成；输出名必须全新。`check.py <快照> <测试场景名> <新输出名> [--release]` 可做隔离专项。
- 只有两组完整帧 P95 都下降才计一轮。预先约定 CPU 门槛：采样至少 55 秒、主机 CPU≥90% 的时间不超过 5%、配对其他进程平均 CPU 差≤10 个百分点。合格但变差的结果不能重跑到偶然赢；CPU 不合格替换前先实测安静窗口并保留失败证据。
- 所有运行隔离 APPDATA/LOCALAPPDATA、读取存档副本；不操作用户游戏，不覆盖原存档。不要并行跑 Godot 测试、打包或大批复制来污染时序。允许的测试入口是 headless/真正隔离的隐藏运行；最小化或移出屏幕不算隔离。
- 当前最后两场 accepted4 基线为 **189.961/193.496ms**，出自 `event-query-base1/base2`。这是当时 Release headless CPU 帧间隔，**不是最新包的 GPU/显示性能**。默认 `TankFX.event` 在 headless 下跳过特效，普通整场 soak 不能验证用户看到的炮火卡顿。

## 无收益方向与下一入口

`report.md` 和 `tools/PERFORMANCE.md` 有完整候选历史。已淘汰包括整图查询缓存、空间分区、碰撞循环外提、移动绘制条件、目标评分上限、血量重绘轮询/事件、计数器改写等；不要原样反复重测。

最近两个明确失败候选：
- 格子版本缓存 `query-local-version`：7475 检查通过，P95 205.165→223.689、196.440→206.608；命中约 82%，但版本检查让邻域函数更慢。
- 主动区域失效 `query-event-invalidation`：7983 检查通过，P95 189.961→196.265、193.496→204.230；邻域函数局部累计 979→842ms，整帧仍变差。两者 CPU 门槛均合格、未合入。

一分钟诊断的包含耗时：单位物理约 30s、战斗处理约 10s、单位绘制约 8.3s；战斗普通移动分支约 6.37s、目标/射程约 0.84s；移动原生碰撞约 2.12s。父子包含时间不可相加，采样日志含启动，不是纯自身耗时。证据：`engine-accepted4-analysis.json`、`combat-branches-analysis.json`、`combat-branches-instrumented/branch-ranking.json`。

若接手者获准继续整体优化，优先细拆单位绘制、动态皮肤/叠加层触发的整身重建，别继续围绕累计约 1s 的邻域查询做微小缓存改写。选中 APOC 的 YR 9 号皮肤有动态星光，不能直接当静态车体或随便离屏剔除。旧桥梁和失效对象专项存在基线失败，详情见报告，不可把整套标绿或归咎于新候选。

## 已合入的两项独立修正

AI 只剩采矿车动：已复现策略预算被靠前 AI 抢占，改 FIFO 等待队列，控制器退出清队列。重型决策仍每渲染帧一个，不改变采矿/单位物理。模拟授予次数由 24/24/24/24/0 变 16/16/16/16/16；630 检查及真实快存五家各获 7 次执行通过。用户原局未保存，不能断言完全同因。证据 `.validation/ai-strategy-fairness-20261114/report.json`。

RA3 天启默认炮火：最新独立证据 `.validation/apoc-fire-fx-20261116/report.json`、`report.md`。
- 修改仅 `iron_tide/scripts/units/ra3_tank_fx.gd` 与 `ra3_crash_fx.gd`。同一 FX 按 emitter id/start 共享材质和相同 uniform 更新，实例之间不共享时钟；TankFX 30Hz 累计 delta 采样。其他 crash/reaper 默认保持独立材质。
- 默认炮口 50 份材质→3 份，仍 51 个粒子（50 烟尘 + 1 光源）；英雄爆炸样本 335→51 份材质，仍 336 粒子。伤害、射速、弹道、AI、存档结构未改。
- Release 20 组真实炮口粒子、60 次 1/60s 更新、8 批交替，中位更新 **301.624→147.797ms，下降约 51%**；创建 54.364→54.015ms，没有显著创建时间收益。不得声称整帧 P95 降了 51%。
- 416 项粒子/真实 emit_entries 入口/共用 Tesla 路径检查、71 项苏联单位检查、2012 项原生命中特效检查通过。测试入口 `apoc_fire_fx_regression`；旧实现参考在 `tests/apoc_before_*.gd`。GPU 和最终视觉仍待用户反馈，不写成已经完全解决实机卡顿。
- 最新 runtime SHA256：`ra3_crash_fx.gd` = `6c4e5fb854a5fdd74bf08a29f52fbbe2c21a18c90a877065a2171f78708f1cf1`；`ra3_tank_fx.gd` = `079dd666e4b159af6d77d3dfb2cc5cefeeb6ec7fcfc47fd8506856377c3c81f7`。
- 打包必须用 `large-package.itsave` 专用夹具（原断言≥190 建筑）；性能快存只有 186 建筑，曾因此失败，不能为通过而降低断言。最新包已用正确夹具通过。

原始证据在本机 `.validation/`，不会自动随 Git 交付。跨机器接手须显式复制选定报告、存档副本和养成输入并核对 SHA256；文件路径或哈希本身不等于已传递。

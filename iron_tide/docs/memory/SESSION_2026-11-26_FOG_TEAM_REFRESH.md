# 常态热点重采样与迷雾同队视野证明（2026-11-26）

接 [避让按行裁格](SESSION_2026-11-26_AVOIDANCE_ROW_GATE.md)，本轮不重复取桶候选。证据 `.validation/current-hotspots-refresh-20261126/`，准备工具 `.validation/prepare_hotspot_refresh.py`、`prepare_fog_hotspot_refresh.py`、`prepare_fog_team_cover.py`。

## 工作负载

旧 Slot1 当前规则不兼容，未绕过或写回。自然新开 `yr_isleland` 五 AI、保留玩家、Release 4.7.2 私有桌面 1600×900 3×；首场 `seed` 冻结了并行 `yr_magnetic_wave.gd` 的类名/类型编译错误，整场作废。重新冻结 `seed2` 无脚本错，65墙钟秒生长约197.71模拟秒，取本轮隔离 checkpoint `seed2/end.itsave`（SHA 85e31a7c8db89fa31cd13656fbe24fdfdd4335949da0054e7750a6498cc29720），之后可正常读档，307单位/179建筑/5 AI。`seed2` 主源审计记录 `yr_magnetic_wave.gd` 并行变化；仅用于生成可正常读的本轮固定样本，不将开局P95作为旧存档基线。不写玩家原档。

两场28点 `natural1/2` 同冻结源码/同checkpoint和meta，30墙钟秒，449/451物理步，187/245帧，推进93.200/93.285模拟秒，第二场外部引擎需复核；退出0、运行源无漂移、无脚本/计时栈错误。绝对计时口径统一以总耗时除实际步数（根 process 另外可除渲染帧）；父子包含不可相加。计时记账约1.88ms/步。迷雾 `_process` 6.824/7.645ms/步（16.385/14.074ms/渲染帧），索敌 `_refresh_target` 3.171/3.139ms/步，扩展更新2.530/2.470ms/步，细桶搜索仅0.111/0.103ms/步。不能用不同战场或插桩比较正式 P95。

`fog1` 的16点下钻：450步/301帧，外部引擎需复核、退出0无源漂移；相对 broad 源指纹有 allied_finale 和两份 UID 并行变化，未改 fog。迷雾主回调8.578ms/步，重建入口6.978；重建 -> lease 到期1.451、离开视野保留1.168、半径计算1.088、发布0.980；`_process -> _scout_covers_firing` 1.248ms/步（其中半径0.673），特效过滤0.088ms/步。详见 `summary.json` 和 `fog-summary.json`，只是诊断优先级，不把子段当节省。

## 已合入：枪火揭露到期同队复用

正式 `scripts/world/fog_of_war.gd::_scout_covers_firing`：在 `_process` 既有同步到期循环的临时缓存里，对验证过的整数队伍编号共享友军侦察覆盖源，未组队/非整数队伍按观察者缓存。每次仍先验证观察者可见域；`friendly` 对同整数队成员接收同样的友军集合，源半径和坐标不依赖观察者；不把缓存跨帧保存，不改真实揭露、持续时间、过期判断、遮罩或持久化。若已有枪火需重建，仍走原路径。

- 影子 `fog-team-1` 277 次初版0差异（一次同步 pass 使用独立旧观察者缓存），访问118,747→102,927；有外引擎。最终整数队版 `fog-team-2` 321次0差异，构建280→244，访问138,559→120,756（−12.85%），半径67,552→58,219（−13.82%）。两场完整图形自然对局、推进92.680/92.868模拟秒，exit0、无脚本错/源漂移，最终场外部引擎审计未见重叠。影子主业务由候选提供判定，未测无插桩净CPU或P95。
- 候选专项 `candidate-fog_scout_cover_regression-v2`145/145、`candidate-fog_fire_cover_regression-v2`579/579，均exit0无脚本错；首次专项复制了已插桩脚本却漏根 `unit_call_probe.gd`，75秒超时无效，补齐隔离依赖后复跑。生产只落迷雾局部改动，`git diff --check`过，未提交/打包。

下一刀按上游减量优先追 `rebuild -> _expire_held_sight / _hold_vacated_scouts`：先量实际变化/到期格、各观察者重复比较和写入，区分同盟重合与独立临时揭露，再决定候选；不改普通视野 cadence、立即枪火语义或全部可见性阈值。

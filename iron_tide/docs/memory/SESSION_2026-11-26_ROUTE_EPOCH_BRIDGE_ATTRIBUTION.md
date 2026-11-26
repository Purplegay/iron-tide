# 路线重算：桥梁版本缺少局部记录

接续 `SESSION_2026-11-26_BLOCKAGE_REPATH_BRIDGE_REVIEW.md`；按桥坡规范阅读 `BRIDGE_PORTING.md` 的既有交接。本轮只诊断，生产算法无改动。准备器 `.validation/prepare_route_epoch_review.py`；v1 准备阶段唯一匹配保护退出，未运行；有效证据 `.validation/route-epoch-review-20261126-v2/run-1/` 的 result.json（route_epoch_review）、slow-frames.json、host-cpu.json、source-audit.json。存档1 yr_isleland、正式 Release 4.7.2、完整图形私有桌面、3×、1600×900、30秒。139帧，模拟93.521s，exit0，进程审计无重叠、来源无变更、无脚本错误，栈与入边对账通过。单场插桩，并非正式 P95 或新旧性能对照。

`_steer_dir` 旧路线版本核验12,100次；512复用、11,202次未获AI准入、212次未获地形刷新预算、174次真实调用重算，四类对账闭合。174次按首个拒绝理由：桥梁版本缺历史121（69.5%）、终点不同35、未标注来源的缺历史13、变更范围与路段相交5（新增建筑1、移除4）。记的是导致判定失败的历史版本，而非查询时最新版本；桥梁更新出现6次。桥梁缺历史的核验7737次，其中7492调度拒绝、124刷新预算拒绝、121实际重算。观测不能逐项归因上一轮差值或判定121次全部可省。

机制：`BridgeDamage.restore` 更新 bridge_flags/broken_bridge_decks 并调用 `_refresh_pathing` 重建通行网格，推进 epoch，但没有调用 `record_route_change`；`Battle.remaining_route_unchanged` 遇缺历史立即保守返回 false，尚未判断该桥是否与剩余路径相交。建筑拆除已有 `route_snapshot_outside`/`route_matches_outside` 后才记局部变更的范例。桥更新还影响原生旗标、水域/桥面、桥段投影和潜在路线域；不能只取一个视觉矩形就宣称安全。

下一步可审的候选：先取旧/新 bridge_flags 与 broken 区段变化的保守范围，原生变化验证范围外通行网格/通行形状和相关桥层信息均不变，且仅推进预期一条 epoch 时才记录局部历史（非原生 set_water 可能产生额外 epoch，暂保留原回退）。量化证据生成/全图副本比对成本；若抵消省下的重算则不采用这版。真实验收：远处路线保留、经过断段必须失效，修复后可重新过桥、桥上/桥下/跨多个段、存读档与同周期叠加建筑变化；同源 A/B 比较有效重算、额外检查与整帧，不跳过物理或改变当前堵路计时。

# 当前源码热点复测：交战、避让与通行（2026-11-26）

用户纠正顺序：先重新测实际最高热点，做函数/循环级 Go 伪代码 review；本轮不做旧候选 A/B，不修改正式游戏逻辑。续接 `SESSION_2026-11-26_TARGET_SCAN_AIR_AG_C4.md`；风险另看 `BRIDGE_PORTING.md` 与历史交通查询交接。

证据 `.validation/hotspot-review-current-20261126/`：存档1 yr_isleland，正式 Release 4.7.2、全特效、1600×900、私有桌面、3×、30 秒墙钟。67 点初筛被外部 Godot 污染，排除其绝对时间和排名结论。31点 focus 与41点 movement 的原始源码哈希清单1542条完全相同，各自 runner source audit 无变化、五秒进程审计无重叠、日志无脚本错误、栈/入边对账及非负 self 通过；模拟推进93.055/93.392 s。focus 99帧取5慢帧，探针账务24.021ms/慢帧；movement 98帧取5，39.479ms。资源为既有共享联接，未做完整资源哈希。两套插桩改变补步数，不能相减、跨表相加、当正式 P95 或折算可节省毫秒。

focus 中 `_physics_process` 自身残差157.900/含子调用381.287ms/慢帧；最大已计时子边 `_process_combat` 83.748（自身16.640），内部直系 `_move_toward` 24.156、`_move_water_safe` 22.408；`_refresh_target` 47.442，`progression_expansion.tick` 38.537（自身35.867，包含未插桩叶子，并非纯函数体）。movement 中 `_process_combat` 128.012，直系 `_move_toward` 39.039、`_move_water_safe` 27.478，当前第一条下钻路径是移动，不是再次扩展索敌。跨调用方 movement 自身数据：`LocalTraffic.apply` 20.109 含、8.274 self；`ensure_candidates` 27.046 含（含多个消费者，不能与 apply 相加），其中 `_can_reuse_candidates` 8.899、`_rebuild_candidates` 11.620。`_move_water_safe` 的 `_slide_across_bridge_layers` 19.804，内部 `_traffic_collision_exceptions` 9.301，`_record_overpass_move` 0.672，`_domain_ok` 对 `_move_water_safe` 贡献4.309。不是桥层记录或地形点测先改。

Review 下一步：先按每消费者、每逻辑步记录 `ensure_candidates` 的调用、半径/掩码/锚点/局部版本/watch 失败原因，计比较格数、watch 扫描数、重建候选数及 apply 几何淘汰量。现已有区域版本及 watch 复用，不再加同类缓存。若同时证明同一步有重复查询、且中间所有依赖与同一单元的位置未变，可只复用已验证事实；若版本比较是主因，再评估同边界范围少做坐标换算/比较或日记式失效，含维护总成本。小改动候选：apply 检查 `other.has_move_order` 或矿车资格后才取速度并 normalize，保持 `request_yield` 顺序，先统计节省覆盖；已有几何过滤不能冒充新增。桥层临时碰撞例外独立审计，禁止复用跨实际移动、归属变化或层切换的结论，保留栅栏/桥面/桥下/进出厂行为。未实现、未验证这些候选或最终整帧收益。

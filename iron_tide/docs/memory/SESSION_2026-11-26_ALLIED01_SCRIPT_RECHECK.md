# 盟军首关脚本复核：航母接力与工程师救援

原图 `ALL01UMD`；接 `SESSION_2026-11-26_ALLIED01_DREAD_AI.md`。`ALL01UMD_SCRIPT_RECHECK.tsv` 保存 334 条原始 Trigger/Event/Action/Tag，附当前覆盖状态：42 条标了本轮、已有近似或已知缺项，其余 292 条待逐条核实，不宣称 334 条均已迁移。原图索引 `.validation/allied-ends-20261126/audit/yr_all01umd_index.json`。

- `allied_first.gd` 补 `0BA104BC -> 089B1CCC -> 0898812C -> 0792B79C`：首批三航母后再发三艘、延时通报、全损后续派；朝 PB（417）集结。CQ（94）在可玩域外，先保留既有替代出生位（68）。使用项目模拟秒映射原图的 1/20 字段；已有旧存档如果已经有航母，不回放首批。目标已毁直接走正常结算，不再申请航母。未验证舰载机实战制胜或路线全程。
- `08E56B3C -> 08E568DC -> 090AB04C`：穿越前兵营及可用工程师均没了，等待 30 项目模拟秒，运输机送四个工程师到 EM（142），首次实际落地才通报。运输机复用通用真实跳伞，不还原图外 EN 专属航线。运输途中不重复派；若拿不到合法落点仍会重试，不改玩家生产入口。
- 隔离 Godot 4.7.2 无头 `tests/allied_first_playable.tscn -- --reported-slot2 --carriers` 33/33 exit0，`--engineer-rescue` 25/25 stderr 空（外层未捕获退出码，日志记录完整 RESULT）；前者用夹具加速和撤除舰队，后者以实际运输机完成飞行与四人降落。日志 `.validation/allied01-playable/script-audit-{carrier,engineer}.{out,err}`；未改玩家档、未有头。
- 本轮补查 `089F2AAC` 来自 `0A815AFC Flash_GGI` 不是谭雅入场的直接动作，开场提示链未还原前不擅自在谭雅登岛生成。`067DD9FC` 后续舰队、桥坍塌/恢复、医院、零售 AI、三档自然战役和完整媒体仍待核对或实现。

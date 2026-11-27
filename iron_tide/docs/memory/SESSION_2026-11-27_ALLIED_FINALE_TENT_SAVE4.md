# 盟军 07《脑死》火地岛帐篷：存档 4 只读核对

- 更正 `SESSION_2026-11-27_SOV01_NEUTRAL_GARRISON.md` 的关卡归属推断。截图目标文本来自 `scripts/world/allied_finale.gd`；是盟军 `yr_allied_finale`，不是 `yr_time_shift`。先前读取到同任务的自动存档不应被排除。
- 按用户指定读取 `battles/slot4.itsave`（2026-11-27 19:40:46），校验 ITSAVE01 外层和载荷 SHA-256，无头独立反序列化；未进入对局，未改档。
- 与截图中旗杆和两顶残损帐篷对照：右侧大帐篷 `CAARMY01`（原图 Structures `1050334`）50/200，8 位，0 驻军；左侧小帐篷 `CAARMY02`（`1050335`）50/200，4 位，0 驻军；两者中立。旗杆 `CARUFGL` 没有驻军位。零售 `data/ra2/allied_finale_field.json` 两帐篷均以 `64/256` 耐久开局。
- `civilian_orders.gd::can_enter` 常规驻军要求严格大于 25%，而非大于等于；帐篷具备驻军位，可由苏联工程师先修，再用动员兵入驻。维修分支核对了代码，未实机下令验证；无生产修改。

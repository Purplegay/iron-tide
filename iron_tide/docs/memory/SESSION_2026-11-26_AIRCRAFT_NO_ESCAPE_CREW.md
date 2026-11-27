# 2026-11-26 飞机损毁不生成逃生员

- 用户确认飞机坠毁不应掉逃生员，报告鲍里斯的米格会掉。零售规则抽取 `data/ra2/death.json` 中 BPLN、BEAG、ORCA 都是 `AircraftTypes` 且 `Crewed=yes`；SHAD 是 `VehicleTypes` 且 `Crewed=yes`。旧 `scripts/units/vehicle_crew.gd` 同时允许两类进逃生分支，只硬编码排除 ORCA。
- 在 `VehicleCrew.eject` 统一排除 `unit.is_air` 及非 `VehicleTypes`，不依赖当前高度。固定翼和直升机空中击毁或地面被毁，都不生成额外士兵或技师；普通载具仍按原有 `Crewed`、概率、落点等规则处理。未改坠毁、碎片、死亡爆炸或搭载乘客逻辑。
- `tests/yr_vehicle_death_regression.tscn` 在 RA2 和扩展模式用鲍里斯实际调度的米格编队走致命受击入口，另覆盖双方入侵者、在飞及停放的黑鹰和夜鹰直升机，以及基地车正对照。测试在飞机检查段强制 100% 逃生概率，避免概率掩盖问题。修前（尚未加夜鹰用例）386 项中 12 项失败，均为米格或黑鹰；修后 394/394，退出码 0，stderr 空。`git diff --check` 通过。Godot 4.7.2 无头，临时配置及隔离 APPDATA 证据在 `.validation/aircraft-no-crew-20261126/`。
- 未改玩家存档、未做有头验收、未单测机场被毁整条流程、未打包或提交。

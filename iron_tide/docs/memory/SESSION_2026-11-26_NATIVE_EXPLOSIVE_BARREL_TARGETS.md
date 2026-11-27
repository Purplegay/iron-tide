# 原图油桶右键攻击

玩家截图反馈油桶不能攻击。零售 `rulesmd.ini` 的 `CAMISC01`（桶堆）与 `CAMISC02`（单桶）是中立建筑实体，5 HP、concrete、Explodes、DeathWeapon=BarrelExplosion（200，OilExplosionWH）。不是 `DRUM01/02` 普通装饰覆盖物。地图数据检出美国首关、Dustbowl，苏军首关的当前导出文件扫描命中文本但 structures 没有这两项。

原故障有两层：`battle.gd::_pick_enemy_at` 一律排除中立建筑；改成可下令后，原版有溅射的炮弹由 `ForceFire.impact_candidates` 在两方战斗对象分组取候选，直接瞄准的中立桶不在分组仍不掉血。现在只允许 CAMISC01/02 的可见精灵命中进入普通右键攻击，通过现有强制攻击指令身份维持目标；普通防御建筑的手动入口也放行。结算把直接被瞄准的桶加回溅射候选，未改变自动索敌分组或其他中立建筑的右键规则。击毁走已有 YR 死亡武器与连锁处理。NativeMaps 设置中文显示名，不改变存档格式。

Godot 4.7.2 隐藏无头、隔离 APPDATA，实际战役菜单出击 `tests/allied_first_playable.tscn -- --barrels` 23/23、exit 0、stderr 空。测试在原图桶旁生成灰熊（摆位夹具）、走真实像素拾取及右键命令、物理等待坦克发射，未注入伤害。桶堆真被毁，附近坦克受伤、邻单桶被连锁引爆。日志 `.validation/allied01-playable/barrels3.{out,err}`。未逐图测试 Dustbowl、单桶直接打击、驻军/防御塔武器或画面特效、未改玩家档、未打包。

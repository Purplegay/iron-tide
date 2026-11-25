extends Node
## 全局事件总线。所有跨系统通信都走这里，避免节点之间硬引用。

# --- 局内战斗 ---
signal funds_changed(amount: float)
## 电力变化（RA2）：produced=总发电、drain=总耗电、low=是否低电
signal power_changed(produced: float, drain: float, low: bool)
signal selection_changed(units: Array)
## Player sidebar notification. Enemy factory queues do not affect its cards.
signal production_queue_changed()
signal wave_started(index: int, wave_name: String)
signal wave_countdown(seconds_left: float)
signal battle_message(text: String, color: Color)
signal unit_spawned(unit)
signal unit_died(unit)
signal building_placed(building)
signal battle_ended(result: Dictionary)
signal command_mode_changed(mode: String)
signal view_changed(label: String)
## (B3) 战术地图雷达事件：世界坐标 + 类型（attack/ready/alert），供小地图闪烁提示
signal radar_ping(world_pos: Vector2, kind: String)

# --- 局外养成 ---
signal meta_changed()
signal meta_tier_unlocked(tier_id: String)
signal meta_upgrade_bought(upgrade_id: String, level: int)
signal idle_income_claimed(rewards: Dictionary)
signal meta_unit_upgraded(unit_id: String, track: String, level: int)
signal meta_loadout_changed(unit_id: String)
signal meta_skill_unlocked(skill_id: String)

# --- GM ---
signal gm_flags_changed()
signal gm_notice(text: String)

func emit_message(text: String, color: Color = Color(0.85, 0.9, 1.0)) -> void:
	battle_message.emit(text, color)

func emit_radar_ping(world_pos: Vector2, kind: String = "attack") -> void:
	radar_ping.emit(world_pos, kind)

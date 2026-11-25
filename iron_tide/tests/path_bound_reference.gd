extends Node
var cols:=1
var rows:=1
func _nearest_walkable(cell_pos: Vector2i, grid: PackedFloat32Array, zones: PackedInt32Array, zone_id: int, max_rad: int) -> Vector2i:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(65)
	if max_rad >= 0: preload("res://scripts/world/battle_call_counters.gd").iterations(65, 1)
	if max_rad >= 0 and cell_pos.x >= 0 and cell_pos.y >= 0 and cell_pos.x < cols and cell_pos.y < rows:
		var origin := cell_pos.y * cols + cell_pos.x
		if grid[origin] >= 0.0 and (zone_id <= 0 or zones[origin] == zone_id): return cell_pos
	var best := Vector2i(-1, -1)
	var best_d := INF
	for r in range(1, max_rad + 1):
		preload("res://scripts/world/battle_call_counters.gd").iterations(65, 8 * r)
		for dy in range(-r, r + 1):
			var stride := 1 if absi(dy) == r else r * 2
			for dx in range(-r, r + 1, stride):
				var nx := cell_pos.x + dx
				var ny := cell_pos.y + dy
				if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
					continue
				var ni := ny * cols + nx
				if grid[ni] < 0.0:
					continue
				if zone_id > 0 and zones[ni] != zone_id:
					continue
				var d := float(dx * dx + dy * dy)
				if d < best_d:
					best_d = d
					best = Vector2i(nx, ny)
		if best.x >= 0:
			return best
	return best

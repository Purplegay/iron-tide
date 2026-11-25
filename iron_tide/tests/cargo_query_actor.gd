extends Unit
var weapon_queries := 0
func _weapon_for_target(target) -> Dictionary:
	weapon_queries += 1
	return super._weapon_for_target(target)

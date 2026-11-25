extends Unit
var fired := 0
var domain_calls := 0
var target_calls := 0
var mutation := ""
func _weapon_domain_valid(target, cover := false, resolved: Dictionary = {}) -> bool:
	domain_calls += 1
	return super._weapon_domain_valid(target,cover,resolved)
func _weapon_target_valid(target, resolved: Dictionary = {}) -> bool:
	target_calls += 1
	return super._weapon_target_valid(target,resolved)
func _fire_shot(target) -> void:
	fired += 1
	if fired != 1: return
	match mutation:
		"kill": target.hp=0.0
		"friendly": target.side=side
		"freeze": special.chrono_left=2.0
		"range": target.position+=Vector2(1000,0)
		"weapon": weapon=weapon.duplicate();weapon.range=0.0;attack_range=0.0
		"turn": turret_angle=PI

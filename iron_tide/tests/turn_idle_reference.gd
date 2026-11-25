extends Unit
func _limit_turn(delta: float) -> void:
	if is_air:
		# The grounded SCHD turret uses vehicle ROT; the airborne nose uses flight steering.
		if unit_id == "SCHP" and _deployed:
			turret_angle = rotate_toward(_turret_prev,turret_angle,deg_to_rad(float(_mv("rot",0.0))) * delta)
		return
	var rr := float(_mv("rot", 0.0))
	if rr <= 0.0:
		return
	var mx := deg_to_rad(rr) * delta
	var desired_hull := _drive_heading if is_finite(_drive_heading) else hull_angle
	hull_angle = _hull_prev + clampf(angle_difference(_hull_prev, desired_hull), -mx, mx)
	turret_angle = _turret_prev + clampf(angle_difference(_turret_prev, turret_angle), -mx, mx)

## RA2 碾压：Crusher=yes 的单位开过去直接碾死可被碾压的敌方步兵（含矿车 AutoCrush）。

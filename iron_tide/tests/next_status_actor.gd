extends Unit
func original_entries() -> Array:
	if _dead or hp<=0 or embarked_in!=null:return []
	var out: Array = preload("res://scripts/units/expansion_visual.gd").entries(self)
	for b in buffs:
		if float(b.get("left",0))<=0:continue
		var kind := str(b.get("kind", ""))
		var val := float(b.get("value", 0.0))
		var nm := str(b.get("name", ""))
		var spec: Dictionary = BUFF_KINDS.get(kind, {})
		var sh := str(spec.get("short", nm))
		var txt := nm
		match kind:
			"cooldown":
				txt = "冷却-%d%%" % int(round(val * 100.0))
			"regen":
				txt = "回血%.1f%%/s" % (val * 100.0)
			"stun", "tesla_emp":
				txt = nm
			_:
				txt = "%s+%d%%" % [sh, int(round(val * 100.0))]
		out.append({
			"kind": kind, "text": txt, "name": nm,
			"left": maxf(0.0, float(b.get("left", 0.0))),
			"dur": maxf(0.01, float(b.get("dur", 1.0))),
			"col": b.get("col", Color.WHITE), "col2": b.get("col2", Color(0, 0, 0, 0)),
			"debuff": (b.get("debuff", false) == true),
		})
	preload("res://tests/next_status_reference.gd").append_native(self,out)
	return preload("res://tests/next_status_reference.gd").normalize(out)

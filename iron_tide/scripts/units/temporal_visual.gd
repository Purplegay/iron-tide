extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Presentation only: temporal_by/work remain the saved gameplay authority.
## Original rulesmd.ini General.ChronoBeamColor = 128,200,255.
const BEAM_COLOR := Color(128.0 / 255.0, 200.0 / 255.0, 1.0)
const STATE := &"temporal_visual"

static func sync(actor) -> void:
	var owner = actor.special.get("temporal_by")
	var active: bool = is_instance_valid(owner) and not owner.is_queued_for_deletion() \
		and not owner._dead and owner.special.get("temporal_target") == actor and not actor._dead
	var c4: bool = actor is Building and not actor._dead and float(actor.special.get("c4_left", 0.0)) > 0.0
	var state: Dictionary = actor.get_meta(STATE, {})
	var split:bool=active and owner.special.get("temporal_skin")=="time_fracture"
	if not split and actor.has_meta("time_fracture"):
		actor.remove_meta("time_fracture")
		var clock=actor.get_node_or_null("EraseClock")
		if clock!=null:
			actor.remove_child(clock)
			clock.queue_free()
		actor.queue_redraw()
	if not active and not c4:
		if not state.is_empty():
			if actor.material == state.effect:
				actor.material = state.original
			actor.remove_meta(STATE)
			actor.queue_redraw()
		return
	# House materials are shared. Never change their uniforms in place.
	# Recreate only on entry or if a house-color update replaced the material.
	if state.is_empty() or actor.material != state.effect:
		var original: Material = actor.material
		var effect: ShaderMaterial
		if original is ShaderMaterial:
			effect = original.duplicate()
		else:
			effect = ShaderMaterial.new()
			effect.shader = HouseColor.shader_res()
		state = {"original": original, "effect": effect}
		actor.set_meta(STATE, state)
		actor.material = effect
		actor.queue_redraw()
	var work: float = float(owner.special.get("temporal_work", 0.0)) if active else 0.0
	var progress := clampf(work / maxf(actor.max_hp, 1.0), 0.0, 1.0)
	if split:
		var clock=actor.get_node_or_null("EraseClock")
		if clock==null:
			clock=Effects.Looks.Signature.new()
			clock.name="EraseClock"
			clock.event="chrono_live"
			clock.z_as_relative=false
			clock.z_index=DepthLayers.WORLD_HUD
			actor.add_child(clock)
			clock.set_process(false)
		clock.progress=progress
		clock.seconds_left=maxf(0,actor.max_hp-work)/maxf(0.001,erase_rate(owner))
		clock.global_position=actor.art_center()+RA2Art.art_dir(Vector2(0,-22))
		clock.queue_redraw()
		actor.set_meta("time_fracture",progress)
		actor.queue_redraw()
	state.effect.set_shader_parameter("fracture_ink",split)
	state.effect.set_shader_parameter("temporal_active", active)
	state.effect.set_shader_parameter("temporal_progress", progress)
	# Progress-driven shimmer freezes with pause and reconstructs after loading.
	state.effect.set_shader_parameter("temporal_phase", work * 0.07)
	# Countdown-driven red pulse also reconstructs after loading and pauses with play.
	state.effect.set_shader_parameter("c4_flash", (0.55 + 0.45 * cos(float(actor.special.c4_left) * TAU * 4.0)) if c4 else 0.0)

static func erase_rate(owner) -> float:
	var rate:=float(owner._active_weapon().get("damage",8))*15.0
	var target=owner.special.get("temporal_target")
	if is_instance_valid(target) and target is Unit and MetaProgress.Academy.survival_rank(target)>=5:
		return rate/P.number("hero/infantry/survival","temporal_duration")
	return rate

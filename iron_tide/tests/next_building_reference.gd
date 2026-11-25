extends Building
func original_process(delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(7)
	if special.has("tesla_pulse"):preload("res://scripts/buildings/tesla_pulse.gd").tick(self,delta)
	if special.has("reaper_focus") or special.has("split_focus") or special.has("reaper_heat"): preload("res://scripts/units/ra3_reaper_split.gd").advance_focus(self,delta)
	preload("res://scripts/units/civilian_orders.gd").tick_building(self)
	Ra3Clearance.tick(self, delta)
	if not _dead:
		preload("res://scripts/units/soviet_specials.gd").tick_actor(self, delta)
		AlliedAbilities.tick_actor(self, delta)
	if _dead or AlliedAbilities.frozen(self): return
	if special.has("hero_escort_queue"):
		special.hero_escort_retry=float(special.get("hero_escort_retry",0.0))-delta
		if special.hero_escort_retry<=0.0: MetaProgress.Academy.release_escorts(self)
	if building_id == "CAOILD": preload("res://scripts/world/civilian_sites.gd").oil_income(self, delta)
	if special.has("force_shield_left"):
		special.force_shield_left -= delta
		self_modulate = Color(0.7, 0.86 + 0.12 * sin(special.force_shield_left * 6.0), 1.4)
		if special.force_shield_left <= 0:
			special.erase("force_shield_left")
			self_modulate = Color.WHITE
	_tick_completion_flash(delta)
	if not _dead and _turret_art.advance_recoil(delta):
		queue_redraw()
	if _buildup_play >= 0.0:
		_buildup_play += delta * (GameData.ra2_buildup_seconds() / GM.FAST_BUILD_SECONDS if GM.no_build_time else float(special.get("native_make_speed",1.0)))
		if _buildup_play >= GameData.ra2_buildup_seconds():
			_buildup_play = -1.0
			if _completion_flash_pending:
				_start_completion_flash()
		queue_redraw()
	_tick_superweapon(delta)
	# Only a visible outage warning pulses; restoring power redraws once to clear it.
	if _refresh_power_warning():
		queue_redraw()
	# ---- RA2 建筑动画层：状态机推进 + 帧号变化才重绘（每层 Rate 不同，取各层帧号做指纹）
	if not _dead and not _ra2_anim.is_empty():
		_anim_t += delta
		_tick_anim_state(delta)
		# Clocks and gameplay keep advancing offscreen; inspect sprite frames only
		# where their draw list can be consumed. Re-entry already requests a redraw.
		if is_visible_in_tree() and _animation_draw_needed(): queue_redraw()
	if _dead:
		return
	if selected or hovered:
		queue_redraw()
	# 血条表现：白闪快速退散 + 残影追赶；受损时逐帧重绘以驱动脉冲闪烁
	if _hp_flash > 0.0:
		_hp_flash = maxf(0.0, _hp_flash - delta * 5.0)
	var _hpf: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	if _hp_ghost > _hpf:
		_hp_ghost = maxf(_hpf, _hp_ghost - delta * 1.2)
	else:
		_hp_ghost = _hpf
	if _hp_flash > 0.0 or _hp_ghost > _hpf + 0.004 or _hpf < 0.999:
		queue_redraw()
	# 建造进度（RA3：一边建造一边扣钱；资金不足则暂停）
	if under_construction:
		# RA2 低电：建造计时与分帧付款同步乘速度系数（总花费不变，工期变长）
		var pf := construction_work_rate()
		var step := minf(maxf(0.0, delta * pf), maxf(0.0, build_total - build_elapsed))
		var previous_elapsed := build_elapsed
		var pay_ok := true
		if build_cost > 0.0:
			pay_ok = battle.spend_side(side, build_cost / max(0.01, build_total) * step)
		if pay_ok:
			build_elapsed += step
			_pay_stall = false
		elif not _pay_stall:
			_pay_stall = true
			Events.emit_message("资金不足，%s 建造暂停" % display_name, Color(1.0, 0.8, 0.5))
			if side == "ally":
				Ra2Sfx.play_player_eva(battle, "EVA_InsufficientFunds")
		var k := clampf(build_elapsed / max(0.01, build_total), 0.0, 1.0)
		# Only newly completed work adds structural health. Never replace current
		# HP with the progress curve: that erased damage every frame, even stalled.
		var health_added := max_hp * 0.85 * (build_elapsed - previous_elapsed) / maxf(0.01, build_total)
		hp = minf(max_hp, hp + health_added)
		queue_redraw()
		if k >= 1.0:
			under_construction = false
			if special.erase("player_build_order") and side=="ally":preload("res://scripts/world/production_counts.gd").record(battle,"building",building_id)
			_start_completion_flash()
			if WallArt.is_wall(data):
				WallArt.refresh_neighbors(self)
			Events.emit_message("%s 建造完成" % display_name, _col)
			battle.strategic_site_completed(self, true)
			if side == "ally":
				Events.emit_radar_ping(global_position, "ready")   # (B3) 建成闪烁
				Ra2Sfx.play_player_eva(battle, "EVA_ConstructionComplete")
				Ra2Sfx.play_player_eva(battle, "EVA_NewConstructionOptions")
		return

	_tick_construction_free_unit(delta)

	# 资金涓流（RA2：Powered 建筑低电停摆时不再涓流，如矿石精炼器 GAOREP）
	if trickle > 0.0 and is_operational():
		battle.credit_income(side, trickle * delta, true)

	# (A4) 维修厂：为驻停的受损载具回血
	if _is_repair:
		_process_repair(delta)

	_process_building_repair(delta)

	_tick_unit_queues(delta)

	if building_id=="R3REAPERTURRET":
		preload("res://scripts/buildings/ra3_reaper_emplacement.gd").tick(self,delta)
		return
	# 炮塔
	if not weapon.is_empty():
		if data.has("charged_weapon"): preload("res://scripts/units/tesla_support.gd").update_weapon(self)
		if _prism_offline > 0.0:
			_prism_offline -= delta
		if _prism_offline > 0.0 or not is_operational():
			special.erase("coil_windup")
			return
		_think -= delta
		if _think <= 0.0:
			_think = 0.25
			_acquire_target()
		_cd = maxf(0.0, _cd - delta)
		if _valid_weapon_target(attack_target):
			if _turret_turn_speed > 0.0:
				_turret_art.turn_toward(attack_target.global_position - global_position, delta, _turret_turn_speed)
				queue_redraw()
			if _cd <= 0.0:
				if data.has("fire_delay") and not preload("res://scripts/units/tesla_support.gd").ready_to_fire(self,delta): return
				if _fire():
					_cd = preload("res://scripts/buildings/tesla_pulse.gd").reload_duration(self)
					special.card_reload_duration=_cd
		elif data.has("fire_delay"):
			special.erase("coil_windup")

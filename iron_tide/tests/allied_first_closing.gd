extends RefCounted
static func count_team(w,id: String) -> Array:
	return w.units.filter(func(u):return w.actor_alive(u) and u.special.get("allied_first_team","")==id)

static func opening(t,w,s: Dictionary) -> void:
	var m=w.AlliedFirst
	var d=m.closing_driver(w,s)
	m.tick(w,1.0)
	t.expect(d.rows.size()==20 and d.state.fired.has("080e410c") and d.state.fired.has("0a992f3c"),"正式出击执行开场揭图和原始房号行")
	var layer=w.get_node_or_null("AlliedFirstSmudges")
	t.expect(layer!=null and layer.visible and layer.texture.get_width()==3528,"可清除的烧痕和弹坑地面层在场")
	var ground=w.find_children("*","Ground",true,false)
	var file:=Image.new()
	file.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/maps/yr/yr_all01umd_terrain.png"))
	var texture=ground[0]._surface.texture if not ground.is_empty() else null
	var loaded: Image=texture.get_image() if texture!=null else null
	if loaded!=null:
		loaded.clear_mipmaps()
		loaded.convert(Image.FORMAT_RGB8)
	file.convert(Image.FORMAT_RGB8)
	t.expect(loaded!=null and texture.resource_path=="res://assets/maps/yr/yr_all01umd_terrain.png" and loaded.get_size()==file.get_size() and loaded.get_data()==file.get_data(),"实加载纹理使用本批海崖和日光烘焙像素")
	var dom=m.present_controller(w)
	t.expect(dom!=null and d.state.fired.has("0b7c0aec") and absf(dom.sw_progress()-0.90)<0.01,"原房号控制器设置90%充能")
	t.expect(not d.state.fired.has(d.BACK) and d.definition.attached[d.BACK].is_empty(),"没有附着对象的后桥事件不会在开局凭空触发")
	for pair in [["0437c23c","0437F1EC","1028434"],["089cf54c","089CE49C","1028381"]]:
		t.expect(not d.state.enabled.has(pair[0]) and count_team(w,pair[1]).is_empty(),"保留驻军原图默认关闭 "+pair[1])
		d.enable(pair[0])
		d.run(w,s,0.99)
		t.expect(count_team(w,pair[1]).is_empty(),"驻军招募不早于一秒 "+pair[1])
		d.run(w,s,0.01)
		var team:=count_team(w,pair[1])
		t.expect(team.size()==5 and team.all(func(u):return u.unit_id=="INIT" and u.special.has("allied_first_index") and u.attack_target is Building and u.attack_target.special.allied_first_index==pair[2]),"原图五名新兵锁定航点内的真实建筑 "+pair[1])
	d.enable("0e0ea53c")
	d.run(w,s,0.0)
	t.expect(not d.state.fired.has("0e0ea53c"),"未选中绑定控制器时保持静默")
	w.select_building(dom)
	d.run(w,s,0.0)
	var voice=w.get_node_or_null("AlliedFirstVoice")
	t.expect(d.state.fired.has("0e0ea53c") and voice!=null and voice.stream!=null and voice.stream.resource_path.ends_with("cevau70.wav"),"选中指定建筑时播放原图语音")
	for id in ["043808cc","043772bc","04378f3c","0438076c"]:
		for b in d.attached(w,id): m.Orders.change_side(b,"enemy"); b.special.allied_first_room="YuriCountry"
	d.enable("043808cc")
	d.run(w,s,4.0)
	for id in ["043808cc","043772bc","04378f3c","0438076c"]:
		t.expect(d.state.fired.has(id) and d.attached(w,id)[0].side=="ally","四门炮按原实例依次归还 "+id)
	var satellite=m.site(w,"GASPYSAT")
	d.run(w,s,0.0)
	t.expect(satellite!=null and not d.state.fired.has(d.SPYSAT),"雷达存活不重遮图")
	satellite.receive_hit(satellite.max_hp*20,"explosive")
	d.run(w,s,0.0)
	t.expect(d.state.fired.has(d.SPYSAT) and w.fog.explored_cells.ally.count(0)>0,"原雷达被毁后清除旧探索并揭露SC区域")
	for id in ["043bb08c","07a89c0c","079b8bbc","079bae6c","07ec78ac"]: d.enable(id)
	d.run(w,s,1.0)
	t.expect(d.state.fired.has("043bb08c") and d.state.fired.has("07a89c0c") and d.state.fired.has("079b8bbc") and d.state.fired.has("079bae6c"),"受控空附着行保持空目标，航点伤害独立执行")
	t.expect(d.state.fired.has("07ec78ac") and s.get("closing_timer_stopped",false),"低电停表；原图未启动全局任务倒计时")

static func damage_before_swap(w) -> void:
	var stable: Array=w.buildings.filter(func(b):return w.actor_alive(b) and b.special.get("allied_first_room","")=="Neutral" and b.building_id in ["CASANF01","CASANF02"] and b.special.has("allied_first_index"))
	var gone=stable[0]
	var hurt=stable[1]
	w.set_meta("closing_restore_ids",{gone.special.allied_first_index:gone.position,hurt.special.allied_first_index:hurt.position})
	w.set_meta("closing_destroyed_point",gone.position)
	gone.receive_hit(gone.max_hp*100,"explosive")
	hurt.hp=hurt.max_hp*0.25

static func verify_restore(t,w) -> void:
	var at: Vector2=w.get_meta("closing_destroyed_point")
	t.expect(w.allied_state.get("building_rubble",[]).all(func(row):return not row.point.is_equal_approx(at)) and w.get_tree().get_nodes_in_group("yr_building_rubble").all(func(node):return node.world!=w or not node.position.is_equal_approx(at)),"原址重建同时清理该楼的存档废墟和地面残骸")
	for id in w.get_meta("closing_restore_ids"):
		var matching: Array=w.buildings.filter(func(b):return w.actor_alive(b) and b.special.get("allied_first_index","")==id)
		t.expect(matching.size()==1 and matching[0].position.is_equal_approx(w.get_meta("closing_restore_ids")[id]) and matching[0].side=="neutral" and is_equal_approx(matching[0].hp,matching[0].max_hp),"原中立建筑按原址恢复且无重复 "+str(id))
static func past(t,w,s: Dictionary) -> void:
	var m=w.AlliedFirst
	var d=m.closing_driver(w,s)
	m.tick(w,1.0)
	t.expect(d.state.fired.has(d.FIX) and d.state.fired.has(d.CREATE) and d.state.fired.has(d.CLEAN),"穿越后还原建筑、创建舰队及清图均由原表执行")
	var field=m.field_driver(w,s)
	t.expect(s.get("closing_smudges_cleared",false) and not w.get_node("AlliedFirstSmudges").visible,"两个原始清痕动作清除首关地面层")
	for wp in [302,303]:
		var at: Vector2=m.wp(wp)+Vector2(-0.5,0.5)*m.Places.CELL
		t.expect(w.buildings.any(func(b):return w.actor_alive(b) and b.building_id=="GAPOWR" and b.side=="ally" and b.position.distance_to(at)<m.Places.CELL),"清图后从原始航点建造盟军电厂 "+str(wp))
	for id in ["09569A4C","0956959C","0956AEFC","0B4FFC8C","0955BB7C","0955B6CC"]:
		t.expect(count_team(w,id).size()==1,"换场舰队每队只出现一次 "+id)
	t.expect(field.state.fired.has(field.KILL_SOUNDS),"清图衔接过去时代环境声")
	t.expect(BattleSaves.save_slot(w,"quick").ok,"穿越后写入收尾驱动断点")

static func cold(t,w) -> void:
	var s: Dictionary=w.allied_state.allied_first
	var fired: Dictionary=s.retail_closing.fired.duplicate()
	w.AlliedFirst.tick(w,0.0)
	var layer=w.get_node_or_null("AlliedFirstSmudges")
	t.expect(s.retail_closing.fired==fired and (layer==null or not layer.visible),"冷读清图状态和触发断点保持")
	t.expect(count_team(w,"0955BB7C").size()==1,"冷读没有重新派遣同一艘无畏舰")

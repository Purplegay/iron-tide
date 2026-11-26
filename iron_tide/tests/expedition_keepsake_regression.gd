extends "res://tests/expedition_regression.gd"

const Gifts=preload("res://scripts/expedition/commander_keepsakes.gd")
const Orders=preload("res://scripts/expedition/keepsake_orders.gd")
const Guide=preload("res://scripts/expedition/field_guide.gd")
var home:Vector2
var stage_origin:Vector2
var troops:Dictionary={}
var dummy
var second
var order
var timer_max := OS.get_environment("IRON_TIDE_TEST_MAX_TIMER")=="1"
var stage_fog

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	var expected_limits:=[0,1,1,2,2,3,3,3,3,3,4,4]
	for index in expected_limits.size():
		check(Gifts.slot_limit(index+1)==expected_limits[index],"keepsake capacity for cycle %d"%(index+1))
	check(Gifts.ITEMS.size()==13 and Gifts.ITEMS.size()==Guide.Stories.PEOPLE.size(),"each of the thirteen commanders grants a keepsake")
	check(Gifts.ICON_SHEET.get_size()==Vector2(832,64),"thirteen complete icon cells")
	for person:String in Gifts.ITEMS:
		check(Guide.Stories.PEOPLE.has(person),"keepsake belongs to a field contact "+person)
		var gift:Dictionary=Gifts.ITEMS[person]
		check(not gift.gift.is_empty() and not gift.after.is_empty() and gift.after!=gift.gift,"both original stories for "+person)
		for partner:String in gift.partners:check(GameData.unit_index.has(partner),"real unit "+partner)
		MetaProgress.contact_transcripts[person]={"rescued":true}
	check(Expedition.start("美国","",864),"start before any clear")
	check(Expedition.state.reunion_contacts.is_empty() and not Gifts.inscribe("lin",Expedition.state,false),"first run cannot grant")
	check(not Expedition.start("美国","",864,{},"lin"),"unowned selection refused")
	var finale:Dictionary=Expedition.state.duplicate(true)
	finale.stage=Campaign.TOTAL;Expedition.ready(finale)
	check(Expedition.commit(finale) and Expedition.launch(0),"launch final-stage settlement fixture")
	if not instantiate_battle():get_tree().quit(1);return
	check(Expedition.settle(battle,true) and Expedition.state.phase=="complete","final victory actually grants account receipt")
	await finish()
	check(Expedition.start("美国","",864) and Expedition.state.reunion_contacts.size()==13,"completed expedition and earlier rescues enable reunions")
	check(Expedition.choose(0) and Expedition.launch(0),"launch first reunion")
	if not instantiate_battle():get_tree().quit(1);return
	var ops = screen.expedition_runtime.field_ops
	var rescues: Array = ops.data.objectives.filter(func(o):return o.kind == "contact")
	check(rescues.size() == 1, "deployed a rescue for this stage")
	if rescues.is_empty():get_tree().quit(1);return
	var rescue: Dictionary = rescues[0]
	var speaker: String = rescue.person.id
	screen.expedition_runtime.queue_gift(speaker)
	screen.expedition_runtime.deliver_gifts()
	check(not Gifts.owned(speaker) and not Gifts.inscribe(speaker,Expedition.state,false), "spawning the NPC and attempting delivery cannot grant a keepsake")
	ops.complete(rescue)
	check(Gifts.owned(speaker),"reunion delivery gives permanent gift")
	var notice = screen.expedition_runtime.gift_notice
	check(notice.get_child_count()==1 and (speaker in notice.waiting or notice.find_children("*","Label",true,false).any(func(l):return l.text==Gifts.ITEMS[speaker].name)),"new gift is on the battlefield banner or queued behind another gift")
	check(notice.find_children("*","Control",true,false).all(func(c):return c.mouse_filter==Control.MOUSE_FILTER_IGNORE),"gift announcement lets battlefield clicks through")
	var queued: int = notice.waiting.size()
	screen.expedition_runtime.queue_gift(speaker)
	screen.expedition_runtime.deliver_gifts()
	check(notice.waiting.size()==queued and notice.get_child_count()==1,"repeat delivery does not enqueue another banner")
	check(not Gifts.inscribe(speaker,Expedition.state,false),"reopening does not duplicate gift")
	for id:String in Gifts.ITEMS:
		if id in ["edith","sami"]:
			ops.meet_contact(id)
			screen.expedition_runtime.queue_gift(id)
			screen.expedition_runtime.deliver_gifts()
			check(Gifts.owned(id) and not Gifts.inscribe(id,Expedition.state,false),"reunion awards new gift once "+id)
		elif id!=speaker:check(Gifts.owned(id) or Gifts.inscribe(id,Expedition.state,false,[id]),"gift "+id)
	MetaProgress.load_save()
	for id:String in Gifts.ITEMS:check(Gifts.owned(id),"gift survives disk reload "+id)
	var report_rows:=VBoxContainer.new()
	notice.add_report_rows(report_rows,Expedition.state.id,Expedition.state.stage+1)
	notice.add_report_rows(report_rows,"different-run",Expedition.state.stage)
	check(report_rows.get_child_count()==0,"gift receipts are isolated by run and stage")
	notice.add_report_rows(report_rows,Expedition.state.id,Expedition.state.stage)
	check(report_rows.get_child_count()==13,"stage report lists all new permanent gifts after reload")
	report_rows.free()
	await finish()
	check(Expedition.start("美国","",865) and Expedition.choose(0),"prepare camp")
	check(Gifts.ITEMS.keys().all(func(id):return not Expedition.equip_keepsake(id)), "no unselected permanent gift can be added at the start")
	check_camp_gift_buttons([])
	check(Expedition.launch(0) and instantiate_battle(), "launch with gifts owned from previous run")
	ops = screen.expedition_runtime.field_ops
	rescue = ops.data.objectives.filter(func(o):return o.kind == "contact")[0]
	speaker = rescue.person.id
	check(ops.data.get("met_contacts", []).is_empty(), "owned gifts and rescue markers do not count as a meeting")
	ops.complete(rescue)
	check(Expedition.checkpoint(battle), "checkpoint after meeting returning commander")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle() and instantiate_battle(), "restore actual reunion from checkpoint")
	check(screen.expedition_runtime.field_ops.data.met_contacts == [speaker] and Expedition.retreat(battle), "retreat retains an actual reunion")
	await finish()
	check(Expedition.load_run(), "reload camp after meeting")
	check_camp_gift_buttons([speaker])
	check(Expedition.equip_keepsake(speaker) and not Expedition.equip_keepsake(speaker), "only the reunited commander allows one camp addition")
	check_camp_gift_buttons([])
	check(not Expedition.start("美国","",866,{},Gifts.ITEMS.keys()),"over-limit departure refused")
	check(Expedition.start("美国","",866,{},["lin"]) and Expedition.choose(0),"permanent gift selected at departure")
	var next:Dictionary=Expedition.state.duplicate(true)
	# Preserve the complete equipped set from an older save.
	next.keepsakes=Gifts.ITEMS.keys()
	next.keepsakes.reverse()
	var timer_run:Dictionary={}
	for rank in range(6):
		check(Gifts.opening_cooldown(12,timer_run)==300-30*rank,"capped opening at rank %d"%rank)
		Market.Relics.grant(timer_run,"signal_timer")
	check(not Market.Relics.can_gain(timer_run,"signal_timer"),"timer capped at five")
	if timer_max:
		for rank in range(5):Market.Relics.grant(next,"signal_timer")
	next.stage=10;Expedition.ready(next)
	check("APOC" not in next.catalog,"foreign partner stays outside early American pool")
	next.stage=11;Expedition.ready(next)
	var partner_offer:Array=Market.unit_pool(next).filter(func(row):return row.id=="APOC")
	check(partner_offer.size()==1,"foreign partner in real recruitment pool")
	if partner_offer.is_empty():get_tree().quit(1);return
	var item:Dictionary=partner_offer[0];item.sold=false;next.shop=[item];next.supplies=1000
	check(Expedition.commit(next) and Expedition.buy(0) and "APOC" in Army.available(Expedition.state),"recruit foreign partner through normal shop purchase")
	check(Expedition.launch(0),"launch equipped run")
	if not instantiate_battle():get_tree().quit(1);return
	if not await check_opening_cooldowns(next.keepsakes):get_tree().quit(1);return
	var support_button:Button=screen.expedition_runtime.keepsake_orders.lin.button
	var sidebar=screen.hud._sw_sidebar
	sidebar.refresh()
	check(support_button.get_parent()==sidebar.grid and sidebar.visible and support_button.icon!=null,"gift is an illustrated strategic support action")
	var seen:Dictionary={}
	for owner_id:String in Gifts.ITEMS:
		var tile:=Gifts.icon(owner_id) as AtlasTexture
		check(tile!=null and tile.atlas==Gifts.ICON_SHEET and tile.region.size==Vector2(64,64) and not seen.has(tile.region.position),"unique keepsake illustration: "+owner_id)
		if tile!=null:seen[tile.region.position]=true
	check(support_button.icon==Gifts.icon("lin"),"support button uses equipped keepsake illustration")
	check(screen.expedition_runtime.keepsake_orders.lin.id=="lin" and screen.expedition_runtime.keepsake_orders.lin.button.text=="接人","equipped gift has real battle button")
	home=battle.player_start()
	stage_origin=home+Vector2(410,0)
	stage_fog=battle.fog;battle.fog=null
	get_tree().paused=false;battle.paused=false
	for spec:Dictionary in Gifts.ITEMS.values():
		for kind:String in spec.partners:
			if not troops.has(kind):troops[kind]=battle.spawn_unit(kind,"ally",stage_origin+Vector2(0,100))
	dummy=battle.spawn_unit("HTNK","enemy",stage_origin)
	second=battle.spawn_unit("HTNK","enemy",stage_origin+Vector2(40,0))
	dummy.max_hp=100000;dummy.hp=dummy.max_hp
	second.max_hp=100000;second.hp=second.max_hp
	for kind:String in Gifts.ITEMS:
		if kind!="lin":check_order(kind)
	check_order("lin")
	battle.fog=stage_fog
	check(Expedition.checkpoint(battle),"save battlefield with spent order",Expedition.error)
	var snapshot:Dictionary=Expedition.read_file(Expedition.FILE).checkpoint
	check(not snapshot.is_empty(),"disk checkpoint is readable")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"prepare resume from disk")
	if instantiate_battle():
		for owner_id:String in ["edith","sami"]:
			var restored_gift=screen.expedition_runtime.keepsake_orders[owner_id]
			check(restored_gift.state.has("cooldown") and restored_gift.button.icon==Gifts.icon(owner_id),"checkpoint preserves spent charge and icon "+owner_id)
		var outer_point:=Vector2.ONE*float(battle.map_size)*0.5+Vector2(470,0)
		check(battle.fog.is_visible_at("ally",outer_point) and is_equal_approx(battle.fog.sight_until.ally.get(battle.fog._index(outer_point),0.0),10.0),"active watch retains remaining sight after reload")
		var restored=screen.expedition_runtime.keepsake_orders.lin
		check(screen.expedition_runtime.keepsake_orders.su.state.cooldown>0,"separate cooldown restored beside spent charge")
		check(restored.state.has("cooldown") and restored.state.get("events",[]).size()==1,"spent charge and one remaining echo restored from checkpoint")
		restored.advance(1.0)
		check(not restored.state.has("events") and not restored.ready_to_act(),"remaining echo clears without rearming the gift")
		get_tree().paused=false;battle.paused=false
		for owner_id:String in Gifts.ITEMS:
			var gift=screen.expedition_runtime.keepsake_orders[owner_id]
			var left:float=gift.state.cooldown
			if owner_id=="yusuf":
				check(gift.button.text.begins_with("签收运费\n"),"saved action returns with the countdown")
			check(left>0 and left<=600 and gift.button.disabled,"saved cooldown "+owner_id)
			gift.advance(left-0.5)
			check(not gift.ready_to_act() and gift.button.text.ends_with("0:01"),"last half second "+owner_id)
			gift.advance(0.5)
			check(gift.ready_to_act() and not gift.button.disabled,"rearmed "+owner_id)
		check(Expedition.settle(battle,true),"finish stage after using equipped orders")
		await finish()
		var following := Expedition.state.duplicate(true)
		Expedition.ready(following)
		check(Expedition.commit(following) and Expedition.launch(0),"launch following stage with same carried order")
		if instantiate_battle():
			var orders: Dictionary = screen.expedition_runtime.keepsake_orders
			check(not orders[next.keepsakes[0]].button.disabled and orders[next.keepsakes[1]].state.cooldown==(5 if timer_max else 10) and orders[next.keepsakes.back()].state.cooldown==(150 if timer_max else 300),"fresh stage reapplies opening delays")
			await finish()
	MetaProgress.load_save()
	var archive:=VBoxContainer.new()
	Guide.add_archive(archive)
	for id:String in Gifts.ITEMS:
		var info:Dictionary=MetaProgress.contact_transcripts[id]
		check(info.has("joint_record") and info.get("joint_record",{}).get("date","")!="","dated joint story on disk "+id)
		var rows:=archive.find_children("*","Label",true,false)
		check(rows.any(func(row):return row.text.contains(Gifts.ITEMS[id].gift)) and rows.any(func(row):return row.text.contains(Gifts.ITEMS[id].after)),"archive contains both earned stories "+id)
	archive.free()
	await check_reunion_upgrades()
	print("KEEPSAKES checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check_reunion_upgrades() -> void:
	# All thirteen original receipts were earned in cycle 2 earlier in this flow.
	var titles := {}
	for level in range(2,6):
		var cycle := level + 2 # skip a cycle before the first upgrade
		var run := {"id":"revisit-%d" % cycle,"cycle":cycle,"stage":7,"reunion_contacts":Gifts.ITEMS.keys()}
		for id: String in Gifts.ITEMS:
			check(not Gifts.inscribe(id,run,false,[]), "no upgrade before meeting "+id)
			check(Gifts.inscribe(id,run,false,[id]) and Gifts.rank(id)==level, "one rank on reunion %s/%d" % [id,level])
			var retry := run.duplicate()
			retry.id = "another-run-in-%d" % cycle
			check(not Gifts.inscribe(id,retry,false,[id]), "restarting in same cycle cannot upgrade "+id)
			var title := Gifts.story(id,level).get_slice("\n",0)
			check(not titles.has(title) and Gifts.story(id,level).length()>40, "distinct authored reunion "+title)
			titles[title]=true
			check(Gifts.use_cooldown(600,id,{})==600-60*(level-1),"earned cooldown for "+id)
			var guide := Gifts.guide_for_run(id,run)
			check(not guide.contains("{") and not guide.contains("}"), "resolved area values in " + id)
			if id == "yusuf":
				check(guide.contains("获得 %d 战场资金" % (4500+500*level)) and guide.contains("提供 %d 资金" % (900+100*level)), "ranked freight rates")
			if id in ["greta","nadya","su","yusuf"]:
				check(not guide.contains("基础范围"), "global order has no range upgrade " + id)
		var pump_radius: int = [286,312,338,364][level-2]
		check(Gifts.guide_for_run("sami",run).contains("半径 %d 内" % pump_radius),"pump guide matches earned rank %d" % level)
		if level == 2:
			await check_rank_two_healing()
		if level == 3:
			var timer_fixture := {}
			for i in 5:Market.Relics.grant(timer_fixture,"signal_timer")
			check(Gifts.guide_for_run("yusuf",timer_fixture).contains("冷却 240 秒") and Gifts.guide_for_run("yusuf",timer_fixture).contains("96 秒"),"distinct normal and joint cooldowns in tooltip")
		MetaProgress.load_save()
		check(Gifts.rank("sami")==level, "published rank survives disk reload")
	check(titles.size()==52, "four unique reunions per commander")
	var next := {"id":"after-cap","cycle":16,"stage":2,"reunion_contacts":Gifts.ITEMS.keys()}
	for id: String in Gifts.ITEMS:
		check(not Gifts.inscribe(id,next,false,[id]) and Gifts.receipts(id).size()==5, "hard cap "+id)
	var rows := VBoxContainer.new()
	preload("res://scripts/expedition/keepsake_notice.gd").add_report_rows(rows,"revisit-7",7)
	check(rows.get_child_count()==13, "reports show earned upgrades in the original stage")
	rows.free()
	# Re-enter a later cycle with one gift at rank 4. Deliver through the battlefield rescue event.
	new_ready("美国",1)
	var fixture: Dictionary = Expedition.state.duplicate(true)
	fixture.cycle = 8
	fixture.keepsakes = Gifts.ITEMS.keys()
	check(Expedition.commit(fixture) and Expedition.launch(0), "launch later-cycle reunion battle")
	if not instantiate_battle():return
	var runtime = screen.expedition_runtime
	var expected_areas := {
		"sami":{"radius":364}, "volkov":{"radius":364}, "seojin":{"radius":420},
		"edith":{"radius":448,"reveal":784}, "vera":{"radius":420}, "yusuf":{},
		"lin":{"radius":364,"blast":224}, "mara":{"radius":203},
		"ines":{"radius":420,"reveal":525,"chain":294}, "qiao":{"half_width":112,"wide_half_width":168}
	}
	for owner: String in expected_areas:
		check(runtime.keepsake_orders[owner].area == expected_areas[owner], "equipped rank-five distances " + owner)
	var rescues: Array = runtime.field_ops.data.objectives.filter(func(o):return o.kind=="contact")
	check(rescues.size()==1,"deployed reunion target")
	if not rescues.is_empty():
		var rescue: Dictionary = rescues[0]
		var id: String = rescue.person.id
		MetaProgress.contact_transcripts[id].keepsake_upgrades.pop_back()
		var command = runtime.keepsake_orders[id]
		command.update_rank()
		command.state.cooldown = 111.0
		command.state.erase("cooldown_total")
		var before: float = command.rearm_seconds
		runtime.field_ops.complete(rescue)
		check(Gifts.rank(id)==5 and command.rearm_seconds==360 and command.state.cooldown==111.0 and command.state.cooldown_total==before, "live reunion strengthens next use and preserves running countdown")
		check(command.button.tooltip_text.contains("5/5") and runtime.gift_notice.displayed!=null, "upgrade appears on HUD and gift banner")
		command.advance_cooldown(111.0)
		command.finish(false)
		check(command.state.cooldown==360, "next actual command uses upgraded cooldown")
	await finish()
	var relic_run := {}
	for i in 5:Market.Relics.grant(relic_run,"signal_timer")
	check(Gifts.use_cooldown(600,"vera",relic_run)==180 and Gifts.use_cooldown(240,"yusuf",relic_run)==72, "rank stacks with timer for both cooldowns")
	check(Gifts.opening_cooldown(2,relic_run)==15, "departure stagger still uses only timer")
	var legacy := {"settled_matches":{"expedition:old:30":true},"contact_transcripts":{"lin":{"keepsake":{"run":"old"}},"vera":{"keepsake":{"run":"unknown"}}}}
	check(Gifts.migrate_cycles(legacy) and not Gifts.migrate_cycles(legacy), "old first-gift receipts migrate once")
	check(legacy.contact_transcripts.lin.keepsake.cycle==1 and legacy.contact_transcripts.vera.keepsake.cycle==2, "completed run and unknown legacy cycle anchors")

func check_rank_two_healing() -> void:
	new_ready("美国",1)
	var fixture: Dictionary = Expedition.state.duplicate(true)
	fixture.keepsakes = ["sami"]
	check(Expedition.commit(fixture),"equip rank-two pump")
	var camp = load("res://scenes/expedition.tscn").instantiate()
	add_child(camp)
	camp.change_tab(4)
	var controls := camp.find_children("*","Control",true,false) as Array
	check(controls.any(func(c):return c.tooltip_text.contains("泵站点验") and c.tooltip_text.contains("半径 286 内")),"camp summary shows rank-two pump radius")
	camp.free()
	var archive := VBoxContainer.new()
	Guide.add_archive(archive)
	check(archive.find_children("*","Label",true,false).any(func(l):return l.text.contains("半径 286 内受损")),"commander archive shows rank-two pump radius")
	archive.free()
	check(Expedition.launch(0),"launch rank-two pump battle")
	if not instantiate_battle():return
	var pump = screen.expedition_runtime.keepsake_orders.sami
	var point := Vector2(600,600)
	var inside = battle.spawn_unit("E1","ally",point+Vector2(286,0))
	var outside = battle.spawn_unit("E1","ally",point+Vector2(0,287))
	inside.hp = inside.max_hp * 0.5
	outside.hp = outside.max_hp * 0.5
	get_tree().paused=false
	battle.paused=false
	check(pump.button.tooltip_text.contains("半径 286 内") and pump.aid_targets(point).has(inside) and not pump.aid_targets(point).has(outside),"rank-two HUD and aim include 286 and exclude 287")
	check(pump.fire_at(point) and inside.hp > inside.max_hp * 0.5 and outside.hp == outside.max_hp * 0.5,"rank-two healing reaches the edge of the expanded circle")
	await finish()

func check_camp_gift_buttons(expected: Array) -> void:
	var camp = load("res://scenes/expedition.tscn").instantiate()
	add_child(camp)
	var summary_tab: Button = camp.find_children("*", "Button", true, false).filter(func(b):return b.text == "战报与收获").front()
	check(summary_tab.has_node("AttentionDot") == (not expected.is_empty()), "summary tab signals available keepsakes from the route page")
	summary_tab.pressed.emit()
	var buttons: Array = camp.find_children("*", "Button", true, false)
	var offered: Array = []
	for b: Button in buttons:
		if b.text == "战报与收获":
			check(b.disabled and b.has_node("AttentionDot") == (not expected.is_empty()), "selected summary tab keeps its pending reminder")
		for id: String in Gifts.ITEMS:
			if b.text == "携带" + Gifts.ITEMS[id].name:
				offered.append(id)
				check(b.has_node("AttentionDot"), "available keepsake button shows its dot " + id)
	check(offered == expected, "summary offers only current expedition reunions", offered)
	camp.free()

func check_opening_cooldowns(carried: Array) -> bool:
	var expected := [0,5,15,30,50,75,105,140,150,150,150,150,150] if timer_max else [0,10,30,60,100,150,210,280,300,300,300,300,300]
	var orders: Dictionary = screen.expedition_runtime.keepsake_orders
	get_tree().paused=false
	battle.paused=false
	var before_ready := Ra2Sfx.a_plays
	check(GameData.ra2_sound_files("SupportReady")==["umessage.wav"],"ready cue resolves to the global message sound")
	for slot in carried.size():
		var gift = orders[carried[slot]]
		if carried[slot]=="yusuf":
			check(gift.button.text.begins_with("签收运费"),"opening charge does not claim a freight payment")
		check(gift.state.get("cooldown",0)==expected[slot] and gift.button.disabled==(slot>0),"opening cooldown and HUD slot %d"%(slot+1))
		check(gift.charge_mask.visible==(slot>0) and (slot==0 or gift.charge_mask.value==1),"opening mask starts full for locked slots")
		if slot>0:
			gift.press()
			check(not gift.aiming and not gift.ready_to_act(),"opening lock prevents activation slot %d"%(slot+1))
		gift.advance(25.0)
	check(Ra2Sfx.a_plays==before_ready+1,"opening charges finishing together play one ready cue")
	check(Ra2Sfx._eva_last.has(Ra2Sfx.STRATEGIC_SUPPORT_READY),"keepsake cooldown expiry requests the English advisor line")
	before_ready=Ra2Sfx.a_plays
	for gift in orders.values():
		gift.refresh()
		gift.advance(0.0)
	check(Ra2Sfx.a_plays==before_ready,"refresh and idle ready orders stay silent")
	check(Expedition.checkpoint(battle),"save during staggered opening")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"reload staggered opening from disk")
	if not instantiate_battle():return false
	check(Ra2Sfx._support_ready_frame!=Engine.get_process_frames(),"restoring already-ready buttons plays no ready cue")
	get_tree().paused=false
	battle.paused=false
	for slot in carried.size():
		var gift = screen.expedition_runtime.keepsake_orders[carried[slot]]
		var left := maxi(0,int(expected[slot])-25)
		check(gift.state.get("cooldown",0)==left and gift.ready_to_act()==(left==0),"restore remaining opening delay slot %d"%(slot+1))
		check(gift.charge_mask.visible==(left>0) and (left==0 or absf(gift.charge_mask.value-float(left)/expected[slot])<0.004),"restore opening mask at original fraction")
		if left>0:
			await get_tree().process_frame
			var sounds := Ra2Sfx.a_plays
			gift.advance(left-0.5)
			check(Ra2Sfx.a_plays==sounds,"resumed order stays silent before expiry")
			check(gift.button.disabled and gift.button.text.ends_with("0:01"),"opening shows final second slot %d"%(slot+1))
			gift.advance(0.5)
			check(Ra2Sfx.a_plays==sounds+1,"each separately completed charge plays its own cue")
		check(gift.ready_to_act() and not gift.button.disabled,"opening unlocks slot %d"%(slot+1))
		check(not gift.charge_mask.visible,"ready slot removes cooldown mask")
	return true

func order_click(point:Vector2, key := MOUSE_BUTTON_LEFT) -> void:
	order_button(point, key, true)
	order_button(point, key, false)

func order_button(point:Vector2, key: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = battle.get_canvas_transform() * point
	event.button_index = key
	event.pressed = down
	order._input(event)

func check_order(kind:String) -> void:
	order=screen.expedition_runtime.keepsake_orders[kind]
	var before:float=dummy.hp
	if order.AREA_HINT.has(kind):
		battle.selected_units=[]
		order.button.pressed.emit()
		check(order.aiming and order.is_processing() and battle.get_meta("keepsake_area_cursor", "")==kind,"area cursor armed "+kind)
		order_click(stage_origin,MOUSE_BUTTON_RIGHT)
		check(not order.aiming and not battle.has_meta("keepsake_area_cursor") and order.ready_to_act(),"area cancel "+kind)
	match kind:
		"vera":
			battle.selected_units=[troops.TTNK]
			order.button.pressed.emit()
			check(order.aiming and order.instruction.visible and dummy.hp==before,"key previews strike with tank selected")
			order_click(stage_origin,MOUSE_BUTTON_RIGHT)
			check(not order.aiming and not order.state.has("cooldown"),"cancel preserves lightning")
			battle.selected_units=[]
			var ally_hp:float=troops.TTNK.hp
			var second_hp:float=second.hp
			order.button.pressed.emit()
			order_click(stage_origin)
			check(order.state.has("cooldown") and not order.aiming and dummy.hp<before and second.hp<second_hp and troops.TTNK.hp==ally_hp,"ground lightning hits nearby enemies and spares allies")
			check(MetaProgress.contact_transcripts.vera.has("joint_record"),"partners on field earn lightning record")
		"volkov":
			order.press()
			battle.fog = stage_fog
			var dark := Vector2.ZERO
			for x in range(128, int(battle.map_size)-128, 128):
				var candidate := Vector2(x, 128)
				if not stage_fog.is_visible_at("ally", candidate):
					dark = candidate
					break
			check(dark != Vector2.ZERO, "artillery test starts in fog")
			var origin:Vector2 = dummy.position
			dummy.position = dark
			order_click(dark)
			check(stage_fog.is_visible_at("ally", dark) and is_equal_approx(stage_fog.sight_until.ally.get(stage_fog._index(dark), 0.0) - stage_fog.sight_clock, 3.0), "artillery impact grants three seconds of sight")
			check(dummy.hp<before and not order.aiming,"ground artillery hits without selected tank")
			dummy.position = origin
			battle.fog = null
		"lin":
			var unit=troops.APOC
			var origin := stage_origin + Vector2(0,-275)
			var crowd := [troops.HTNK,troops.GGI,troops.TNKD,troops.SREF,troops.TTNK]
			var positions:Array=[]
			var health:Array=[]
			for i in crowd.size():
				positions.append(crowd[i].position)
				health.append(crowd[i].hp)
				crowd[i].position=origin+Vector2(i*3,0)
				crowd[i].hp=crowd[i].max_hp*(0.1+i*0.1)
			check(order.rescue_targets(origin)==crowd.slice(0,4),"preview prioritizes four lowest health fractions")
			for i in crowd.size():
				crowd[i].position=positions[i]
				crowd[i].hp=health[i]
			unit.position=origin
			battle.selected_units=[]
			order.button.pressed.emit()
			check(order.aiming and order.is_processing() and order.rescue_targets(origin).has(unit),"rescue previews ally without preselection")
			order_click(Vector2(2,2))
			check(order.aiming and not order.state.has("cooldown"),"empty rescue keeps aim and cooldown ready")
			order_click(origin,MOUSE_BUTTON_RIGHT)
			check(not order.aiming and not order.state.has("cooldown"),"cancel preserves rescue")
			order.button.pressed.emit()
			order_click(origin)
			var hp:float=unit.hp
			unit.receive_hit(400,"shell",{},dummy)
			order.advance(4.9)
			check(unit.hp==hp and unit.special.has("rescue_shield") and unit.position==origin,"shield absorbs hit and holds until departure")
			var departure := origin + Vector2(300, 0)
			unit.position = departure
			dummy.position = departure
			second.position = origin
			var blast_hp:float = dummy.hp
			var outside_hp:float = second.hp
			order.advance(0.11)
			check(dummy.hp < blast_hp and second.hp == outside_hp and unit.hp == hp, "shield bursts at moving passenger before echo")
			check(not unit.special.has("rescue_shield") and unit.position.distance_to(home)<600 and unit.position!=origin and order.state.get("events",[]).size()==2,"rescue reaches base and leaves echoes")
			order.advance(0.5)
		"su":
			order.press()
			check(order.state.burn_left==4 and order.state.cooldown==(300 if timer_max else 600),"global exposure starts on click")
			order.advance(4.1)
			check(dummy.hp<before and not order.state.has("burn_left") and not order.ready_to_act(),"burn ends while superweapon cooldown continues")
		"mara":
			order.press()
			check(order.aiming and order.is_processing() and order.instruction.visible,"beacon targeting preview")
			var default_heading:Vector2=order.aim_heading(stage_origin)
			order_button(stage_origin,MOUSE_BUTTON_LEFT,true)
			order_button(stage_origin+Vector2.ONE,MOUSE_BUTTON_LEFT,false)
			check(order.state.events.size()==2 and Vector2(order.state.events[0].heading).is_equal_approx(default_heading),"short beacon click follows original approach")
			order.state.clear()
			order.press()
			order_button(stage_origin,MOUSE_BUTTON_LEFT,true)
			order_click(stage_origin,MOUSE_BUTTON_RIGHT)
			order_button(stage_origin,MOUSE_BUTTON_LEFT,false)
			check(not order.aiming and order.state.is_empty(),"cancel held beacon without spending cooldown")
			order.press()
			order_button(stage_origin,MOUSE_BUTTON_LEFT,true)
			var heading:=default_heading.orthogonal()
			var cursor:=stage_origin+heading*220.0
			var motion:=InputEventMouseMotion.new()
			motion.button_mask=MOUSE_BUTTON_MASK_LEFT
			motion.position=battle.get_canvas_transform()*cursor
			order._input(motion)
			check(order.aim_anchor.is_equal_approx(stage_origin) and order.aim_heading(stage_origin).is_equal_approx(heading) and order.state.is_empty(),"held beacon rotates preview around fixed center before spending")
			order_button(cursor,MOUSE_BUTTON_LEFT,false)
			var flight:Dictionary=order.state.events[0]
			check(not order.aiming and order.state.events.size()==2 and order.state.cooldown==(300 if timer_max else 600) and flight.at.is_equal_approx(stage_origin) and flight.heading.is_equal_approx(heading),"release launches both flights along the preview")
			check(flight.heading == -order.state.events[1].heading,"return flight reverses chosen heading")
			var old_dummy:Vector2=dummy.position
			dummy.position=order.beacon_drop(stage_origin,heading,0)
			order.advance(0.9)
			check(dummy.hp==before,"aircraft approaches before first impact")
			order.advance(0.4)
			check(dummy.hp<before,"first impact reaches the rotated first circle")
			order.advance(3)
			dummy.position=old_dummy
		"nadya":
			dummy._cd_timer=0.0
			var old_position: Vector2 = second.position
			second.position = Vector2.ONE * (battle.map_size - 80)
			second._cd_timer = 0
			var second_hp: float = second.hp
			order.button.pressed.emit()
			check(not order.aiming and dummy._cd_timer>=5 and second._cd_timer>=5,"clock button delays enemies map-wide")
			order.advance(5.1)
			check(dummy.hp<before and second.hp<second_hp,"clock strikes both ends of map")
			second.position = old_position
		"qiao":
			battle.selected_units=[]
			order.press()
			var at := stage_origin - Vector2(105,0)
			var route:Dictionary = order.ruler_route(at)
			check(order.aiming and order.instruction.visible and route.end.x > stage_origin.x,"tank previews forward lane without selection")
			order_button(at, MOUSE_BUTTON_LEFT, true)
			order_click(at, MOUSE_BUTTON_RIGHT)
			order_button(at, MOUSE_BUTTON_LEFT, false)
			check(not order.aiming and not order.aim_anchor.is_finite() and not order.state.has("cooldown"),"right-click cancels held tank without casting on release")
			order.press()
			order_button(at, MOUSE_BUTTON_LEFT, true)
			battle.cancel_pointer_gestures()
			order_button(at, MOUSE_BUTTON_LEFT, false)
			check(not order.aiming and not order.state.has("events"),"interrupted hold never casts")
			order.press()
			order_button(at, MOUSE_BUTTON_LEFT, true)
			order_button(at + Vector2(1,1), MOUSE_BUTTON_LEFT, false)
			check(Vector2(order.state.events[0].end).is_equal_approx(route.end),"short click keeps the original direction")
			order.state.clear()
			var old_cycle:int = Expedition.state.cycle
			Expedition.state.cycle=3
			order.button.pressed.emit()
			order_button(at, MOUSE_BUTTON_LEFT, true)
			var cursor := at + Vector2.DOWN * 200.0
			var motion := InputEventMouseMotion.new()
			motion.position = battle.get_canvas_transform() * cursor
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			order._input(motion)
			var preview:Dictionary = order.ruler_route(order.aim_anchor)
			check(order.aim_anchor.is_equal_approx(at) and Vector2(preview.heading).is_equal_approx(Vector2.DOWN) and not order.state.has("events") and not order.state.has("cooldown"),"drag locks landing point and rotates preview without spending")
			var edge_route:Dictionary = order.ruler_route(Vector2(100, battle.map_size - 10))
			check(Vector2(edge_route.end).is_equal_approx(Vector2(100, battle.map_size)),"rotated route clips to map edge")
			order_button(cursor, MOUSE_BUTTON_LEFT, false)
			var drop:Dictionary = order.state.events[0]
			check(order.state.has("cooldown") and drop.width==120 and Vector2(drop.at).is_equal_approx(at) and Vector2(drop.end).is_equal_approx(preview.end) and Vector2(drop.heading).is_equal_approx(preview.heading),"cycle three tank uses preview landing, heading and width")
			var old_dummy: Vector2 = dummy.position
			var old_second: Vector2 = second.position
			var second_hp: float = second.hp
			dummy.position = at + Vector2.DOWN * 135.0
			second.position = at + Vector2.RIGHT * 350.0
			order.advance(0.3)
			check(dummy.hp==before,"no damage while airborne")
			order.advance(0.65)
			var after:float=dummy.hp
			order.advance(2)
			check(after<before and dummy.hp==after and second.hp==second_hp and not order.state.has("events"),"tank sweeps dragged lane once, misses default lane and departs")
			dummy.position = old_dummy
			second.position = old_second
			Expedition.state.cycle=old_cycle
		"greta":
			troops.TNKD._cd_timer=4.0
			troops.HTNK.special.expedition_mission_unit=true
			order.press()
			check(troops.TNKD._cd_timer==2.0 and troops.TNKD.buff_value("west_shift")==0.5 and troops.GGI.buff_value("west_shift")==0.0,"global ten-second vehicle reload")
			troops.TNKD._tick_buffs(10)
			check(troops.TNKD.buff_value("west_shift")==0,"shift ends after ten seconds")
			troops.HTNK.special.erase("expedition_mission_unit")
			order.state.clear()
			order.press()
			check(troops.TNKD._cd_timer==0.0,"joint shift completes current reload")
		"seojin":
			order.press()
			order_click(stage_origin)
			check(order.state.events.size()==4 and dummy.hp==before,"four incoming bombers")
			order.advance(1.5)
			var first_hp:float=dummy.hp
			order.advance(2)
			check(first_hp<before and dummy.hp<first_hp and not order.state.has("events"),"four timed bombing passes conclude")
		"yusuf":
			var miners: Array = battle.units.filter(func(u): return order.available(u) and u.is_harvester)
			for unit in miners: unit.special.expedition_mission_unit = true
			var funds: float = battle.funds_for("ally")
			order.button.pressed.emit()
			check(not order.aiming and battle.funds_for("ally")-funds==5000 and order.state.cooldown==(300 if timer_max else 600), "zero miners: one press credits base freight")
			order.button.pressed.emit()
			check(battle.funds_for("ally")-funds==5000,"cooldown prevents duplicate freight")
			order.advance(order.state.cooldown)
			for unit in miners: unit.special.erase("expedition_mission_unit")
			var fee := 2*(5000+1000*miners.size())
			funds=battle.funds_for("ally")
			order.button.pressed.emit()
			check(battle.funds_for("ally")-funds==fee and order.state.cooldown==(120 if timer_max else 240),"joint freight doubles base and all miner bonuses")
			order.advance(60 if timer_max else 120)
			check(order.button.text==("签收运费\n1:00" if timer_max else "签收运费\n2:00") and order.get_child(-1).get_child(0).text=="+%d" % fee,"freight receipt and countdown")
			check(order.charge_mask.visible and order.charge_mask.value==0.5,"joint freight mask")
		"edith":
			battle.fog=stage_fog
			var point:=Vector2.ONE*float(battle.map_size)*0.5
			var original:Vector2=dummy.position
			dummy.position=point
			troops.SNIPE.special.expedition_mission_unit=true
			check(order.fire_at(point) and dummy.special.has("reed_watch"),"enemy marked at cast")
			var cell: Vector2 = Vector2.ONE * stage_fog.CELL
			var dark := Vector2.ZERO
			stage_fog.rebuild()
			for x in range(3, stage_fog.width - 3):
				var candidate := Vector2(x, 3) * cell
				if not stage_fog.is_visible_at("ally", candidate) and not stage_fog.is_visible_at("ally", candidate + cell) and not stage_fog.is_visible_at("ally", candidate + Vector2.RIGHT * cell.x):
					dark = candidate
					break
			check(dark != Vector2.ZERO, "isolated watch test cells")
			dummy.position = dark
			stage_fog.rebuild()
			check(stage_fog.is_visible_at("ally", dark) and not stage_fog.is_visible_at("ally", dark + Vector2.RIGHT * cell.x), "watch lights only occupied cell")
			dummy.position += cell
			stage_fog.rebuild()
			check(stage_fog.is_visible_at("ally", dark + cell) and not stage_fog.is_visible_at("ally", dark) and stage_fog.is_explored_at("ally", dark), "watch sight moves and leaves exploration")
			dummy.position=original
			order.advance(29.9)
			check(battle.actor_visible_to("ally",dummy) and dummy.special.has("reed_watch"),"mark follows moving enemy")
			order.advance(0.11)
			check(not dummy.special.has("reed_watch"),"mark expires")
			dummy.position = dark + cell
			stage_fog.rebuild()
			check(not stage_fog.is_visible_at("ally", dummy.position), "expired watch loses cell sight")
			order.state.clear()
			troops.SNIPE.special.erase("expedition_mission_unit")
			dummy.position=point
			check(order.fire_at(point) and stage_fog.is_visible_at("ally",point+Vector2(470,0)),"joint watch reveals outer ring")
			dummy.position=original
			battle.fog=null
		"sami":
			var medic=troops.SENGINEER
			var patient=troops.DESO
			var spot := Vector2(400,400)
			var sounds := Ra2Sfx.a_plays
			check(GameData.ra2_sound_files("HealCrate")==["gcraheal.wav"],"aid uses the original HealCrate sound")
			order.button.pressed.emit()
			order_click(Vector2(-1,-1))
			order_click(spot,MOUSE_BUTTON_RIGHT)
			check(not order.aiming and order.ready_to_act() and Ra2Sfx.a_plays==sounds,"invalid click and cancel preserve aid and stay silent")
			order.button.pressed.emit()
			order_click(Vector2.ZERO)
			check(not order.aiming and order.state.get("cooldown")==(300 if timer_max else 600) and Ra2Sfx.a_plays==sounds+1,"empty ground consumes aid and plays one confirmation")
			order.advance(600)
			patient.position=spot
			patient.hp=patient.max_hp
			check(order.aid_targets(spot).is_empty(),"full troops have no preview ring")
			order.button.pressed.emit()
			order_click(spot)
			check(patient.hp==patient.max_hp and order.state.get("cooldown")==(300 if timer_max else 600) and Ra2Sfx.a_plays==sounds+2,"full-health area accepts aid and plays once")
			check(not MetaProgress.contact_transcripts.sami.has("joint_record"),"empty or full-health casts do not inscribe a joint rescue")
			order.advance(600)
			patient.hp=patient.max_hp*0.30
			patient.position=spot+Vector2(261,0)
			check(not order.aid_targets(spot).has(patient),"injured troop just outside circle excluded")
			patient.position-=Vector2.RIGHT
			patient.special.hero_wreck=true
			check(not order.aid_targets(spot).has(patient),"healing-locked units have no ring")
			patient.special.erase("hero_wreck")
			medic.special.expedition_mission_unit=true
			check(order.aid_targets(spot)==[patient],"eligible injured unit on radius 260 marked")
			order.button.pressed.emit()
			order_click(spot)
			check(not order.aiming and is_equal_approx(patient.hp,patient.max_hp*0.50) and Ra2Sfx.a_plays==sounds+3,"ordinary aid restores twenty percent with one sound")
			check(not MetaProgress.contact_transcripts.sami.has("joint_record"),"ordinary aid does not grant joint record")
			order.advance(600)
			medic.special.erase("expedition_mission_unit")
			medic.position=spot
			medic.hp=medic.max_hp*0.8
			dummy.position=spot
			check(order.aid_targets(spot).size()==2 and not order.aid_targets(spot).has(dummy),"only both injured allies marked")
			check(order.fire_at(spot) and is_equal_approx(patient.hp,patient.max_hp*0.90) and medic.hp==medic.max_hp and dummy.hp==before and Ra2Sfx.a_plays==sounds+4,"joint aid heals both allies up to max with one sound")
			dummy.position=stage_origin
		"ines":
			order.press()
			check(order.aiming and order.is_processing(),"mirror preview follows cursor before committing")
			order.press()
			check(not order.aiming and not order.is_processing() and not order.state.has("cooldown"),"cancel clears preview without spending")
			check(order.fire_at(stage_origin) and dummy.special.has("keepsake_photo"),"mirror tags target")
			order.advance(1.1)
			check(dummy.hp<before,"mirror ambush resolves")
	check(order.state.has("cooldown") and not order.fire_at(stage_origin),"cooldown blocks a second activation "+kind)

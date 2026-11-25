extends Node

var checks:Array=[]
var failed:=0
var stage:SubViewport
var camp:Control
var output_dir:=""

func check(ok:bool,title:String,details:Variant=null) -> void:
	checks.append({"name":title,"passed":ok,"details":details})
	if not ok:
		failed+=1
		print("FAIL ",title," ",details)

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	stage=SubViewport.new();stage.size=Vector2i(1600,900);add_child(stage)
	for country in ["美国","苏俄"]:
		Expedition.state={}
		camp=load("res://scenes/expedition.tscn").instantiate();stage.add_child(camp)
		camp.country_changed(0 if country=="美国" else 1)
		await inspect_sizes(country+" opening")
		var opening:Dictionary=camp.opening.duplicate(true)
		check(Expedition.start(country,"",12345,opening),country+" start")
		camp.build()
		preload("res://tests/expedition_attention_cases.gd").lobby(self,true)
		check(Expedition.load_run(),country+" pending reward reload")
		camp.build()
		await inspect_sizes(country+" rewards")
		camp.request_item("reward",0,Expedition.reward_token())
		check(Expedition.state.phase=="ready",country+" initial reward UI selected")
		var next:Dictionary=Expedition.state.duplicate(true)
		next.stage=2;next.phase="reward";next.reward_round="main"
		next.relics.choice_compass=true
		next.offers=preload("res://scripts/expedition/market.gd").rewards(next)
		check(Expedition.commit(next),country+" prepare post-battle reward UI")
		camp.build()
		check(Expedition.state.offers.size()==4,country+" compass main reward has four choices")
		await inspect_sizes(country+" compass four main choices")
		var token:=Expedition.reward_token()
		camp.request_item("reward",0,token)
		check(Expedition.state.phase=="reward" and Expedition.state.reward_round=="buff",country+" original reward UI opens bonus round")
		check(Expedition.state.offers.size()==4,country+" compass extra reward has four choices")
		var bonus:Dictionary=Expedition.state.duplicate(true)
		camp.request_item("reward",0,token)
		check(Expedition.state==bonus,country+" stale UI callback does not claim bonus")
		await inspect_sizes(country+" extra Buff choices")
		camp.request_item("reward",0,Expedition.reward_token())
		check(Expedition.state.phase=="event",country+" bonus UI opens event")
		await inspect_sizes(country+" post-battle event")
		var event_token:=Expedition.event_token()
		camp.event_choice(0,event_token)
		check(Expedition.state.phase=="ready",country+" event UI opens camp")
		var event_claimed:Dictionary=Expedition.state.duplicate(true)
		camp.event_choice(0,event_token)
		check(Expedition.state==event_claimed,country+" stale event UI callback cannot repeat reward")
		# Final chapter shows five choices with compass and three separately claimable bonus pages.
		next=Expedition.state.duplicate(true);next.stage=26;next.phase="reward";next.reward_round="main"
		next.offers=preload("res://scripts/expedition/market.gd").rewards(next)
		Expedition.commit(next);camp.build()
		for reward_page in 4:
			check(Expedition.state.phase=="reward" and Expedition.state.offers.size()==5,country+" late five-choice page "+str(reward_page))
			await inspect_sizes(country+" late five choices "+str(reward_page))
			var late_token:=Expedition.reward_token()
			camp.request_item("reward",0,late_token)
			var late_claimed:Dictionary=Expedition.state.duplicate(true)
			camp.request_item("reward",0,late_token)
			check(Expedition.state==late_claimed,country+" stale late UI callback cannot skip next round "+str(reward_page))
		check(Expedition.state.phase=="event",country+" third bonus UI finally opens event")
		camp.event_choice(0,Expedition.event_token())
		check(Expedition.state.phase=="ready",country+" late event reaches sixth chapter camp")
		Expedition.commit(event_claimed);camp.build()
		check(Expedition.service("relic"),country+" buy manual for real UI")
		next=Expedition.state.duplicate(true)
		for id:String in preload("res://scripts/expedition/relics.gd").ITEMS:next.relics[id]=true
		check(Expedition.commit(next),country+" load full relic collection for layout")
		next=Expedition.state.duplicate(true);next.stage=13;next.supplies=500
		for id:String in preload("res://scripts/expedition/catalog.gd").BUFFS:next.buffs[id]=1
		Expedition.open_event(next);Expedition.commit(next)
		camp.build()
		await inspect_sizes(country+" post-battle event with full equipment collection")
		check(not Expedition.resolve_event(0,event_token),country+" previous-stage event token rejected")
		camp.event_choice(0,Expedition.event_token())
		check(Expedition.state.buffs.size()==24 and Expedition.state.supplies==560,country+" UI event preserves unlimited equipment collection")
		for tab in 4:
			camp.change_tab(tab)
			await inspect_sizes(country+" tab "+str(tab))
		var unit_id:String=camp.opening.keys()[0]
		var balance:int=Expedition.state.supplies
		camp.upgrade_unit(unit_id,0)
		check(Expedition.state.supplies==balance and not preload("res://scripts/expedition/growth.gd").free_available(Expedition.state),country+" real UI claims one free upgrade")
		var grown:Dictionary=Expedition.state.duplicate(true)
		camp.upgrade_unit(unit_id,0)
		check(Expedition.state==grown,country+" old free UI action cannot charge paid price")
		preload("res://tests/expedition_attention_cases.gd").lifecycle(self)
		await preload("res://tests/expedition_scroll_cases.gd").run(self)
		await preload("res://tests/expedition_shop_card_cases.gd").run(self)
		await preload("res://tests/expedition_trait_card_cases.gd").run(self)
		# Exercise the longer explanations both before and after a real specialization choice.
		next=Expedition.state.duplicate(true);next.stage=16;next.supplies=1000
		var specialist:String="E1" if country=="美国" else "DESO"
		next.survivors=[];next.reinforcements=[];next.special_squads=[];next.active_roster=[]
		preload("res://scripts/expedition/army.gd").add_unit(next,specialist,1)
		next.native_talents[specialist]=3;next.specializations.erase(specialist)
		Expedition.grant(next,{"kind":"special_unit","id":specialist,"tier":2,"native_rank":1,"count":1})
		Expedition.commit(next);camp.change_tab(2)
		await inspect_sizes(country+" specialization options and same-unit promotion explanation")
		camp.request_native(specialist,"a")
		check(Expedition.state.specializations.get(specialist,"")=="a" and Expedition.state.supplies==800,country+" explained specialization still selects actual branch once")
		await inspect_sizes(country+" chosen specialization keeps its explanation")
		camp.free()
		await get_tree().process_frame
	stage.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPEDITION LAYOUT checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func inspect_sizes(context:String) -> void:
	preload("res://tests/expedition_attention_cases.gd").inspect(self)
	var state:Dictionary=Expedition.state.duplicate(true)
	var opening:Dictionary=camp.opening.duplicate(true)
	# Resize the same live controls in both directions, without rebuilding the page.
	for dimensions in [Vector2i(800,600),Vector2i(1024,768),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160),Vector2i(1024,768)]:
		stage.size=dimensions
		await settle()
		var prefix:=context+" "+str(dimensions)
		var scroll:ScrollContainer=camp.body.get_parent()
		check(not scroll.get_h_scroll_bar().visible,prefix+" no horizontal scroll")
		check(camp.body.size.x<=scroll.size.x,prefix+" body fits viewport",str(camp.body.size))
		inspect_controls(camp.body,prefix,scroll.get_global_rect())
		preload("res://tests/expedition_trait_card_cases.gd").inspect(self,prefix)
		var header:Control=camp.body.get_child(0)
		check(header.find_children("AttentionDot","",true,false).is_empty(),prefix+" no floating reminder in title or return-to-lobby header")
		if Expedition.state.get("phase","")=="ready" and camp.tab==1:
			var shop_title:Label
			var refresh:Button
			for child in camp.body.get_children():
				if child is Label and child.text.begins_with("军需商店 ·"):shop_title=child
				if child is Button and child.text.begins_with("刷新 ·"):refresh=child
			check(shop_title!=null and refresh!=null,prefix+" shop title and refresh share vertical body")
			if shop_title!=null and refresh!=null:
				check(refresh.get_index()==shop_title.get_index()+1 and refresh.position.y>=shop_title.position.y+shop_title.size.y,prefix+" refresh immediately below shop title")
				check(absf(refresh.position.x-shop_title.position.x)<1 and refresh.size.x<300,prefix+" refresh is left aligned and compact")
		var tail:Control=camp.body.get_child(camp.body.get_child_count()-1)
		scroll.scroll_vertical=100000
		await settle()
		check(scroll.get_global_rect().encloses(tail.get_global_rect()),prefix+" final action reachable",str(tail.get_global_rect()))
		scroll.scroll_vertical=0
		await settle()
	check(Expedition.state==state and camp.opening==opening,context+" resizing preserves selections and run")

func inspect_controls(node:Node,prefix:String,bounds:Rect2) -> void:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree():
			var rect:Rect2=child.get_global_rect()
			check(rect.position.x>=bounds.position.x-1 and rect.end.x<=bounds.end.x+1,prefix+" contained "+str(child.get_path()),str(rect))
		if child is Label and node is HBoxContainer:
			var required_width:float=child.get_minimum_size().x if child.autowrap_mode==TextServer.AUTOWRAP_OFF else 150.0
			check(child.size.x>=required_width and child.get_line_count()<=3,prefix+" readable title "+child.text,str(child.size))
		if child is UnitIcon:
			check(child.size.y<=80,prefix+" compact unit portrait",str(child.size))
		if child is GridContainer:
			check(child.columns<=2 if stage.size.x<=1024 else child.columns>=2,prefix+" responsive columns",child.columns)
		inspect_controls(child,prefix,bounds)

func settle() -> void:
	for frame in 12:await get_tree().process_frame

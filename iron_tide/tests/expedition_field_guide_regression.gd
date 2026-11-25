extends "res://tests/expedition_regression.gd"

const Guide=preload("res://scripts/expedition/field_guide.gd")

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	MetaProgress.yuriko_school={}
	var main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var menu_book=open_from(main)
	if menu_book:
		for frame in 3:await get_tree().process_frame
		var list:ItemList=menu_book.find_children("*","ItemList",true,false)[0]
		var instructions:ScrollContainer=menu_book.find_children("*","ScrollContainer",true,false).filter(func(s):return s.is_visible_in_tree())[0]
		check(list.size.y>100 and instructions.size.x>200 and instructions.size.y>100,"mission index and reading pane have usable space")
		var names:Dictionary=Guide.Missions.BASIC_NAMES.merged(Guide.Missions.NAMES)
		check(list.item_count==names.size(),"all battle side missions have guide entries")
		for i in list.item_count:
			var id:String=list.get_item_metadata(i)
			list.select(i)
			list.item_selected.emit(i)
			if id=="contact":
				for person:Dictionary in Guide.Contacts.PEOPLE.values():
					if person.has("permit"):check(has_text(menu_book,str(person.name).get_slice(" · ",0)+"　→　"+str(GameData.get_unit(person.permit).name)),"permit directory "+person.country)
			var action:String=Guide.Missions.Assign.BOOK[id][2] if Guide.Missions.Assign.BOOK.has(id) else Guide.GUIDE[id][1]
			check(list.get_item_text(i)==names[id] and has_text(menu_book,action),"select mission and read its instructions "+id)
		var tabs:TabContainer=menu_book.find_children("*","TabContainer",true,false)[0]
		tabs.current_tab=2
		var picker: ItemList = tabs.get_tab_control(2).find_children("*", "ItemList", true, false)[0]
		check(picker.item_count == MetaProgress.Academy.HEROES.size()+1, "all heroes have stories")
		for i in picker.item_count:
			picker.select(i)
			picker.item_selected.emit(i)
			var id: String = Guide.HeroStories.BOOK.keys()[i]
			if id=="YURIKO":
				var story:Dictionary=Guide.HeroStories.BOOK[id]
				check(has_text(menu_book,"港口手记") and not has_text(menu_book,story.clue) and not has_text(menu_book,story.story),"sealed Yuriko letter")
				MetaProgress.yuriko_school={"read":{"letter":1}}
				picker.item_selected.emit(i)
				check(has_text(menu_book,story.clue) and has_text(menu_book,story.story),"open Yuriko letter and mission after finale")
				MetaProgress.yuriko_school={}
				continue
			check(has_text(menu_book, Guide.HeroStories.BOOK[id].story), "read hero story " + id)
			var hero_page := tabs.get_tab_control(2)
			check(has_text(hero_page, "同行档案 1/19") and has_text(hero_page, Guide.HeroStories.BOOK[id].title), "opening and archive progress " + id)
			if id in ["MTNK", "HTNK", "ORCA", "TTNK", "FV", "HARV"]:
				check(has_text(hero_page, "驾驶员头像") and not Guide.Portraits.choose_driver(id, true), "driver portrait requires an earned chapter " + id)
			var recruit: FoldableContainer = hero_page.find_children("*", "FoldableContainer", true, false)[0]
			check(recruit.folded and recruit.title == "招募条件与行动", "recruitment starts collapsed " + id)
			toggle_section(recruit)
			check(has_text(recruit, Guide.HeroStories.BOOK[id].clue) and has_text(recruit, "从下一关起随队增援"), "read recruitment instructions " + id)
		var first_infantry:=Guide.HeroStories.BOOK.keys().find("E1")
		picker.select(first_infantry)
		picker.item_selected.emit(first_infantry)
		var restored: FoldableContainer = tabs.get_tab_control(2).find_children("*", "FoldableContainer", true, false)[0]
		check(not restored.folded and has_text(restored, Guide.HeroStories.BOOK.E1.clue), "hero recruitment expansion survives switching heroes")
		tabs.current_tab=1
		check(has_text(menu_book,"暂无已解锁档案"),"empty archive state")
		for id:String in Guide.Stories.PEOPLE:
			var cards:Array=menu_book.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with(Guide.Stories.PEOPLE[id].name))
			check(cards.is_empty(),"unknown commander hidden "+id)
		check(tabs.get_tab_control(1).find_children("*","FoldableContainer",true,false).is_empty(),"no locked commander entries created")
		check(not has_text(menu_book,Guide.Stories.PEOPLE.lin.chapters.visor.lines[0]),"closed profiles collapse their transcripts")
		menu_book.find_children("*","Button",true,false).filter(func(b):return b.text=="返回主菜单")[0].pressed.emit()
		await get_tree().process_frame
		check(not is_instance_valid(menu_book) and main.visible,"closing returns to the original menu")
	main.free()
	var vera:Dictionary=Guide.Stories.PEOPLE.vera
	MetaProgress.contact_archive={"vera":{"torch":{"run":"guide-fixture","stage":14}}}
	MetaProgress.contact_transcripts={"vera":{"rescued":true,"bio":[vera.bio],"rescue":[vera.rescue],
		"promise":["约定第 14 关："+vera.promise,"约定第 17 关："+vera.promise]}}
	var camp=load("res://scenes/expedition.tscn").instantiate()
	add_child(camp)
	var camp_book=open_from(camp)
	if camp_book:
		var tabs:TabContainer=camp_book.find_children("*","TabContainer",true,false)[0]
		tabs.current_tab=1
		var readers: ItemList = tabs.get_tab_control(1).find_children("*", "ItemList", true, false)[0]
		check(readers.item_count==1,"archive can be opened before starting a run")
		if readers.item_count==1:
			readers.item_selected.emit(0)
			check(readers.get_item_text(0)==vera.name and has_text(camp_book,"档案解锁 4/23"),"three rescue communications and one story count once each")
			var sections:Array=tabs.get_tab_control(1).find_children("*","FoldableContainer",true,false)
			check(sections.size()==4,"only four earned sections exist")
			for section:FoldableContainer in sections:
				check(section.folded,"starts collapsed")
				toggle_section(section)
			check(not has_text(camp_book,vera.arrival),"locked communication absent")
			check(has_text(camp_book,vera.chapters.torch.lines[1]),"unlocked chapter can be reread in the encyclopedia")
			check(not sections.any(func(s):return s.title=="《第二条线》"),"locked chapter title absent")
			toggle_section(sections[0])
			readers.item_selected.emit(0)
			sections = tabs.get_tab_control(1).find_children("*","FoldableContainer",true,false)
			check(sections[0].folded and not sections[1].folded, "each commander entry retains its last state when rebuilt")
	camp.free()
	check_complete_archives()
	check_hero_commissions()
	check_hero_chronicles()
	check_chronicle_routes()
	new_ready("美国",6)
	check(Expedition.launch(0),"launch battle")
	if instantiate_battle():
		var rt=screen.expedition_runtime
		var buttons=screen.hud.expedition_panel.find_children("*","Button",true,false)
		check(not buttons.any(func(b):return b.text=="支线百科"),"battle panel has no encyclopedia shortcut")
		check(buttons.any(func(b):return b.text=="定位目标" and b.is_visible_in_tree() and b.pressed.is_connected(rt.tasks.focus_next)),"main objective shortcut remains available")
		check(buttons.any(func(b):return b.text=="定位支线" and b.is_visible_in_tree() and b.pressed.is_connected(rt.field_ops.focus_next)),"side objective shortcut remains available")
		var ops = rt.field_ops
		var leads: Array = ops.data.objectives.filter(func(o):return o.has("hero_lead"))
		if not leads.is_empty():
			var lead: Dictionary = leads[0]
			check(ops.summary().contains(Guide.HeroStories.BOOK[lead.hero_lead].clue),"battle displays assigned hero clue")
			if lead.kind == "contact":ops.complete(lead)
			else:lead.done=true;lead.phase="station"
			check(Expedition.settle(battle,true),"commit victory with hero commission")
			check(Expedition.load_run() and lead.hero_lead in Expedition.state.heroes,"hero retained after reload")
			var plan: Array = preload("res://scripts/expedition/reinforcement_plan.gd").build(Expedition.state)
			check(plan.any(func(r):return r.get("hero","")==lead.hero_lead),"hero enters next reinforcement plan")
		else:check(false,"fixture deploys a hero lead")
		await finish()
	await check_chronicle_battle(false)
	await check_chronicle_battle(true)
	print("FIELD GUIDE checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check_complete_archives() -> void:
	var previous_archive:=MetaProgress.contact_archive
	var previous_transcripts:=MetaProgress.contact_transcripts
	var previous_state:=Expedition.state
	MetaProgress.contact_archive={}
	MetaProgress.contact_transcripts={}
	Expedition.state={"cycle":5}
	for id:String in Guide.Stories.PEOPLE:
		var profile:Dictionary=Guide.Stories.PEOPLE[id]
		var receipts:={}
		for key:String in profile.chapters:
			receipts[key]={"run":"guide-fixture","stage":14}
		MetaProgress.contact_archive[id]=receipts
		var records:={"rescued":true,"keepsake":{},"keepsake_upgrades":[{},{},{},{}],"joint_record":{"date":"2026-11-23","stage":14}}
		for kind:String in ["bio","promise","rescue","arrival"]:
			check(not profile[kind].is_empty(),"authored "+kind+" for "+id)
			records[kind]=[profile[kind]]
		MetaProgress.contact_transcripts[id]=records
	var pages:=VBoxContainer.new()
	Guide.add_archive(pages)
	add_child(pages)
	var groups:=pages.find_children("*","Button",false,false)
	check(groups.size()==1,"completed commanders share a single row")
	var cards:=pages.find_children("*","Button",true,false).filter(func(b):return not groups.has(b))
	if groups.size()==1:
		check(not groups[0].button_pressed and cards.all(func(b):return not b.is_visible_in_tree()),"completed cards start hidden")
		groups[0].button_pressed=true
		check(cards.all(func(b):return b.is_visible_in_tree()),"expanding the row reveals completed commanders")
	check(cards.size()==Guide.Stories.PEOPLE.size(),"one full archive per commander")
	for card:Button in cards:
		var sections:=card.get_parent().get_child(card.get_index()+1).find_children("*","FoldableContainer",false,false)
		check(card.text.ends_with("档案解锁 23/23") and sections.size()==23,"all twenty-three entries can be reread for "+card.text.get_slice("\n",0))
	pages.free()
	MetaProgress.contact_archive=previous_archive
	MetaProgress.contact_transcripts=previous_transcripts
	Expedition.state=previous_state

func open_from(host:Node):
	var buttons:=host.find_children("*","Button",true,false).filter(func(b):return b.text=="支线百科" and b.is_visible_in_tree())
	check(buttons.size()==1,"visible encyclopedia entry in "+host.name)
	if buttons.is_empty():return null
	buttons[0].pressed.emit()
	for dialog in host.get_parent().get_children():
		if dialog is Guide and dialog.visible and not host.visible:return dialog
	check(false,"encyclopedia opens")
	return null

func toggle_section(section: FoldableContainer) -> void:
	section.grab_focus()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.pressed = pressed
		section.get_viewport().push_input(event, true)

func has_text(book:Control,fragment:String) -> bool:
	return book.find_children("*","Label",true,false).any(func(l):return l.is_visible_in_tree() and l.text.contains(fragment))

func check_hero_commissions() -> void:
	var stories = Guide.HeroStories
	for id: String in MetaProgress.Academy.HEROES:
		check(stories.BOOK.has(id), "authored commission for " + id)
		var country := "美国" if GameData.get_unit(id).faction == "allied" else "苏俄"
		var run := {"country":country,"stage":8,"heroes":[]}
		var objective := {"kind": stories.BOOK[id].kind,"done":false}
		stories.assign(run,[objective])
		check(objective.get("hero_lead","")==id,"commission assigned to " + id)
		var report := {}
		stories.settle(run,[objective],report)
		check(run.heroes.is_empty(),"pending commission earns no recruit")
		objective.done=true
		objective.failed=true
		stories.settle(run,[objective],report)
		check(run.heroes.is_empty(),"failed commission earns no recruit")
		objective.failed=false
		if objective.kind=="fuel":
			objective.phase="scrap"
			stories.settle(run,[objective],report)
			check(run.heroes.is_empty(),"scrapping tanker excludes hero")
			objective.phase="station"
		stories.settle(run,[objective],report)
		stories.settle(run,[objective],report)
		check(run.heroes==[id] and report.get("field_heroes",[])==[id],"recruit once " + id)
	var duo := {"country":"美国","stage":8,"heroes":["MTNK"]}
	var report := {}
	stories.settle(duo,[{"kind":"contact","hero_lead":"E1","done":true}],report)
	check(report.has("hero_reunion") and stories.candidate(duo,"radio")=="TANY","two heroes can find Tanya's lead")
	stories.settle(duo,[{"kind":"radio","hero_lead":"TANY","done":true}],report)
	check(duo.heroes==["MTNK","E1","TANY"] and stories.Heroes.valid(duo),"third hero joins a valid expedition roster")

func check_hero_chronicles() -> void:
	var stories = Guide.HeroStories
	var previous := MetaProgress.hero_story_archive
	MetaProgress.hero_story_archive = {}
	var book := Guide.new()
	for id: String in MetaProgress.Academy.HEROES:
		var run := {"heroes":[id], "stage":8, "cycle":1}
		var chapters: Array = stories.chronicles[id].chapters
		var gates := [1,1,2,2,3,3,4,5]
		check(chapters.size() == gates.size(), "eight chapters " + id)
		var kinds := {}
		for i in chapters.size():
			var chapter: Dictionary = chapters[i]
			var mark := {"hero":id, "chapter":i+1}
			var objective := {"kind":chapter.kind, "done":true, "phase":"station"}
			var report := {}
			kinds[chapter.kind] = true
			run.cycle = int(chapter.cycle) - 1
			stories.assign(run, [objective])
			check(not objective.has("hero_chronicle") and int(chapter.cycle) == gates[i], "future chapter withheld %s/%d" % [id,i+1])
			run.cycle += 1
			run.wounded_heroes = [id]
			stories.assign(run, [objective])
			check(not objective.has("hero_chronicle"), "wounded hero receives no lead")
			run.wounded_heroes = []
			stories.assign(run, [objective])
			check(objective.get("hero_chronicle", {}) == mark and stories.chapter_hint(mark).contains(chapter.clue), "assigned chapter %s/%d" % [id,i+1])
			objective.done = false
			stories.settle(run, [objective], report)
			objective.done = true
			objective.failed = true
			stories.settle(run, [objective], report)
			objective.failed = false
			if chapter.kind == "fuel":
				objective.phase = "scrap"
				stories.settle(run, [objective], report)
				objective.phase = "station"
			check(report.is_empty(), "incomplete, failed and scrapped objectives earn nothing")
			stories.settle(run, [objective], report)
			stories.settle(run, [objective], report)
			var portrait_rewards: Array = [id] if i == 0 and id in ["MTNK", "HTNK", "ORCA", "TTNK", "FV", "HARV"] else []
			check(report.get("driver_portrait_rewards", []) == portrait_rewards, "first earned chapter awards vehicle pilot once %s/%d" % [id,i+1])
			check(report.get("hero_chronicles", []) == [mark] and run.get("hero_story_archive", {}).get(id, {}).size() == i+1, "earned only once %s/%d" % [id,i+1])
		check(kinds.size()==5, "five different battle objectives "+id)
		check(not Guide.Portraits.driver_unlocked(id), "pending run does not unlock portrait " + id)
		check(stories.deliver(run), "publish chapters before portrait selection " + id)
		var scroll := ScrollContainer.new()
		var pages := VBoxContainer.new()
		scroll.add_child(pages)
		book.show_hero_story(0, [id], pages)
		var switcher := pages.get_node_or_null("SwitchHeroPortrait") as Button
		if id in ["MTNK", "HTNK", "ORCA", "TTNK", "FV", "HARV"]:
			var portrait: TextureRect = pages.find_children("*", "TextureRect", true, false)[0]
			var vehicle := portrait.texture
			check(switcher != null and vehicle.resource_path == Guide.Portraits.PATHS[id], "earned portrait is optional " + id)
			if switcher:
				switcher.pressed.emit()
				MetaProgress.driver_portraits.clear()
				MetaProgress.load_save()
				var hud := UnitIcon.new()
				hud.set_hero(id)
				check(Guide.Portraits.showing_driver(id) and portrait.texture.resource_path.ends_with("-driver.png") and portrait.texture == hud.cameo_texture, "story and HUD use saved driver " + id)
				switcher.pressed.emit()
				hud.set_hero(id)
				var original_hud := vehicle.resource_path.get_basename() + "-unit.png" if id in ["FV","HARV"] else vehicle.resource_path
				check(portrait.texture == vehicle and hud.cameo_texture.resource_path == original_hud and MetaProgress.driver_portraits.is_empty(), "switch back to original vehicle " + id)
				hud.free()
		else:
			check(switcher == null, "infantry has no driver option " + id)
		var sections := pages.find_children("*", "FoldableContainer", false, false)
		var texts := []
		for section: FoldableContainer in sections:
			if section.title != "招募条件与行动":
				texts.append(section.get_child(0).text)
		var expected := []
		for chapter: Dictionary in chapters:
			expected.append(chapter.text)
			for extra: String in ["artifact","letter"]:
				if chapter.has(extra):expected.append(chapter[extra])
		check(texts == expected and texts.size()==18 and pages.find_children("*","Label",true,false).any(func(label):return label.text.ends_with("19/19")), "full archive and actual texts "+id)
		scroll.free()
	book.free()
	MetaProgress.hero_story_archive = previous
	var missed := {"kind":"contact"}
	stories.assign({"heroes":["E1"],"stage":6,"cycle":5}, [missed])
	check(missed.get("hero_chronicle", {}) == {"hero":"E1","chapter":1}, "fifth cycle offers missed first-cycle story")

func check_chronicle_routes() -> void:
	var field = preload("res://scripts/expedition/field_operations.gd")
	for cycle in range(1,6):
		var seen := {}
		for seed_value in range(1,17):
			for stage in range(5,30):
				var run := {"cycle":cycle,"seed":seed_value,"stage":stage,"history":[]}
				for route: Dictionary in Campaign.routes(run):
					var kind := Guide.Missions.candidate(seed_value,stage,route,cycle)
					var arrival: int = field.available_arrival(stage,[])
					var slots := Guide.Missions.Assign.slots(arrival)
					if 0 in slots:seen.contact = true
					if 1 in slots:seen[kind if not kind.is_empty() else ("cache" if stage%2==0 else "intel")] = true
			if seen.has_all(["contact","intel","radio","box","fuel"]):break
		check(seen.has_all(["contact","intel","radio","box","fuel"]), "all story mission kinds offered by generated routes in cycle "+str(cycle),seen)

func check_chronicle_battle(win: bool) -> void:
	new_ready("美国",6)
	var next := Expedition.state.duplicate(true)
	next.heroes = ["E1"]
	check(Expedition.commit(next) and Expedition.launch(0), "launch with recruited storyteller")
	if not instantiate_battle():return
	var ops = screen.expedition_runtime.field_ops
	var leads: Array = ops.data.objectives.filter(func(o):return o.has("hero_chronicle"))
	check(leads.size()==1 and leads[0].kind=="contact", "one personal lead on the real rescue objective")
	if not leads.is_empty():
		var lead: Dictionary = leads[0]
		var chapter := Guide.HeroStories.chapter_for(lead.hero_chronicle)
		check(ops.summary().contains(chapter.clue), "personal clue displayed in battle")
		check(Expedition.checkpoint(battle) and Expedition.load_run() and Expedition.prepare_battle(), "resume personal lead from checkpoint")
		await finish()
		if not instantiate_battle():return
		ops = screen.expedition_runtime.field_ops
		var restored: Array = ops.data.objectives.filter(func(o):return o.get("hero_chronicle",{})==lead.hero_chronicle)
		check(restored.size()==1, "restored battle still carries assigned chapter")
		if not restored.is_empty():
			ops.complete(restored[0])
			check(Expedition.settle(battle,win), "commit result with completed personal lead")
			var count: int = Expedition.state.battle_reports[-1].get("hero_chronicles",[]).size()
			check(count==int(win), "only victory reports the story")
			MetaProgress.load_save()
			check(MetaProgress.hero_story_archive.get("E1",{}).has("1")==win, "only victory reaches disk archive")
			if win:
				MetaProgress.hero_story_archive.erase("E1")
				check(MetaProgress.save() and Expedition.load_run(), "retry unpublished archive from committed run")
				MetaProgress.load_save()
				check(MetaProgress.hero_story_archive.get("E1",{}).get("1",{}).get("stage",0)==6, "retry restores the earned chapter to disk")
	await finish()

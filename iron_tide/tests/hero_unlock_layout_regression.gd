extends Node
const Page=preload("res://scripts/ui/hero_progression.gd")
const Contracts=preload("res://scripts/rules/expansion_contracts.gd")
var checks:Array=[]
var failed:=0

func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failed+=1;push_error(label)

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	MetaProgress.reset_save()
	MetaProgress.academy.hero_builds={"TANY":4,"BORIS":0}
	MetaProgress.academy.hero_contracts={}
	var viewport:=SubViewport.new();viewport.size=Vector2i(540,900);add_child(viewport)
	var page:=Page.new();page.size=Vector2(540,900);viewport.add_child(page);page.open_page()
	check(page.hero_buttons.size()==MetaProgress.Academy.HEROES.size() and not page.picker.visible,"all heroes have visible flat selectors")
	for id:String in MetaProgress.Academy.HEROES:
		page.hero_buttons[id].pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		check_model_links(page.progress_label,id)
	for id:String in ["TANY","BORIS","ORCA","TTNK"]:
		page.hero_buttons[id].pressed.emit()
		await get_tree().process_frame;await get_tree().process_frame
		check(page.selected==id and page.hero_buttons[id].button_pressed,"flat selector opens correct hero "+id)
		var button:Button=page.hero_buttons[id]
		check(button.is_visible_in_tree() and button.get_global_rect().end.x<=540,"hero selector fits narrow page "+id)
		check(not button.text.contains("谭雅 · 谭雅"),"hero name is not duplicated "+id)
		check(page.progress_label.get_global_rect().end.y<=page.expansion_contract.global_position.y,"unlock condition precedes skill contract "+id)
		check(page.progress_label.get_global_rect().end.x<=540,"unlock condition wraps within page "+id)
		if id in ["TANY","BORIS"]:
			check(page.progress_label.text.contains(" / 5") and page.progress_label.text.contains("下一局"),"production threshold and next-match timing are explicit "+id)
		else:check(page.progress_label.text.contains("额外赠送") and page.progress_label.text.contains(" / 5") and page.progress_label.text.contains("下一局"),"gift explains permanent prerequisite and next-match activation "+id)
		for i in 3:
			var row:Label=page.expansion_contract.find_child("ContractTask_"+str(i),true,false)
			check(row!=null and row.is_visible_in_tree() and row.text.begins_with("○"),"unowned task is directly readable "+id+str(i))
			check(row.get_global_rect().end.x<=540 and row.get_visible_line_count()==row.get_line_count(),"task wraps without truncation "+id+str(i))
			var toggle:Button=page.expansion_contract.find_child("ContractDemoToggle",true,false)
			check(row.get_global_rect().end.y<toggle.global_position.y,"tasks appear before optional demonstration "+id+str(i))
		check(page.expansion_contract.find_child("HeroContractDemo",true,false)==null,"reading tasks requires no animated illustration "+id)
		MetaProgress.academy.hero_contracts[id]={"first":Contracts.GOALS[id][0],"second":1,"win":false,"complete":false}
		page.refresh()
		check(page.expansion_contract.find_child("ContractTask_0",true,false).text.begins_with("✓"),"completed task has checkmark "+id)
		check(page.expansion_contract.find_child("ContractTask_1",true,false).text.begins_with("○"),"incomplete task retains pending marker "+id)
		check(page.expansion_contract.find_child("ContractTask_2",true,false).text.ends_with("0 / 1"),"victory requirement has explicit progress "+id)
	MetaProgress.academy.hero_builds.TANY=5
	page.open_page();page.hero_buttons.TANY.pressed.emit()
	check(page.hero_buttons.TANY.text.contains("已解锁") and page.progress_label.text.begins_with("已解锁"),"unlock label refreshes from actual production count")
	viewport.free();await get_tree().process_frame
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)

func check_model_links(line:RichTextLabel,hero:String) -> void:
	var hits:Dictionary={}
	for y in range(3,int(line.size.y),6):
		for x in range(2,int(line.size.x),8):
			var id:=line.get_tooltip(Vector2(x,y))
			if not id.is_empty():hits[id]=true
	check(hits.has(hero) and line.get_parsed_text().contains(GameData.get_unit(hero).name),"production name is a hover target "+hero)
	if hero=="ORCA":
		check(hits.size()==3 and hits.has_all(["SHAD","ORCA","BEAG"]),"only the three qualifying aircraft are shown")
	else:check(hits.size()==1,"only the counted product offers a model "+hero)
	for id:String in hits:
		var tip:Control=line._make_custom_tooltip(id)
		add_child(tip)
		var model=tip.find_children("*","TextureRect",true,false)[0]
		check(model.actor.unit_id==id and not model.actor.special.has("academy_hero"),"hover shows the production model "+id)
		tip.free()

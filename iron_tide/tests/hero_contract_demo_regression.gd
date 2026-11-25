extends Node
const Demo=preload("res://scripts/ui/hero_contract_demo.gd")
const Q=preload("res://scripts/rules/expansion_contracts.gd")
var checks:Array=[]
var failed:=0

func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failed+=1;push_error(label)

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	var before:=MetaProgress.to_dict().duplicate(true)
	var had_save:=FileAccess.file_exists(MetaProgress.SAVE_PATH)
	var save_bytes:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH) if had_save else PackedByteArray()
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,1000);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo:=Demo.new();demo.size=Vector2(540,550);viewport.add_child(demo)
	for id:String in ["TANY","BORIS","ORCA","TTNK"]:
		demo.show_hero(id);demo.playing=false
		var images:Array=[]
		for t:float in [0,2,4,5,7,8.9,9,9.5,10,11,12,15,16,18,20,22,23.9,24,24.5,26,27,28,30.9]:
			demo.playback.user_seek(t)
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			var sample:=Demo.sample(id,t)
			check(not demo.playing and demo.status.text==sample.phase,"seek pauses on actual caption "+id+str(t))
			check(demo.reward.text.contains("两张卡均未装备") and demo.reward.text.contains("%d 次"%sample.grants),"reward count and unequipped state visible "+id+str(t))
			for label:Label in [demo.status,demo.condition,demo.reward,demo.rows[0],demo.rows[1]]:
				check(label.size.x<=540 and label.get_visible_line_count()>=label.get_line_count(),"wrapped visible label fits "+id+str(t)+label.text.split("\n")[0])
			var digest:=viewport.get_texture().get_image().get_data().hex_encode().sha256_text()
			if not digest in images:images.append(digest)
		check(images.size()>10,"actual rendered task and transfer phases differ "+id)
		var before_settle:=Demo.sample(id,7)
		check(before_settle.saved_first==Q.GOALS[id][0]-2 and before_settle.first==2 and not before_settle.win,"in-match first task does not change settled total "+id)
		check(before_settle.second==(200 if id=="TTNK" else 2) and before_settle.saved_second==Q.GOALS[id][1]-before_settle.second,"second task uses health loss or event count without premature settlement "+id)
		for t:float in [9,11,12,15]:
			var sample:=Demo.sample(id,t)
			check(sample.saved_first==Q.GOALS[id][0] and sample.saved_second==Q.GOALS[id][1] and not sample.complete and sample.grants==0,"loss and replay cap cumulative tasks but do not grant victory rewards "+id+str(t))
		check(Demo.sample(id,22).criterion==Demo.LABELS[id][3] and not Demo.sample(id,22).win,"all four distinct in-match criteria still await victory "+id)
		for t:float in [24,27,28,30.9]:
			var sample:=Demo.sample(id,t)
			check(sample.complete and sample.win and sample.grants==1,"victory reward survives restore and duplicate without second grant "+id+str(t))
		demo.playback.seek(31);check(demo.elapsed>30.9 and demo.reward.text.contains("已解锁"),"final frame remains completed "+id)
		demo.playback.user_seek(0);check(demo.reward.text.contains("待解锁") and Demo.sample(id,0).grants==0,"rewinding only resets illustration "+id)
	demo.free()
	var panel=preload("res://scripts/ui/expansion_contract_panel.gd").new();panel.size=Vector2(650,900);viewport.add_child(panel)
	for id:String in ["TANY","BORIS","ORCA","TTNK","MTNK"]:
		panel.refresh(id)
		var toggle:Button=panel.find_child("ContractDemoToggle",true,false)
		if id=="MTNK":check(toggle==null,"older hero not assigned four-hero task illustration");continue
		check(toggle!=null and not toggle.disabled and panel.find_child("HeroContractDemo",true,false)==null,"unowned contract exposes lazy task preview "+id)
		toggle.button_pressed=true;await get_tree().process_frame
		var child=panel.find_child("HeroContractDemo",true,false)
		check(child!=null and child.hero_id==id and child.is_processing(),"actual contract panel opens correct task preview "+id)
		toggle.button_pressed=false;await get_tree().process_frame
		check(not child.is_processing(),"collapsed task preview does not tick "+id)
		toggle.button_pressed=true
		check(panel.find_child("HeroContractDemo",true,false)==child,"reopen does not duplicate task preview "+id)
	check(MetaProgress.to_dict()==before,"all preview routes preserve complete persistent profile")
	check(FileAccess.file_exists(MetaProgress.SAVE_PATH)==had_save and (not had_save or FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==save_bytes),"preview never creates or changes save bytes")
	viewport.free();await get_tree().process_frame
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)

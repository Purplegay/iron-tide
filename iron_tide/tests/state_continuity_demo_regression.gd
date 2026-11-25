extends Node
const Demo=preload("res://scripts/ui/state_continuity_demo.gd")
var checks:Array=[]
var failed:=0
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failed+=1;push_error(label)

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	var before:=MetaProgress.to_dict().duplicate(true)
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,600);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://tests/state_continuity_text_probe.gd").new();demo.size=Vector2(540,500);viewport.add_child(demo)
	for index in Demo.CASES.size():
		demo.scenario.select(index);demo.playing=false
		for t:float in [.1,1.1,2.,2.19,2.41,3.01,4.01,5.9]:
			demo.playback.user_seek(t);await get_tree().process_frame;await RenderingServer.frame_post_draw
			check(not demo.playing and not demo.drawn_text.is_empty(),"scenario draws at paused cursor "+str(index)+"/"+str(t))
			for row in demo.drawn_text:
				var extent:=ThemeDB.fallback_font.get_string_size(row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
				var right:=270 if row.at.x<270 else 540
				check(row.at.x+extent.x<=right and row.at.y+ThemeDB.fallback_font.get_descent(14)<=175,"saved and restored labels stay inside their half "+str(index)+row.text)
			check(demo.details.get_visible_line_count()>=demo.details.get_line_count(),"continuity explanation wraps without hidden lines "+str(index))
		check(Demo.state(index,0).value==Demo.state(index,2).value,"restore starts at identical saved value "+str(index))
	check(Demo.state(0,3.99).completed==0 and Demo.state(0,4.01).completed==1,"saved bomb waits its remaining two seconds")
	check(Demo.state(1,3.1).value==2 and Demo.state(1,4.1).value==0,"restored wing retires original groups without creating replacements")
	check(Demo.state(2,2.39).completed==0 and Demo.state(2,2.41).completed==1,"95 percent of baseline eight-second refill completes after remaining 0.4 seconds")
	check(Demo.state(3,2.19).completed==0 and Demo.state(3,2.21).completed==1,"court exposure restores partial 0.3 seconds")
	check(Demo.state(4,3.1).value==1 and Demo.state(4,4.1).value==0,"remaining two volleys consumed without regranting three")
	check(Demo.state(5,2.51).completed==1 and Demo.state(6,5.9).value==0,"current leap finishes while automatic toggle remains off")
	check(Demo.state(7,5.9).value==1 and Demo.state(7,5.9).completed==1,"forked child completes once without grandchildren")
	check(Demo.state(8,3.1).value==4 and Demo.state(9,5.9).value==100,"spent missile shield and single power contribution persist")
	check(Demo.state(10,2.99).completed==0 and Demo.state(10,3.01).completed==1,"179-second wreck resumes final second only")
	demo.free()
	var page=preload("res://scripts/ui/hero_progression.gd").new();page.size=Vector2(650,600);viewport.add_child(page)
	var toggle:Button=page.find_child("ContinuityDemoToggle",true,false)
	check(toggle!=null and page.find_child("StateContinuityDemo",true,false)==null,"real hero page lazily exposes continuity gallery")
	toggle.button_pressed=true;await get_tree().process_frame
	var child=page.find_child("StateContinuityDemo",true,false)
	check(child!=null and child.scenario.item_count==11 and child.is_processing(),"actual gallery button exposes all eleven states")
	toggle.button_pressed=false;await get_tree().process_frame
	check(not child.is_processing(),"hidden gallery stops drawing and advancing")
	check(MetaProgress.to_dict()==before,"gallery does not change persistent game progress")
	viewport.free();await get_tree().process_frame
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)

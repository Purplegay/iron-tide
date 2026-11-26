extends Node
const Book=preload("res://scripts/units/yuriko_school.gd")
const Psi=preload("res://scripts/units/yuriko.gd")
const Stories=preload("res://scripts/expedition/hero_field_stories.gd")
var checks:=0
var failures:=0

func check(ok:bool,reason:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL ",reason)

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	call_deferred("run")

func click(root:Node,prefix:String) -> bool:
	for b in root.find_children("*","Button",true,false):
		if b.text.begins_with(prefix) and not b.disabled:
			b.pressed.emit()
			return true
	return false

func navigation_rects(view) -> Dictionary:
	var rects := {}
	for item:Button in view.stage.find_children("*","Button",true,false):
		if item.text in view.VIEW_NAMES or item.text=="CG 集":
			rects[item.text]=item.get_global_rect()
	return rects

var observed_speakers:Dictionary={}
const EXPECTED_CAST:={
	"小满":["小满","xiaoman"], "陈姨":["陈姨","chen"],
	"修车阿姨":["路人丙","passerby_c"], "老师":["路人丙","passerby_c"], "家政老师":["路人丙","passerby_c"],
	"店主":["路人甲","passerby_a"], "体育老师":["路人甲","passerby_a"], "鱼摊叔叔":["路人甲","passerby_a"],
	"图书委员":["路人丁","passerby_d"], "园艺委员":["路人乙","passerby_b"], "部长":["路人乙","passerby_b"],
}

func check_speaker(view,ep:Dictionary) -> void:
	var cursor:=Book.cursor(ep)
	var speaker:String=ep.get("choice_speaker","百合子") if Book.choosing(ep) else Book.lines(ep,int(cursor.answer))[int(cursor.step)].get_slice("｜",0)
	var portrait:TextureRect=view.stage.find_child("SpeakerPortrait",true,false)
	var caption:Label=view.stage.find_child("SpeakerName",true,false)
	if speaker=="旁白":
		check(caption.text=="旁白" and portrait==null and not view.actor_layer.visible and view.actor_layer.texture==null,"narration clears both portraits")
	elif speaker in ["指挥官","男人"]:
		check(caption.text=="潮声" and portrait==null and not view.actor_layer.visible and view.actor_layer.texture==null,"player name only, including before the reunion")
	elif speaker=="百合子":
		check(caption.text==speaker and portrait!=null and portrait.texture==view.story_portraits[ep.portrait] and view.actor_layer.visible and view.actor_layer.texture==portrait.texture,"Yuriko speaks in current story outfit")
	else:
		var spec:Array=EXPECTED_CAST.get(speaker,[])
		var valid:=not spec.is_empty() and portrait!=null and portrait.texture!=null
		if valid:
			var expected:String=spec[0]+" · "+speaker if str(spec[0]).begins_with("路人") else speaker
			valid=caption.text==expected and portrait.texture.resource_path.get_file()==str(spec[1])+".webp" and view.actor_layer.visible and view.actor_layer.texture==portrait.texture and portrait.texture.get_width()==1024
		check(valid,"speaker identity: "+speaker)
		if valid:observed_speakers[speaker]=true

func finish(view,ep:Dictionary,answer:int) -> void:
	var n:=0
	while not view.current.is_empty() and n<30:
		check_speaker(view,ep)
		if Book.choosing(ep):
			check(click(view.stage,ep.choices[answer].text),"click choice "+ep.id)
		else:
			check(click(view.stage,"下一句") or click(view.stage,"记入手记"),"click dialogue "+ep.id)
		n+=1
	check(n<30 and MetaProgress.yuriko_school.read.has(ep.id),"finish "+ep.id)

func check_turns(view) -> void:
	var body:Node3D=view.model.body
	var camera:Camera3D=view.model.get_camera_3d()
	# Track a point on the side facing the camera in display coordinates.
	var front:=body.to_local(body.global_position+Vector3(0,10,3))
	var start:=camera.unproject_position(body.to_global(front)).x
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	view.photo.gui_input.emit(press)
	var motion:=InputEventMouseMotion.new()
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	motion.relative=Vector2(24,0)
	view.photo.gui_input.emit(motion)
	check(camera.unproject_position(body.to_global(front)).x>start+1,"drag right moves near side right")
	motion.relative=Vector2(-48,0)
	view.photo.gui_input.emit(motion)
	var left:=camera.unproject_position(body.to_global(front)).x
	check(left<start-1,"drag left moves near side left")
	press.pressed=false
	view.photo.gui_input.emit(press)
	motion.button_mask=0
	view.photo.gui_input.emit(motion)
	check(is_equal_approx(camera.unproject_position(body.to_global(front)).x,left),"release stops drag")
	check(click(view.stage,"向右转") and camera.unproject_position(body.to_global(front)).x>start,"right button follows right drag")
	check(click(view.stage,"向左转") and is_equal_approx(camera.unproject_position(body.to_global(front)).x,left),"left button reverses right turn")

func check_motion_frame(view) -> void:
	var selector:OptionButton=view.stage.find_children("*","OptionButton",true,false)[0]
	var camera:Camera3D=view.model.get_camera_3d()
	var rig:Skeleton3D=view.model.rig
	view.adjust_zoom(1.0)
	for motion in [1,2]:
		selector.select(motion)
		selector.item_selected.emit(motion)
		var inside:=true
		for step in 120:
			view.rotate_model(TAU/120)
			view._process(1.0/30.0)
			for bone in rig.get_bone_count():
				var point:=camera.unproject_position(rig.to_global(rig.get_bone_global_pose(bone).origin))
				inside=inside and Rect2(16,16,992,992).has_point(point)
		check(inside,"animated joints stay inside frame at closest zoom: %d/%d"%[view.model.outfit,motion])
	view.adjust_zoom(-0.6)

func check_gift_shop(view) -> void:
	var bonds=preload("res://scripts/units/yuriko_bonds.gd")
	var day:=Time.get_date_string_from_system()
	var price:int=bonds.gift_price("uniform",day)
	MetaProgress.currency.cores=price-1
	view.hub(0)
	var journal_rect:Rect2=view.stage.get_node("HubPortrait").get_global_rect()
	var journal_texture:Texture2D=view.stage.get_node("HubPortrait").texture_normal
	for section:String in ["手记", "私信与礼物"]:
		check(click(view.stage,section) and click(view.stage,"好感手记"),"open affinity archive via "+section)
		var archive_portrait:TextureButton=view.stage.get_node_or_null("HubPortrait")
		check(archive_portrait!=null and archive_portrait.is_visible_in_tree() and journal_texture!=null and archive_portrait.texture_normal==journal_texture and archive_portrait.get_global_rect().is_equal_approx(journal_rect),"affinity archive shows selected portrait via "+section)
	check(click(view.stage,"私信与礼物"),"open correspondence after archive")
	check(view.stage.get_node("GiftPortrait").get_global_rect().is_equal_approx(journal_rect),"gift portrait matches journal portrait bounds")
	var gift_texture:Texture2D=view.stage.get_node("GiftPortrait").texture
	check(click(view.stage,"回看赠礼回应"),"open gift replies")
	var reply_portrait:TextureRect=view.stage.get_node_or_null("GiftPortrait")
	check(reply_portrait!=null and reply_portrait.is_visible_in_tree() and gift_texture!=null and reply_portrait.texture==gift_texture and reply_portrait.get_global_rect().is_equal_approx(journal_rect),"reply page keeps visible equipped gift portrait and bounds")
	check(click(view.stage,"返回私信与礼物"),"return from gift replies")
	check(view.buy_buttons.uniform.disabled and not bonds.buy_gift("uniform",day).is_empty(),"insufficient funds block button and purchase")
	MetaProgress.currency.cores=price+0.5
	view.refresh_gift_shop()
	check(view.buy_buttons.uniform.icon!=null and view.buy_buttons.uniform.text.contains(str(price)) and not view.buy_buttons.uniform.disabled,"button quotes today's payable resource and exact price")
	check(not bonds.buy_gift("uniform","1999-01-01").is_empty() and MetaProgress.balance("cores")==price+0.5,"stale day cannot debit new price")
	view.shop_day="1999-01-01"
	view.buy_buttons.uniform.pressed.emit()
	check(view.buy_buttons.uniform.text.contains("加价" if price>500 else "降价"),"quote labels the direction of the actual charge")
	check(view.shop_day==day and view.message.text.contains("已更新") and MetaProgress.balance("cores")==price+0.5,"midnight click refreshes a stale screen without charging")
	var tmp:=ProjectSettings.globalize_path(MetaProgress.SAVE_PATH+".tmp")
	if DirAccess.make_dir_absolute(tmp)==OK:
		check(not bonds.buy_gift("uniform",day).is_empty() and MetaProgress.balance("cores")==price+0.5 and MetaProgress.yuriko_school.get("gifts",{}).is_empty(),"failed save rolls back inventory and balance")
		DirAccess.remove_absolute(tmp)
	else:check(false,"prepare isolated write failure")
	view.buy_buttons.uniform.pressed.emit()
	check(MetaProgress.balance("cores")==0.5 and view.buy_buttons.uniform.disabled and not view.give_buttons.uniform.disabled,"buy one gift at exact price, keeping fractional funds")
	MetaProgress.load_save()
	check(MetaProgress.yuriko_school.gifts.uniform==1 and MetaProgress.balance("cores")==0.5 and Book.affinity_level()==0 and not Book.outfit_unlocked(1),"purchase persists independently of giving and wardrobe")
	check(not bonds.give("uniform").is_empty() and not Book.outfit_unlocked(1),"gifting uniform cannot bypass chapter lock")
	for id:String in ["cola","ticket"]:
		var cost:int=bonds.gift_price(id,day)
		MetaProgress.currency.cores=cost
		view.hub(4)
		view.buy_buttons[id].pressed.emit()
		check(MetaProgress.balance("cores")==0 and MetaProgress.yuriko_school.gifts.get(id,0)==1,"reopening preserves daily quote and adds correct item "+id)
	check(MetaProgress.yuriko_school.get("fragments",{}).is_empty(),"shop purchases grant no expedition fragments")
	var discounted:Dictionary={}
	var marked_up:Dictionary={}
	var independent:=false
	var valid:=true
	var expected_labels:={350:"350 战略核心（降价 30%）",501:"501 战略核心（加价 0.2%）",750:"750 战略核心（加价 50%）"}
	var tested_prices:Dictionary={}
	for i in 366:
		var date_:=Time.get_date_string_from_unix_time(1704067200+i*86400)
		var distinct:Dictionary={}
		for id:String in bonds.GIFTS:
			var value:int=bonds.gift_price(id,date_)
			valid=valid and value>=350 and value<=750 and value!=500 and value==bonds.gift_price(id,date_)
			if expected_labels.has(value) and not tested_prices.has(value):
				view.refresh_gift_shop(date_)
				check(view.buy_buttons[id].text.contains(expected_labels[value]),"live shop displays the correct price and percentage "+str(value))
				tested_prices[value]=true
			distinct[value]=true
			if value<500:discounted[id]=true
			else:marked_up[id]=true
		if distinct.size()==3:independent=true
	check(valid and independent and discounted.size()==3 and marked_up.size()==3 and tested_prices.size()==expected_labels.size(),"each gift has stable daily discounts and premiums")
	var prices:Array[int]=[]
	for ticket in 100:prices.append(bonds.price_from_roll(ticket))
	check(prices.filter(func(p):return p<500).size()==5 and prices.filter(func(p):return p>500).size()==95,"daily draw assigns exactly 95 premium outcomes and 5 discount outcomes")
	check(prices.min()==350 and prices.max()==750 and prices.reduce(func(a,b):return a+b,0)==50000,"daily draw endpoints and exact mean of 500")
	view.refresh_gift_shop()
	check(click(view.stage,"免费刷新礼物价格") and MetaProgress.balance("cores")==0,"free reroll at zero balance")
	check(view.reroll_button.disabled and not bonds.reroll_gifts(day,1).is_empty(),"insufficient funds block paid reroll")
	MetaProgress.currency.cores=2000.5
	view.refresh_gift_shop()
	var expected_balance:=2000.5
	for fee:int in [10,10,20,20,20,30,30,30,50,50,50,50,50,50,100,100]:
		expected_balance-=fee
		check(view.reroll_button.icon!=null and click(view.stage,"刷新礼物价格　%d 战略核心"%fee) and MetaProgress.balance("cores")==expected_balance,"display and charge reroll fee "+str(fee))
	MetaProgress.load_save()
	check(bonds.refresh_count(day)==17 and bonds.refresh_count("1999-01-01")==0 and MetaProgress.balance("cores")==expected_balance,"daily reroll count and balance persist")
	check(not bonds.buy_gift("cola",day,0).is_empty(),"reject old quote after reroll")
	view.hub(0)

func check_player_name() -> void:
	# This runner uses a private profile and process-local environment.
	for key:String in ["USERNAME","USER","LOGNAME"]:OS.unset_environment(key)
	check(MetaProgress.set_commander_alias("") and MetaProgress.commander_name().is_empty(),"no nickname or OS account available")
	var menu=get_tree().current_scene
	get_tree().reload_current_scene()
	await get_tree().scene_changed
	menu=get_tree().current_scene
	check(menu.find_child("SettingsButton",true,false).has_node("UpgradeDot"),"unnamed player gets settings red dot")
	OS.set_environment("USERNAME","TestWindows")
	OS.set_environment("LOGNAME","TestMacLogin")
	check(MetaProgress.system_login("Windows")=="TestWindows" and MetaProgress.system_login("macOS")=="TestMacLogin","Windows account and macOS login fallback")
	OS.set_environment("USER","TestMac")
	check(MetaProgress.system_login("macOS")=="TestMac","macOS account lookup prefers USER")
	check(click(menu,"设 置"),"open naming from settings entry")
	await get_tree().scene_changed
	var settings=get_tree().current_scene
	var edit:LineEdit=settings.find_child("CommanderNameInput",true,false)
	check(edit.text=="" and edit.placeholder_text.contains(MetaProgress.system_login()),"settings exposes system default")
	edit.text=" 潮声 "
	check(click(settings,"保存名字"),"save a custom name")
	MetaProgress.commander_alias=""
	MetaProgress.load_save()
	check(MetaProgress.commander_name()=="潮声","custom name is trimmed and survives reload")
	edit.text="  "
	edit.text_submitted.emit(edit.text)
	MetaProgress.load_save()
	check(MetaProgress.commander_alias.is_empty() and MetaProgress.commander_name()==MetaProgress.system_login(),"clearing and confirming restores system login")
	click(settings,"返 回 主 菜 单")
	await get_tree().scene_changed
	check(get_tree().current_scene.find_child("SettingsButton",true,false).has_node("UpgradeDot")==MetaProgress.system_login().is_empty(),"settings dot follows resolved system login")
	click(get_tree().current_scene,"设 置")
	await get_tree().scene_changed
	settings=get_tree().current_scene
	edit=settings.find_child("CommanderNameInput",true,false)
	edit.text="潮声"
	edit.text_submitted.emit(edit.text)
	click(settings,"返 回 主 菜 单")
	await get_tree().scene_changed
	check(not get_tree().current_scene.find_child("SettingsButton",true,false).has_node("UpgradeDot"),"saved name clears settings dot")

func check_wedding_cg(view) -> void:
	var original:=MetaProgress.yuriko_school.duplicate(true)
	var wallet:=MetaProgress.currency.duplicate(true)
	var gallery=preload("res://scripts/screens/yuriko_cg.gd")
	MetaProgress.currency.diamonds=100000
	for candidate in [{"affinity":19,"read":{"desk":0}},{"affinity":20,"read":{}}]:
		MetaProgress.yuriko_school.affinity=candidate.affinity
		MetaProgress.yuriko_school.read=candidate.read
		view.hub(8)
		check(not click(view.stage,"收藏整组") and Book.buy_wedding_cg()==Book.WEDDING_HEAD_REQUIREMENT and MetaProgress.balance("diamonds")==100000 and not Book.owns_wedding_cg(),"both head milestones required before gallery purchase")
	MetaProgress.yuriko_school.read={"desk":0}
	MetaProgress.yuriko_school.journal_head=false
	check(Book.journal_head_unlocked() and not Book.wear(Book.WEDDING_OUTFIT),"head alone does not grant wedding outfit")
	MetaProgress.currency.diamonds=99999
	view.hub(0)
	check(click(view.stage,"CG 集"),"gallery opens from journal")
	var cover:TextureRect=view.stage.get_node_or_null("CGArt")
	check(cover!=null and cover.texture!=null and cover.texture.get_size()==Vector2(1536,1024),"full-body cover available before purchase")
	var buy:Button
	for b:Button in view.stage.find_children("*","Button",true,false):
		if b.text.begins_with("收藏整组"):buy=b
	check(buy!=null and buy.disabled and buy.icon!=null and buy.text.contains("100000"),"gallery quotes diamond cost and disables when one short")
	gallery.show_page(view,1,0,true)
	check(view.tab==8 and not click(view.stage,"返回剧情") and not Book.buy_wedding_cg().is_empty() and MetaProgress.balance("diamonds")==99999,"full-screen access and purchase guarded")
	MetaProgress.currency.diamonds=100000
	var tmp:=ProjectSettings.globalize_path(MetaProgress.SAVE_PATH+".tmp")
	if DirAccess.make_dir_absolute(tmp)==OK:
		check(not Book.buy_wedding_cg().is_empty() and not Book.owns_wedding_cg() and MetaProgress.balance("diamonds")==100000,"save failure rolls back both album and wallet")
		DirAccess.remove_absolute(tmp)
	else:check(false,"prepare isolated CG save failure")
	view.hub(8)
	check(click(view.stage,"收藏整组") and Book.owns_wedding_cg() and MetaProgress.balance("diamonds")==0,"one purchase grants set at exact price")
	MetaProgress.yuriko_school={}
	MetaProgress.load_save()
	check(Book.owns_wedding_cg() and MetaProgress.balance("diamonds")==0 and Book.buy_wedding_cg().is_empty(),"both grants and debit survive reload without repeat payment")
	check(Book.wear(Book.WEDDING_OUTFIT),"album grants wearable outfit after reload")
	view.hub(3)
	check(click(view.stage,"头部外观"),"open head catalog")
	check(view.model.journal_head and view.model.body.find_child("YurikoUnitHead",true,false)!=null and not click(view.stage,"原版头型"),"wedding forces AI head without altering ordinary outfit preference")
	var garment:MeshInstance3D=view.model.body.find_child("YurikoBody",true,false)
	check(garment.mesh.get_surface_count()==3 and garment.get_node(garment.skeleton)==view.model.rig and view.model.rig.get_bone_count()==36,"bridal mesh bound to the moving unit rig")
	check(Book.wear(0) and not Book.journal_head_equipped(),"returning to ordinary outfit restores preferred head")
	view.hub(8)
	click(view.stage,"重温 · 等你看够")
	var next_rect:=Rect2()
	for scene:Dictionary in gallery.story.scenes:
		for i in scene.pages.size():
			var image:TextureRect=view.stage.get_node_or_null("CGArt")
			check(image!=null and image.texture!=null and image.texture.resource_path.ends_with(scene.art+".webp") and image.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"real illustrated page "+str(scene.art))
			await get_tree().process_frame
			await get_tree().process_frame
			for key:Button in view.stage.find_children("*","Button",true,false):
				if key.text in ["下一页","下一幕"]:
					if next_rect.size==Vector2.ZERO:next_rect=key.get_global_rect()
					check(next_rect.is_equal_approx(key.get_global_rect()),"fixed forward button on every page")
			var words:bool=false
			for item:Label in view.stage.find_children("*","Label",true,false):
				if item.text==scene.pages[i][1]:words=true
			check(words,"authored POV story is visible")
			if i==0:
				check(click(view.stage,"全屏赏图") and view.stage.get_node("CGArt").anchor_right==1 and click(view.stage,"返回剧情"),"full art and return to same page")
			if i+1<scene.pages.size():check(click(view.stage,"下一页"),"turn CG page")
			elif scene==gallery.story.scenes.front():check(click(view.stage,"下一幕"),"continue to second CG")
	check(click(view.stage,"返回 CG 集") and click(view.stage,"重温 · 留一只手") and click(view.stage,"返回 CG 集"),"replay unlocked second scene from collection")
	MetaProgress.currency=wallet
	check(view.stage.get_node("CGArt").texture.resource_path.ends_with("tram.webp"),"gallery remembers second illustration")
	MetaProgress.yuriko_school={}
	MetaProgress.load_save()
	view.hub(8)
	check(view.stage.get_node("CGArt").texture.resource_path.ends_with("tram.webp"),"last illustration survives reload")
	check(click(view.stage,"重温 · 等你看够") and click(view.stage,"返回 CG 集") and view.stage.get_node("CGArt").texture.resource_path.ends_with("platform.webp"),"revisiting first illustration updates gallery")
	MetaProgress.currency=wallet
	check(Book.commit(original),"restore isolated CG fixture")
	view.hub(3)

func check_head_wardrobe(view) -> void:
	var previous:=MetaProgress.yuriko_school.duplicate(true)
	var progress:=previous.duplicate(true)
	progress.affinity=20
	progress.pages=8
	progress.gm_open=true
	progress.journal_head=true
	check(Book.commit(progress),"load high-affinity profile without completed chapter")
	view.hub(3)
	check(click(view.stage,"头部外观"),"open head catalog")
	check(not click(view.stage,"手记头型") and not Book.wear_journal_head(true) and not view.model.journal_head,"available pages, GM story access and stale preference cannot unlock head")
	progress=progress.duplicate(true)
	progress.erase("gm_open")
	progress.erase("journal_head")
	progress.read={"desk":0}
	progress.affinity=19
	progress.gifts={"cola":1}
	progress.given={"cola":1}
	check(Book.commit(progress),"load completed chapter below threshold")
	view.hub(3)
	check(click(view.stage,"头部外观"),"open head catalog")
	check(not click(view.stage,"手记头型") and view.model.body.scene_file_path.contains("/classic/"),"chapter alone uses retail body")
	view.present("cola")
	check(Book.affinity_level()==20 and view.message.text.contains("已解锁手记头型"),"repeat gift unlocks at level 20 after reading chapter five")
	view.hub(3)
	check(click(view.stage,"头部外观"),"open head catalog")
	check(not view.model.journal_head and click(view.stage,"手记头型") and view.model.journal_head,"optional head equips from wardrobe")
	check(click(view.stage,"衣装　"),"open outfit catalog" )
	for skin_index in [0,1]:
		check(click(view.stage,Psi.SKINS[skin_index]) and view.model.body.find_child("YurikoUnitHead",true,false)!=null,"journal head follows outfit")
	MetaProgress.yuriko_school={}
	MetaProgress.load_save()
	check(Book.journal_head_equipped(),"equipped head survives profile reload")
	view.show_demo()
	var preview=view.get_child(-1)
	check(preview.model.body.find_child("YurikoUnitHead",true,false)!=null,"skill demo uses equipped head")
	preview.hide()
	view.hub(3)
	check(click(view.stage,"头部外观"),"open head catalog")
	check(click(view.stage,"原版头型") and view.model.body.find_child("YurikoUnitHead",true,false)==null and Book.journal_head_unlocked(),"switch to original and keep entitlement")
	progress=previous.duplicate(true)
	progress.affinity=20
	progress.pages=5
	progress.read={"gate":0,"rice":0,"map":0,"again":0}
	check(Book.commit(progress),"prepare level 20 before chapter five")
	var desk:Dictionary=Book.episodes[4]
	view.hub(0)
	view.read_episode(desk)
	check(not Book.journal_head_unlocked(),"opening the chapter leaves the head locked")
	for step in 80:
		if Book.journal_head_unlocked():break
		view.advance(0 if Book.choosing(desk) else -1)
	check(Book.journal_head_unlocked() and view.message.text.contains("已解锁手记头型") and not Book.journal_head_equipped(),"finishing chapter five unlocks without auto-equipping")
	check(Book.commit(previous),"restore profile after head boundary checks")
	view.hub(3)

func run() -> void:
	# Keep the test driver alive while pressing the same scene-change button as a player.
	get_tree().current_scene=null
	MetaProgress.yuriko_school={}
	check(MetaProgress.save(),"isolated clean profile")
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await get_tree().scene_changed
	await check_player_name()
	check(not click(get_tree().current_scene,"百合子手记"),"hidden menu locked before encounter")
	check(Book.commit({"pages":8}),"prepare eight field-earned pages for reading regression")
	get_tree().reload_current_scene()
	await get_tree().scene_changed
	check(click(get_tree().current_scene,"百合子手记"),"main menu entry")
	await get_tree().scene_changed
	var view=get_tree().current_scene
	check(click(view.stage,"日常活动") and view.tab == 1, "open daily activities from journal")
	await get_tree().process_frame
	await get_tree().process_frame
	var tab_rects:=navigation_rects(view)
	check(tab_rects.size()==7,"all journal navigation buttons present")
	var exit_before:Rect2=view.stage.get_node("ExitButton").get_global_rect()
	check(click(view.stage,"场景"),"open scene gallery")
	await get_tree().process_frame
	await get_tree().process_frame
	for key:Button in view.stage.find_children("*","Button",true,false):
		if tab_rects.has(key.text):check(key.get_global_rect().is_equal_approx(tab_rects[key.text]),"stable gallery tab "+key.text)
	check(view.photo.get_global_rect().position.x>view.size.x*.5 and view.photo.texture==view.model.get_texture() and view.model.outfit==Book.snapshot().skin,"right-side equipped model preview")
	var gallery:GridContainer=view.stage.find_child("SceneCards",true,false)
	check(gallery.get_child_count()==11,"all scene cards visible")
	var harbor:Button=gallery.get_node("SceneCard1")
	check(harbor.disabled and harbor.tooltip_text.contains("门从这边开"),"locked card has chapter hint")
	for card in gallery.get_children():
		var image:TextureRect=card.get_node("Scenery")
		var person:TextureRect=image.get_node("Yuriko")
		check(image.texture!=null and person.texture!=null and (image.material!=null)==card.disabled and person.use_parent_material==card.disabled,"card previews scenery and portrait together")
	click(view.stage,"日常活动")
	check(view.scenery.material==null and view.scenery.texture==view.CLASSROOM,"leaving preview restores saved background")
	var hub_portrait:TextureButton=view.stage.get_node("HubPortrait")
	for outfit in ["uniform", "casual", "rescue", "swim", "uniform"]:
		check(hub_portrait.texture_normal == view.story_portraits[outfit], "hub portrait cycles to story art: " + outfit)
		var center := hub_portrait.get_global_rect().get_center()
		check(center.x > view.size.x * 0.6, "hub portrait is on the right")
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = center
			event.pressed = pressed
			view.get_viewport().push_input(event, true)
	check(click(view.stage,"试衣间"),"open wardrobe from daily activities")
	for section in ["衣装","头部外观","衣装"]:
		check(click(view.wardrobe_catalog,section),"switch wardrobe section "+section)
		await get_tree().process_frame
		await get_tree().process_frame
		var wardrobe_rects:=navigation_rects(view)
		for title:String in tab_rects:
			check(wardrobe_rects.has(title) and wardrobe_rects[title].is_equal_approx(tab_rects[title]),"stable wardrobe tab "+title+" on "+section)
		var exit_button:Button=view.stage.find_child("ExitButton",true,false)
		check(exit_button.get_global_rect().is_equal_approx(exit_before),"stable wardrobe exit")
		var catalog_rect:Rect2=view.wardrobe_catalog.get_global_rect()
		var viewer_rect:Rect2=view.photo.get_parent().get_global_rect()
		check(catalog_rect.end.x<=viewer_rect.position.x and not exit_before.intersects(viewer_rect) and view.stage.get_global_rect().encloses(viewer_rect),"wardrobe preview and controls fit beside catalog")
	check(not click(view.stage,Psi.SKINS[1]) and not Book.wear(2) and view.model.outfit==0,"only starting clothes can be equipped before reading")
	await check_wedding_cg(view)
	var motions:OptionButton=view.stage.find_children("*","OptionButton",true,false)[0]
	motions.item_selected.emit(2)
	view._process(0.0)
	var length:float=view.model.duration(view.model.action)
	view._process(length+.125)
	check(is_equal_approx(view.model.elapsed,.125),"wardrobe repeats a full cast")
	check(click(view.stage,"暂停"),"pause current motion")
	view._process(.25)
	check(is_equal_approx(view.model.elapsed,.125),"paused pose stays still")
	check(click(view.stage,"播放"),"resume current motion")
	view._process(.25)
	check(is_equal_approx(view.model.elapsed,.375),"resume from paused position")
	var middle:=InputEventMouseButton.new()
	middle.button_index=MOUSE_BUTTON_MIDDLE
	middle.pressed=true
	view.photo.gui_input.emit(middle)
	check(is_equal_approx(view.zoom,1.15),"middle click zooms in once")
	check_head_wardrobe(view)
	check_gift_shop(view)
	var first:Dictionary=Book.episodes[0]
	check(not Book.available(Book.episodes[8]) and not Book.learn("Shield_Rank1"),"school activities and unpaid study locked")
	check(Stories.candidate({"country":"美国","stage":2},"intel")!="YURIKO","no random Yuriko clue before letter")
	check(click(view.stage,"继续阅读"),"open novel")
	check(click(view.stage,"下一句"),"advance first page")
	check(not view.unlocked_scenes().has(1),"partial reading keeps harbor locked")
	var saved_step:int=Book.cursor(first).step
	click(view.stage,"收起手记")
	MetaProgress.yuriko_school={}
	MetaProgress.load_save()
	click(view.stage,"继续阅读")
	check(Book.cursor(first).step==saved_step and view.current.id==first.id,"resume saved line through menu")
	for i in Book.episodes.size():
		var ep:Dictionary=Book.episodes[i]
		view.hub(0 if ep.kind=="chapter" else 1)
		var shown := false
		for entry:Button in view.stage.find_children("*","Button",true,false):
			if entry.text.begins_with(ep.title+"　"):
				shown = click(entry.get_parent(),"?") and view.message.text == view.episode_source(ep) and view.current.is_empty()
				break
		check(shown,"show source from episode row "+ep.id)
		if ep.has("diary_cost"):
			check(click(view.stage,ep.title+"　") and view.message.text == view.episode_source(ep) and view.current.is_empty() and not Book.available(ep),"locked without diary "+ep.id)
			var run:Dictionary={"id":"diary_test","stage":i}
			var objectives:Array=[{"kind":"intel","done":true}]
			view.Bonds.attach(objectives)
			view.Bonds.settle(run,{"objectives":objectives},{})
			check(view.Bonds.deliver(run) and view.Bonds.deliver(run) and Book.diary_balance()==1,"one diary per reward receipt")
			view.hub(1)
		check(click(view.stage,ep.title+"　"),"open unlocked episode "+ep.id)
		if ep.has("diary_cost"):check(Book.diary_balance()==0 and Book.available(ep) and not Book.unlock_diary(ep),"single permanent purchase")
		var outfit:="uniform"
		match ep.id:
			"gate","rice":outfit="rescue"
			"map","again","station","market":outfit="casual"
			"swim":outfit="swim"
		check(ep.portrait==outfit,"authored story outfit "+ep.id)
		check_speaker(view,ep)
		if ep.kind=="activity":check(view.scenery.texture is AtlasTexture and view.scenery.texture.region.size.x>500,"daily scene texture "+ep.id)
		finish(view,ep,i%2)
		var scene_id:int=view.scene_index(ep)
		check(view.unlocked_scenes().has(scene_id),"finished scene available: "+ep.id)
		if i==0:
			click(view.stage,"场景")
			harbor=view.stage.find_child("SceneCard1",true,false)
			check(not harbor.disabled and harbor.get_node("Scenery").material==null,"unlocked harbor card is in color")
			harbor.pressed.emit()
			MetaProgress.yuriko_school={}
			MetaProgress.load_save()
			view.hub(0)
			check(view.scenery.texture==view.HARBOR,"chosen harbor restored from profile")
		if ep.kind=="chapter":
			check(Book.outfit_unlocked(1)==(i>=4) and Book.outfit_unlocked(2)==(i>=7),"chapter wardrobe milestone "+ep.id)
		if ep.id in ["desk","letter"]:check(view.message.text.contains("试衣间已解锁"),"milestone announces free outfit "+ep.id)
		if ep.kind=="chapter" and ep.id!="letter":
			check(view.tab==0,"ordinary chapter returns to journal")
		if ep.id=="letter":
			check(view.tab==1 and click(view.stage,"继续阅读") and view.current.id=="bread","final chapter opens daily activities and next unread activity")
			click(view.stage,"收起手记")
			click(view.stage,"返回主菜单")
			await get_tree().scene_changed
			MetaProgress.load_save()
			click(get_tree().current_scene,"百合子手记")
			await get_tree().scene_changed
			view=get_tree().current_scene
			check(view.tab==1 and click(view.stage,"手记") and view.tab==0,"completed save opens activities and permits manual return")
			check(not click(view.stage,"继续阅读"),"completed journal does not recommend an activity")
		await get_tree().process_frame
	check(Book.contact_ready() and Stories.candidate({"country":"美国","stage":2},"intel")=="YURIKO","letter opens expedition clue")
	check(Book.balance()==15,"six chapter and nine activity points")
	var rice:Dictionary=Book.episodes[1]
	view.hub(0)
	click(view.stage,rice.title+"　")
	finish(view,rice,0)
	check(view.tab==0,"manual reread stays on journal")
	check(Book.balance()==15 and int(MetaProgress.yuriko_school.read.rice)==1,"replay preserves reward and original response")
	check(Book.lines(Book.episodes[3],0).has(Book.episodes[3].echo.lines[1]),"reunion recalls first meal")
	for i in Book.episodes.size():
		var ep:Dictionary=Book.episodes[i]
		view.hub(0 if ep.kind=="chapter" else 1)
		click(view.stage,ep.title+"　")
		finish(view,ep,1-i%2)
		check(int(MetaProgress.yuriko_school.read[ep.id])==i%2,"both paths readable, original entry retained "+ep.id)
		await get_tree().process_frame
	check(observed_speakers.size()==EXPECTED_CAST.size(),"all named and unnamed speakers reached in the live reader")
	check(Book.balance()==15,"all alternative readings award no extra points")
	click(view.stage,"灵能练习")
	check(click(view.stage,"观看技能"),"launch native demo from study")
	var demo=view.get_children().back()
	demo.ability.select(1)
	demo.choose(1)
	demo.level.select(2)
	demo.restart(2)
	check(demo.visible and demo.caption.text.contains("7"),"level three W demo")
	demo.hide()
	check(not Book.learn("Shield_Rank2"),"prerequisites enforced")
	for t in Book.talents:
		var prefix:String=preload("res://scripts/units/yuriko.gd").NAMES[t.branch]+" "+str(int(t.rank))+"　"
		check(click(view.stage,prefix) and t.id in Book.snapshot().learned,"real study purchase "+t.id)
	check(not Book.learn("Shield_Rank1") and Book.balance()==0,"duplicate purchase rejected")
	click(view.stage,"试衣间")
	for i in [0,1,2]:
		check(click(view.stage,preload("res://scripts/units/yuriko.gd").SKINS[i]),"change outfit")
		check(view.model.rig.get_bone_count()==(52 if i==0 else 36) and view.model.outfit==i,"live 3D rig")
		check_turns(view)
		check_motion_frame(view)
	check(click(view.stage,"拉近") and view.zoom>1,"zoom control")
	MetaProgress.yuriko_school={}
	MetaProgress.load_save()
	check(Book.snapshot().skin==2 and Book.snapshot().learned.size()==15,"profile survives reload")
	view.hub(0)
	check(click(view.stage,rice.title+"　"),"reopen early rescue chapter")
	var reached_rescue:=false
	for step in rice.intro.size():
		var line:String=rice.intro[int(Book.cursor(rice).step)]
		if line.begins_with("百合子｜"):
			reached_rescue=view.actor_layer.texture==view.story_portraits.rescue
			break
		click(view.stage,"下一句")
	check(reached_rescue,"replay rescue clothes with chapter III combat outfit equipped")
	check(Book.snapshot().skin==2,"story portrait leaves equipped wardrobe intact")
	click(view.stage,"收起手记")
	var exit_rect:Rect2=view.stage.get_node("ExitButton").get_rect()
	check(is_equal_approx(exit_rect.position.y,16) and is_equal_approx(view.stage.size.x-exit_rect.end.x,16),"exit button at top right of stage")
	check(click(view.stage,"返回主菜单"),"return to main")
	await get_tree().scene_changed
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"country":"美国","map_size":2400,"starting_funds":8000})
	var field=load("res://scenes/battle.tscn").instantiate()
	add_child(field)
	var w=field.battle
	w._place_building("GAPILE","ally",w.player_start()+Vector2(175,95),true)
	var qualified:=MetaProgress.yuriko_school.duplicate(true)
	qualified.affinity=maxi(int(qualified.get("affinity",0)),20)
	check(Book.commit(qualified) and Book.wear_journal_head(true),"equip qualified head before skirmish")
	check(Psi.summon(w),"profile to skirmish summon")
	var u=Psi.hero(w)
	check(u!=null and u.yuriko_model.outfit==2 and Psi.rank(w,"Lure")==3 and Psi.shield(u) and is_equal_approx(u.special.psi_shield,9.0),"equipped skin, trained W and nine-second shield in live battle")
	check(u.yuriko_model.body.find_child("YurikoUnitHead",true,false)!=null,"real summoned unit uses equipped head on outfit III")
	qualified=MetaProgress.yuriko_school.duplicate(true)
	qualified.cg_album={"same_stop":true}
	qualified.journal_head=false
	check(Book.commit(qualified),"seed owned wedding outfit for field change")
	Psi.dress(w,Book.WEDDING_OUTFIT)
	check(u.yuriko_model.outfit==Book.WEDDING_OUTFIT and u.yuriko_model.journal_head,"real summoned unit wears bridal rig and forced AI head")
	var profile:=MetaProgress.yuriko_school.duplicate(true)
	profile.read={}
	check(Book.commit(profile) and Book.snapshot().skin==0,"stale equipped outfit is resolved to the starting clothes")
	u.special.yuriko_skin=2
	u.yuriko_model.set_skin(0)
	u.yuriko_model.sync_actor(u,.1)
	var command_btn=field.hud.find_child("YurikoCommand",true,false)
	command_btn.pressed.emit()
	var command=command_btn.pressed.get_connections()[0].callable.get_object()
	command._dress(2)
	check(command.outfit.is_item_disabled(1) and command.outfit.is_item_disabled(2) and command.outfit.selected==0 and u.yuriko_model.outfit==0 and Psi.skin(w)==0,"battle rejects locked outfits and restores correct preview")
	preload("res://scripts/units/yuriko_bonds.gd").gm_unlock()
	check(Book.wear(2) and Book.snapshot().skin==2,"GM story unlock includes chapter outfits")
	field.free()
	print("YURIKO SCHOOL checks=",checks," failed=",failures)
	get_tree().quit(0 if failures==0 else 1)

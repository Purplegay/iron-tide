extends Node

const Catalog = preload("res://scripts/ui/campaign_cg_catalog.gd")
const Film = preload("res://scripts/ui/hollywood_film.gd")
const Book = preload("res://scripts/units/yuriko_school.gd")
var passed := 0
var failed := 0
var callbacks := 0

const ALLIED_01 := ["A01_F00E", "A01_P01E", "A01_P02E", "A01_P03E"]

func catalog_total() -> int:
	var total := 0
	for group in Catalog.GROUPS:
		total += group.clips.size()
	return total

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL: ",message)

func button(scene: Node, text: String) -> Button:
	for control in scene.find_children("*","Button",true,false):
		if control.text == text: return control
	return null

func has_reward(count: int) -> bool:
	return MetaProgress.balance("diamonds") == 5 * count \
		and MetaProgress.balance("war_points") == 25 * count \
		and MetaProgress.balance("credits") == 150 * count \
		and MetaProgress.balance("cores") == 0

func run() -> void:
	var tree := get_tree()
	if OS.get_environment("IRON_TIDE_CG_TEST_PROFILE") != OS.get_user_data_dir():
		printerr("Set IRON_TIDE_CG_TEST_PROFILE to the isolated Godot user data directory.")
		tree.quit(2)
		return
	reparent(tree.root)
	tree.create_timer(25.0,true,false,true).timeout.connect(func():
		printerr("CG COLLECTION: timeout")
		tree.quit(3))
	if "--chapter-order" in OS.get_cmdline_user_args():
		tree.change_scene_to_file("res://scenes/cg_collection.tscn")
		await tree.scene_changed
		var screen := tree.current_scene
		for faction: String in ["allied", "soviet"]:
			var rows := {}
			for group in Catalog.GROUPS:
				if group.faction != faction: continue
				var chapter := int(group.chapter)
				var row := -1.0
				var previous_x := -1.0
				for clip in group.clips:
					var card := screen.find_child(clip[0], true, false) as Button
					check(card != null and screen.find_child("Gallery_" + faction, true, false).is_ancestor_of(card), clip[0] + " 位于对应阵营收藏页")
					if card == null: continue
					if row < 0.0: row = card.position.y
					check(card.position.y == row and card.position.x > previous_x, clip[0] + " 保留关内行和播放顺序")
					previous_x = card.position.x
				rows[chapter] = row
			var chapters := rows.keys()
			chapters.sort()
			var previous_y := -1.0
			for chapter in chapters:
				check(rows[chapter] > previous_y, "%s 第 %d 关按关卡号从上到下排列" % [faction, chapter])
				previous_y = rows[chapter]
		print("CG COLLECTION CHAPTER ORDER: %d passed, %d failed" % [passed, failed])
		tree.quit(failed)
		return
	if "--allied-finale-replay" in OS.get_cmdline_user_args():
		var ids := ["A07_F00E","A07_P01E","A08_F00E"]
		for unlocked in [false,true]:
			if unlocked:
				for id in ids: MetaProgress.campaign_cg[id]=true
			tree.change_scene_to_file("res://scenes/cg_collection.tscn")
			await tree.scene_changed
			var screen := tree.current_scene
			await click(screen.find_child("Tab_allied",true,false))
			for id in ids:
				var card := screen.find_child(id,true,false) as Button
				check(card!=null,id+" 收藏卡存在")
				if card==null: continue
				var preview := card.get_node("FilmPreview") as TextureRect
				check(card.disabled!=unlocked and preview.material.get_shader_parameter("screen_type")==int(unlocked),id+" 锁定雪花／已收录节选状态")
				if not unlocked: continue
				check(preview.texture.resource_path.ends_with(id+".webp"),id+" 使用同名节选")
				card.pressed.emit()
				await tree.process_frame
				var film = screen.get_node_or_null("HollywoodFilm")
				check(film!=null and film.replay and film.clip_id==id and film.player.is_playing(),id+" 从收藏打开对应正片")
				if film==null: continue
				var media := Catalog.media(id)
				if not media.audio.is_empty(): check(film.mission_audio!=null,id+" 回放加载独立音轨")
				await drag_timeline(film.replay_slider,0.12,0.63)
				var later: float = film._playback_seconds()
				check(absf(later-film.replay_length*0.63)<2.0,id+" 可向前定位")
				if id=="A07_P01E" and film.replay_length*0.63>=film.replay_video_length:
					check(film.replay_still!=null and film.replay_still.texture!=null and not film.subtitle.text.is_empty(),id+" 续音留帧和中文字幕存在")
				var early: float = minf(0.18,film.replay_video_length*0.3/film.replay_length)
				await drag_timeline(film.replay_slider,0.63,early)
				check(film._playback_seconds()<later,id+" 可向后定位")
				if id=="A07_P01E": check(film.replay_still==null and absf(film.player.stream_position-film.mission_audio.get_playback_position())<0.4,id+" 拖回影片后画音同步")
				film.skip.pressed.emit()
				await tree.process_frame
				check(not screen.has_node("HollywoodFilm") and screen.page.visible,id+" 返回收藏")
		print("CG FINALE: %d passed, %d failed" % [passed,failed])
		tree.quit(failed)
		return
	if "--allied-first-replay" in OS.get_cmdline_user_args():
		tree.change_scene_to_file("res://scenes/main.tscn")
		await tree.scene_changed
		button(tree.current_scene,"CG 收藏").pressed.emit()
		await tree.scene_changed
		var screen := tree.current_scene
		await click(screen.find_child("Tab_allied",true,false))
		var card: Button = screen.find_child("A01_P03E",true,false)
		check(not card.disabled and card.get_node("FilmPreview").texture.resource_path.ends_with("A01_P03E.webp"),"通关存档直接显示第三段影片节选")
		card.pressed.emit()
		await tree.process_frame
		var film = screen.get_node_or_null("HollywoodFilm")
		check(film!=null and film.replay and film.clip_id=="A01_P03E" and film.player.is_playing(),"从收藏卡打开抵达过去的正片")
		if film!=null:
			await drag_timeline(film.replay_slider,0.1,0.65)
			var later: float = film.player.stream_position
			check(absf(later-film.replay_length*0.65)<2.0 and not film.subtitle.text.is_empty(),"向前拖动原片并更新中文字幕")
			await drag_timeline(film.replay_slider,0.65,0.15)
			check(film.player.stream_position<later-4 and "穿越了时间" in film.subtitle.text,"向后拖回穿越成功对白")
			film.skip.pressed.emit()
		print("CG COLLECTION: %d passed, %d failed" % [passed,failed])
		tree.quit(failed)
		return
	if "--three-campaign-assets" in OS.get_cmdline_user_args():
		var screen=load("res://scripts/screens/cg_collection.gd")
		for group in Catalog.GROUPS:
			if group.folder not in ["hollywood","time_shift","head_games"]:continue
			for clip in group.clips:
				var id:String=clip[0]
				var media:=Catalog.media(id)
				check(load(media.video) is VideoStream,id+" 原片可加载")
				check(screen.POSTERS.get(id) is Texture2D,id+" 收藏节选可加载")
				if not str(media.audio).is_empty():
					var audio:=load(media.audio) as AudioStream
					check(audio!=null and audio.get_length()>0,id+" 独立原声非空")
		print("CG COLLECTION: %d passed, %d failed" % [passed,failed])
		tree.quit(failed)
		return
	var seed := not "--cold" in OS.get_cmdline_user_args()
	if seed:
		check(MetaProgress.campaign_cg.is_empty(),"新档无收藏")
		check(has_reward(0),"新档三种余额为零")
		check_gallery_progress()
		MetaProgress.campaign_cg["A02_F00E"] = true
		check(not MetaProgress.collect_campaign_cg("A02_F00E") and has_reward(0),"旧档已收藏影片不补发")
		MetaProgress.campaign_cg.erase("A02_F00E")
		check(not MetaProgress.collect_campaign_cg("invalid") and has_reward(0),"未知影片不能发奖")
		var host := Node.new()
		add_child(host)
		Film.show_clip(host,"invalid",func(): callbacks += 1)
		check(callbacks == 1 and MetaProgress.campaign_cg.is_empty() and has_reward(0),"无效资源不入册或发奖，仍放行剧情回调")
		Film.show_clip(host,"S01_F00E",func(): callbacks += 1)
		var film = host.get_node_or_null("HollywoodFilm")
		check(film != null and film.player.is_playing() and film.mission_audio.playing,"战役影片与独立音轨播放")
		check(tree.paused and MetaProgress.campaign_cg.get("S01_F00E") == true,"首播立即收藏且保持战役暂停")
		check(film.replay_slider == null,"进度条只在收藏回看显示，不改变战役播放")
		check(has_reward(1),"首播自动发放三种正确货币，不加战略核心")
		check(not film.has_node("FirstUnlockReward"),"到账不打断影片、不显示提示")
		film.skip.pressed.emit()
		await tree.process_frame
		check(has_reward(1),"立即跳过也保留奖励")
		check(callbacks == 2 and not tree.paused,"跳过后恢复战斗并只触发一次剧情回调")
		Film.show_clip(host,"S01_F00E")
		host.get_node("HollywoodFilm").finish()
		await tree.process_frame
		check(MetaProgress.campaign_cg.size() == 1 and has_reward(1),"重打不重复收藏或发奖")
		var temporary := MetaProgress.SAVE_PATH + ".tmp"
		check(DirAccess.make_dir_absolute(temporary) == OK,"构造暂存写入失败")
		check(not MetaProgress.collect_campaign_cg("A02_F00E") and not MetaProgress.campaign_cg.has("A02_F00E") and has_reward(1),"写盘失败同时撤销收藏和奖励")
		check(DirAccess.remove_absolute(temporary) == OK,"恢复隔离档暂存路径")
	else:
		check(MetaProgress.campaign_cg == {"S01_F00E":true} and has_reward(1),"新进程同时读回收藏和三种余额")
		tree.change_scene_to_file("res://scenes/main.tscn")
		await tree.scene_changed
		button(tree.current_scene,"CG 收藏").pressed.emit()
		await tree.scene_changed
		var screen := tree.current_scene
		var bar: ProgressBar = screen.find_child("CampaignCGProgress",true,false)
		check(bar != null and bar.value == 1 and bar.max_value == catalog_total(),"从主菜单进入时显示读档后的战役影片总进度")
		var allied: Button = screen.find_child("Tab_allied",true,false)
		var soviet: Button = screen.find_child("Tab_soviet",true,false)
		var allied_card: Button = screen.find_child("A02_F00E",true,false)
		var unlocked: Button = screen.find_child("S01_F00E",true,false)
		var locked: Button = screen.find_child("S08_F00E",true,false)
		check(not unlocked.disabled and locked.disabled,"主菜单进入收藏，只允许回看已收录影片")
		check(soviet.button_pressed and unlocked.is_visible_in_tree() and not allied_card.is_visible_in_tree(),"初始为样稿苏军页，其他阵营卡片不可见")
		await click(allied)
		check(allied.button_pressed and not soviet.button_pressed and allied_card.is_visible_in_tree() and not unlocked.is_visible_in_tree(),"鼠标切换盟军页，阵营内容不混排")
		check(bar != null and bar.value == 1 and bar.max_value == catalog_total(),"切换阵营不改变战役总进度")
		await click(soviet)
		check(soviet.button_pressed and unlocked.is_visible_in_tree(),"鼠标可切回苏军页")
		var poster: TextureRect = unlocked.get_node("FilmPreview")
		var noise: TextureRect = locked.get_node("FilmPreview")
		check(poster.texture.resource_path.ends_with("S01_F00E.png") and poster.material.get_shader_parameter("screen_type") == 1,"收录卡片显示对应原片预览")
		check(noise.texture.resource_path.ends_with("snow.png") and noise.material.get_shader_parameter("screen_type") == 0,"锁定卡片只显示雪花")
		check(screen.find_child("YurikoPortrait",true,false).texture.resource_path.ends_with("Portrait_Japan_Yuriko_01.png"),"手记入口使用原版百合子头像")
		if "--gallery-shot" in OS.get_cmdline_user_args():
			screen.get_viewport().gui_release_focus()
			await RenderingServer.frame_post_draw
			check(screen.get_viewport().get_texture().get_image().save_png("user://cg-soviet.png") == OK,"苏军页实机截图")
		await click(locked)
		check(screen.page.visible and not screen.has_node("HollywoodFilm"),"点击雪花卡片不打开播放器")
		check(not Film.show_replay(screen,"S08_F00E",Callable()),"回看入口也拒绝未解锁影片")
		await click(unlocked)
		var film = screen.get_node("HollywoodFilm")
		check(film.replay and not tree.paused and not screen.page.visible,"收藏全屏回看不暂停场景")
		await tree.create_timer(0.8).timeout
		check(film.player.stream_position > 0 and film.mission_audio.playing and not film.subtitle.text.is_empty(),"视频实际推进并有独立音轨与中文字幕")
		await drag_timeline(film.replay_slider, 0.15, 0.55)
		var forward: float = film.player.stream_position
		check(absf(forward - film.replay_length * 0.55) < 2.0 and absf(forward - film.mission_audio.get_playback_position()) < 0.4,"鼠标向前拖动同时定位画面和独立音轨")
		await drag_timeline(film.replay_slider, 0.55, 0.18)
		check(film.player.stream_position < forward - 2.0 and absf(film.player.stream_position - film.mission_audio.get_playback_position()) < 0.4,"鼠标向后拖动后画音同步续播")
		film.skip.pressed.emit()
		await tree.process_frame
		check(screen.page.visible and unlocked.has_focus() and not screen.has_node("HollywoodFilm"),"返回收藏恢复按钮焦点")
		unlocked.pressed.emit()
		screen.get_node("HollywoodFilm").player.finished.emit()
		await tree.process_frame
		check(screen.page.visible and not screen.has_node("HollywoodFilm"),"播放结束返回收藏")
		unlocked.pressed.emit()
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		tree.root.push_input(escape)
		await tree.process_frame
		await tree.process_frame
		check(screen.page.visible and not screen.has_node("HollywoodFilm"),"按 Esc 返回收藏而不退出页面")
		check(MetaProgress.campaign_cg.size() == 1 and has_reward(1) and not Book.owns_wedding_cg(),"回看不改变余额、收藏或婚纱购买状态")
		await check_radio_seek(screen)
		await click(allied)
		if "--gallery-shot" in OS.get_cmdline_user_args():
			screen.get_viewport().gui_release_focus()
			await RenderingServer.frame_post_draw
			check(screen.get_viewport().get_texture().get_image().save_png("user://cg-allied.png") == OK,"盟军页实机截图")
		var yuriko: Button = screen.find_child("YurikoJournal",true,false)
		var avatar: Control = yuriko.get_node("YurikoPortrait")
		await click(avatar)
		if tree.current_scene == null or tree.current_scene == screen: await tree.scene_changed
		check(tree.current_scene.tab == 8 and not Book.owns_wedding_cg(),"直达百合子原 CG 集，不绕过原解锁")
		button(tree.current_scene,"返回 CG 收藏").pressed.emit()
		await tree.scene_changed
		check(tree.current_scene.active_faction == "allied","百合子返回收藏后保留原阵营页")
		button(tree.current_scene,"返回主菜单").pressed.emit()
		await tree.scene_changed
		check(tree.current_scene.scene_file_path == "res://scenes/main.tscn","收藏返回主菜单")
		var ids := {}
		for group in Catalog.GROUPS:
			for clip in group.clips:
				var media := Catalog.media(clip[0])
				check(not ids.has(clip[0]) and load(media.video) is VideoStream,"影片资源可加载: " + clip[0])
				ids[clip[0]] = true
				check(screen_poster_exists(clip[0]),"每段影片有独立缩略图: " + clip[0])
				if not media.audio.is_empty():
					check(load(media.audio) is AudioStream,"独立音轨可加载: " + clip[0])
		check(ids.size() == catalog_total(),"覆盖目录中全部战役影片")
	print("CG COLLECTION: %d passed, %d failed" % [passed,failed])
	tree.quit(failed)

func check_gallery_progress() -> void:
	var gallery := preload("res://scenes/cg_collection.tscn")
	var previous := MetaProgress.campaign_cg.duplicate()
	MetaProgress.campaign_cg["unknown_test_clip"] = true
	var total := catalog_total()
	for owned in [0,1,total]:
		var screen := gallery.instantiate()
		add_child(screen)
		var bar: ProgressBar = screen.find_child("CampaignCGProgress",true,false)
		check(bar != null and bar.value == owned and bar.max_value == total and is_equal_approx(bar.ratio,float(owned) / total),"战役总进度 %d / %d，不统计图鉴外的记录" % [owned,total])
		if owned == 0 or owned == total:
			for id in ALLIED_01:
				var card: Button = screen.find_child(id,true,false)
				var preview: TextureRect = card.get_node("FilmPreview") if card else null
				var unlocked: bool = owned == total
				var expected: String = (id + ".webp") if unlocked else "snow.png"
				check(preview != null and card.disabled != unlocked and preview.texture.resource_path.get_file() == expected and preview.material.get_shader_parameter("screen_type") == int(unlocked),"盟军 01 预览 %s（已收藏=%s）" % [id,unlocked])
		screen.free()
		if owned == 0:
			MetaProgress.campaign_cg["S01_F00E"] = true
		elif owned == 1:
			for group in Catalog.GROUPS:
				for clip in group.clips:
					MetaProgress.campaign_cg[clip[0]] = true
	MetaProgress.campaign_cg = previous

func click(target: Control) -> void:
	var viewport := target.get_viewport()
	var pos := target.get_global_transform_with_canvas() * (target.size * 0.5)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.global_position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		viewport.push_input(event,true)
	await get_tree().process_frame

func drag_timeline(slider: HSlider, from_ratio: float, to_ratio: float) -> void:
	var viewport := slider.get_viewport()
	var transform := slider.get_global_transform_with_canvas()
	var from := transform * (slider.size * Vector2(from_ratio, 0.5))
	var to := transform * (slider.size * Vector2(to_ratio, 0.5))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	viewport.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = to
	motion.global_position = to
	motion.relative = to - from
	viewport.push_input(motion, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = to
	release.global_position = to
	viewport.push_input(release, true)
	await get_tree().create_timer(0.25).timeout

func check_radio_seek(screen: Node) -> void:
	MetaProgress.campaign_cg["A01_P01E"] = true
	check(Film.show_replay(screen, "A01_P01E", Callable()), "打开伊娃战场简报回看")
	var film = screen.get_node("HollywoodFilm")
	await get_tree().process_frame
	check(film.replay_slider.max_value > film.player.get_stream_length() + 5.0, "进度条包含短片后的续音")
	await drag_timeline(film.replay_slider, 0.1, 0.55)
	check(film.replay_still != null and film.replay_still.texture != null and film.mission_audio.get_playback_position() > 6.0 and not film.subtitle.text.is_empty(), "跳到续音段时保留对应画面、语音和字幕")
	await drag_timeline(film.replay_slider, 0.55, 0.09)
	check(film.replay_still == null and film.player.is_playing() and film.player.stream_position < 2.5 and absf(film.player.stream_position - film.mission_audio.get_playback_position()) < 0.4, "从续音拖回视频段后画音同步播放")
	await drag_timeline(film.replay_slider, 0.09, 1.0)
	await get_tree().create_timer(0.65).timeout
	check(not screen.has_node("HollywoodFilm"), "拖到续音末尾后自然结束")
	MetaProgress.campaign_cg.erase("A01_P01E")

func screen_poster_exists(id: String) -> bool:
	const Gallery = preload("res://scripts/screens/cg_collection.gd")
	var texture: Texture2D = Gallery.POSTERS.get(id)
	return texture != null and texture.get_width() > 0 and texture.resource_path.get_file().get_basename() == id

extends Node

const Catalog = preload("res://scripts/ui/campaign_cg_catalog.gd")
const Film = preload("res://scripts/ui/hollywood_film.gd")
const Book = preload("res://scripts/units/yuriko_school.gd")
var passed := 0
var failed := 0
var callbacks := 0

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
	var seed := not "--cold" in OS.get_cmdline_user_args()
	if seed:
		check(MetaProgress.campaign_cg.is_empty(),"新档无收藏")
		check(has_reward(0),"新档三种余额为零")
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
		var allied: Button = screen.find_child("Tab_allied",true,false)
		var soviet: Button = screen.find_child("Tab_soviet",true,false)
		var allied_card: Button = screen.find_child("A02_F00E",true,false)
		var unlocked: Button = screen.find_child("S01_F00E",true,false)
		var locked: Button = screen.find_child("S08_F00E",true,false)
		check(not unlocked.disabled and locked.disabled,"主菜单进入收藏，只允许回看已收录影片")
		check(soviet.button_pressed and unlocked.is_visible_in_tree() and not allied_card.is_visible_in_tree(),"初始为样稿苏军页，其他阵营卡片不可见")
		await click(allied)
		check(allied.button_pressed and not soviet.button_pressed and allied_card.is_visible_in_tree() and not unlocked.is_visible_in_tree(),"鼠标切换盟军页，阵营内容不混排")
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
		check(ids.size() == 11,"覆盖现有 11 段战役影片")
	print("CG COLLECTION: %d passed, %d failed" % [passed,failed])
	tree.quit(failed)

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

func screen_poster_exists(id: String) -> bool:
	const Gallery = preload("res://scripts/screens/cg_collection.gd")
	var texture: Texture2D = Gallery.POSTERS.get(id)
	return texture != null and texture.get_width() > 0 and texture.resource_path.get_file().get_basename() == id

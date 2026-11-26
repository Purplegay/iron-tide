extends Node

var failures := 0

func expect(ok: bool, message: String) -> void:
	print("CAMPAIGN MENU ",ok," ",message)
	if not ok: failures += 1

func find_button(screen, title: String):
	for btn in screen.find_children("*","Button",true,false):
		if btn.text == title or btn.text.ends_with("\n"+title) or btn.text=="‹  "+title: return btn
	return null

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.change_scene_to_file("res://scenes/main.tscn")
	await tree.scene_changed
	find_button(tree.current_scene,"战 役").pressed.emit()
	await tree.scene_changed
	var menu = tree.current_scene
	var allied = menu.find_child("allied",true,false)
	var soviet = menu.find_child("soviet",true,false)
	await tree.create_timer(0.35).timeout
	expect(allied.frame>0 and soviet.frame>0,"盟苏两枚阵营徽动画推进")
	var shot := OS.get_environment("IRON_TIDE_FACTION_CAPTURE")
	if not shot.is_empty():
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png(shot)
	var soviet_plays := Ra2Sfx.a_plays
	find_button(menu,"苏军战役").pressed.emit()
	expect(Ra2Sfx.a_plays==soviet_plays+1,"苏军战役选中语音成功播放一次")
	var level:OptionButton=menu.find_children("*","OptionButton",true,false)[0]
	level.select(2)
	level.item_selected.emit(2)
	find_button(menu,"带入我的养成").pressed.emit()
	expect(menu.difficulty==2,"苏军选择困难并保留选择")
	await tree.process_frame
	var soviet_capture:=OS.get_environment("IRON_TIDE_SOVIET_CAPTURE")
	if not soviet_capture.is_empty():
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png(soviet_capture)
	for label in menu.find_children("*","Label",true,false):
		if label.text.begins_with("摧毁两座心灵信标"):
			expect(label.position.x+label.size.x<=739 and label.get_line_count()>1,"苏军目标在中栏内换行")
	find_button(menu,"更换阵营").pressed.emit()
	var allied_plays := Ra2Sfx.a_plays
	find_button(menu,"盟军战役").pressed.emit()
	expect(Ra2Sfx.a_plays==allied_plays+1,"盟军战役选中语音成功播放一次")
	var capture:=OS.get_environment("IRON_TIDE_COMMAND_CAPTURE")
	if not capture.is_empty():
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png(capture)
	find_button(menu,"更换阵营").pressed.emit()
	var original_plays := Ra2Sfx.a_plays
	find_button(menu,"Iron Tide 原创战役").pressed.emit()
	expect(Ra2Sfx.a_plays==original_plays+1,"Iron Tide 原创战役选中语音成功播放一次")
	var icons := menu.find_children("ResourceIcon", "TextureRect", true, false)
	expect(icons.size()==3 and icons.all(func(icon):return icon.texture!=null),"奖励表三列均有资源图标")
	var labels := menu.find_children("*","Label",true,false).map(func(item):return item.text)
	expect("战略点" in labels and "军需券" in labels and "钻石" in labels and "600" in labels,"战役奖励使用钱包资源名")
	find_button(menu,"带入我的养成").pressed.emit()
	expect(menu.carry,"选择带入养成")
	find_button(menu,"结晶裂谷").pressed.emit()
	expect(menu.mission.id=="m02" and not menu.carry,"换关恢复原版配置")
	find_button(menu,"灰烬要塞").pressed.emit()
	expect(menu.mission.endless,"无尽任务独立说明")
	find_button(menu,"返回主菜单").pressed.emit()
	await tree.scene_changed
	find_button(tree.current_scene,"遭遇战").pressed.emit()
	await tree.scene_changed
	expect(tree.current_scene.scene_file_path=="res://scenes/lobby.tscn" and find_button(tree.current_scene,"开始遭遇战")!=null,"遭遇战独立入口")
	tree.quit(failures)

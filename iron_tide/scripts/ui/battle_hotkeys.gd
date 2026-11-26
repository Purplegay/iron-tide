extends RefCounted
const PATH := "user://battle_hotkeys.cfg"
const ACTIONS := {
	"skill_q":["固有主动（Q 槽）",KEY_Q],"skill_w":["装配主动（W 槽）",KEY_W],"skill_e":["特殊操作（E 槽）",KEY_E],
	"attack":["攻击",KEY_A],"stop":["停止",KEY_S],"guard":["警戒",KEY_G],"attack_move":["攻击移动",KEY_X],
	"harvest":["采集",KEY_Y],"same":["同型选择",KEY_T],"selectall":["全选作战单位",KEY_F2],"selectall_alt":["全选备用键",KEY_P],
	"center":["聚焦选中单位",KEY_C],"centerbase":["回基地",KEY_H],"follow":["镜头跟随",KEY_F],"prev":["上一个单位",KEY_M],"next":["下一个单位",KEY_N],
	"repair":["维修",KEY_K],"sell":["出售",KEY_L],"deploy":["部署／收起",KEY_J],"reverse_attack":["倒退攻击",KEY_D],"pause":["暂停",KEY_SPACE],"speed":["切换倍速",KEY_TAB],
	"save":["快速存档",KEY_F5],"load":["打开存档",KEY_F9],"view_down":["投影比例减小",KEY_MINUS],"view_up":["投影比例增大",KEY_EQUAL],
	"mirror":["镜像视角",KEY_BACKSLASH],"yaw":["切换视角朝向",KEY_APOSTROPHE],
	"snapshot":["保存性能快照",KEY_F8],"radar_event":["跳到最近的雷达事件",KEY_PERIOD],
	"excluded":["找回已排除单位",KEY_F3],"exclude":["切换选中单位的全选排除标记",KEY_F4],
	"aggressive":["主动进攻开关（再按恢复防卫）",KEY_V],
}
static var bindings:Dictionary={}
static var loaded:=false
static var modal_count:=0

static func defaults() -> Dictionary:
	var result:Dictionary={}
	for id in ACTIONS:result[id]=ACTIONS[id][1]
	return result

static func allowed(key:int) -> bool:
	return (key>=KEY_A and key<=KEY_Z) or (key>=KEY_F1 and key<=KEY_F12 and key!=KEY_F11) or key in [KEY_SPACE,KEY_TAB,KEY_MINUS,KEY_EQUAL,KEY_BACKSLASH,KEY_APOSTROPHE,KEY_COMMA,KEY_PERIOD,KEY_BRACKETLEFT,KEY_BRACKETRIGHT,KEY_SEMICOLON]

static func ensure() -> void:
	if loaded:return
	loaded=true;bindings=defaults()
	var cfg:=ConfigFile.new()
	if cfg.load(PATH)!=OK:return
	bindings=read_bindings(cfg)

static func read_bindings(cfg:ConfigFile) -> Dictionary:
	var candidate:=defaults()
	var used:=[]
	var missing:=[]
	var legacy:=not cfg.has_section_key("keys","reverse_attack")
	for id in ACTIONS:
		# Migrate the former default deployment D without discarding custom keys.
		if (id in ["snapshot","aggressive","reverse_attack","excluded","exclude","radar_event"] and not cfg.has_section_key("keys",id)) or (id=="deploy" and legacy and cfg.get_value("keys",id,KEY_D)==KEY_D):
			missing.append(id)
			continue
		var key=cfg.get_value("keys",id,candidate[id])
		if not key is int or not allowed(key) or key in used:return defaults()
		candidate[id]=key;used.append(key)
	for id in missing:
		for key in [ACTIONS[id][1],KEY_F8,KEY_F7,KEY_F6,KEY_F3,KEY_F4,KEY_F10,KEY_F12]+range(KEY_A,KEY_Z+1):
			if not used.has(key):
				candidate[id]=key;used.append(key)
				break
	return candidate

static func label(id:String) -> String:
	ensure()
	return OS.get_keycode_string(bindings[id]) if bindings.has(id) else ""

static func hint(text:String) -> String:
	var pattern:=RegEx.new();pattern.compile("(?<![A-Za-z0-9+])(?:F[0-9]+|[A-Z])(?![A-Za-z0-9+])")
	var matches:=pattern.search_all(text)
	for i in range(matches.size()-1,-1,-1):
		var found=matches[i]
		for id in ACTIONS:
			if found.get_string()==OS.get_keycode_string(ACTIONS[id][1]):
				text=text.substr(0,found.get_start())+label(id)+text.substr(found.get_end());break
	return text

static func save(candidate:Dictionary) -> bool:
	var cfg:=ConfigFile.new()
	for id in candidate:cfg.set_value("keys",id,candidate[id])
	if cfg.save(PATH+".tmp")!=OK or DirAccess.rename_absolute(PATH+".tmp",PATH)!=OK:return false
	bindings=candidate;loaded=true
	return true

static func assign(id:String,key:int) -> String:
	ensure()
	if not ACTIONS.has(id) or not allowed(key):return "此键保留给编队、界面或滚屏，请选字母、标点或其它功能键。"
	for other in bindings:
		if other!=id and bindings[other]==key:return "冲突：%s 已用于「%s」。请先修改该指令。"%[OS.get_keycode_string(key),ACTIONS[other][0]]
	var candidate:=bindings.duplicate();candidate[id]=key
	return "" if save(candidate) else "保存失败，原快捷键保持不变。"

static func translate(event:InputEventKey) -> InputEventKey:
	ensure()
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return event if event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and event.keycode in [KEY_G,KEY_F] else null
	for id in bindings:
		if event.keycode==bindings[id]:
			var result:InputEventKey=event.duplicate()
			result.keycode=ACTIONS[id][1]
			return result
	return event if event.keycode==KEY_ESCAPE or (event.keycode>=KEY_0 and event.keycode<=KEY_9) else null

static func add_button(parent:Control,on_close:Callable=Callable(),before_open:Callable=Callable()) -> void:
	var button:=UiKit.make_button("战斗快捷键",14)
	button.name="BattleHotkeySettings"
	parent.add_child(button)
	button.pressed.connect(func():
		if modal_count>0:return
		if before_open.is_valid():before_open.call()
		var editor=load("res://scripts/ui/battle_hotkey_editor.gd").new()
		parent.get_tree().root.add_child(editor)
		if on_close.is_valid():editor.tree_exited.connect(on_close))

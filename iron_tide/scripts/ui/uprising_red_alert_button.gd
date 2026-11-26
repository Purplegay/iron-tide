extends TextureButton
## Uprising 1.1 TacticalHUDExperiencePanel red button + threat display.
signal activated
const ART := preload("res://assets/ra3/ui/red_alert/experience_panel.png")
const Alert = preload("res://scripts/expedition/red_alert.gd")
var world
var clock := 0.0
var flash_left := 0.0
var was_ready := false
var glow: TextureRect
var threat_bar: Control
var audio: AudioStreamPlayer
var appeared := false
var reveal := 0.0

static func region(rect: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ART
	texture.region = rect
	return texture

func setup(battle) -> void:
	world = battle
	var soviet: bool = world.roster_faction("ally") == "soviet"
	texture_normal = region(Rect2(0, 343, 130, 82) if soviet else Rect2(297, 264, 136, 94))
	texture_hover = texture_normal
	texture_pressed = texture_normal
	texture_disabled = texture_normal
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2(136, 86)
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tooltip_text = "RED ALERT · 起义时刻按钮\n持续 %d 秒：全军立即升满军衔；生产耗时 -50%%、单位攻速 +50%%、威力 +30%%。\n警戒值满格可储存一次总攻。靠总攻升满星的单位下关从一星开始。原本满星或没吃到总攻的单位保留军衔和经验。"%int(Alert.DURATION)
	glow = TextureRect.new()
	glow.texture = region(Rect2(297, 359, 133, 86) if soviet else Rect2(143, 263, 152, 98))
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.modulate.a = 0.0
	pressed.connect(_activate)

func build_status(parent: Control) -> void:
	# Fixed native dock: readiness moves the button, never the selection strip.
	position = Vector2(72, 42)
	size = Vector2(136, 86)
	modulate.a = 0.0
	threat_bar = preload("res://scripts/ui/uprising_threat_meter.gd").new()
	threat_bar.soviet = world.roster_faction("ally")=="soviet"
	parent.add_child(threat_bar)
	threat_bar.position = Vector2(0, 42)
	threat_bar.size = threat_bar.get_combined_minimum_size()
	parent.size.y = threat_bar.position.y + threat_bar.size.y
	audio=AudioStreamPlayer.new()
	audio.stream=load("res://assets/ra3/ui/red_alert/activation.wav")
	audio.volume_db=-8.0
	add_child(audio)
	# The HUD appearing is silent; readiness and activation own the cue.

func _play_alert_sound() -> void:
	if audio!=null and is_visible_in_tree() and not audio.playing:audio.play()

func _activate() -> void:
	if not is_instance_valid(world) or world.ended or world.paused:return
	if Alert.activate(world):
		activated.emit()
		flash_left=1.2
		_play_alert_sound()

func _process(delta: float) -> void:
	if not is_instance_valid(world):return
	var s:=Alert.state(world)
	var running:=float(s.left)>0.0
	var charge:=int(s.charge)
	var threat:=float(s.threat)
	var ready:=charge>0 and not running
	if appeared and ready and not was_ready:_play_alert_sound()
	was_ready=ready
	appeared=true
	disabled=world.ended or world.paused or get_tree().paused or running or not ready
	if threat_bar!=null:
		threat_bar.time_fraction=clampf(float(s.left)/Alert.DURATION,0.0,1.0) if running else -1.0
		threat_bar.maximum=Alert.threshold(s)
		threat_bar.value=threat_bar.maximum if running or ready else threat
		threat_bar.tooltip_text="总攻剩余时间：左侧圆环亮灯逐格熄灭" if running else "警戒值积累，满格可发动总攻"
		threat_bar.queue_redraw()
	clock+=delta
	flash_left=maxf(0.0,flash_left-delta)
	if glow!=null:
		glow.modulate.a=(0.35+0.25*sin(clock*3.0)) if flash_left>0.0 or running or ready else (0.42 if is_hovered() and not disabled else 0.0)
	reveal = move_toward(reveal, 1.0 if ready else 0.0, delta * 3.8)
	position.y = lerpf(42.0, 0.0, 1.0 - pow(1.0 - reveal, 3.0))
	modulate = Color(1, 1, 1, reveal)
	mouse_filter = Control.MOUSE_FILTER_STOP if ready and reveal > 0.95 else Control.MOUSE_FILTER_IGNORE

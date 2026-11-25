class_name Ra2Fx
extends Node2D
## RA2 攻击特效播放器：把 art.ini 动画 SHP（武器 Anim= 炮口火光 / 弹头 AnimList= 命中动画 /
## 弹道 Image= 可见弹体）按 Rate（本工程换算为 fps）逐帧播放。
##
## 素材：res://assets/ra2/fx/<IMAGE>.png + .json（ANIM.PAL 上色）。
## 抽取时已把每帧裁到【全动画并集包围盒】，因此 cell 中心 == 动画内容中心，
## 把 cell 居中画在目标像素上，就与 RA2「动画居中于炮口/落点」一致。
##
## 语义依据（rules.ini / art.ini 为唯一事实源）：
##   [Weapon]   Anim=      炮口火光，最多 8 项按炮塔朝向取（N=0 顺时针）；Bright= 发光 → 叠加混合
##   [Warhead]  AnimList=  命中动画，按【伤害】选档：索引 = clamp(floor(damage/25), 0, n-1)
##                          （第 8 批修正：旧实现是「列表里随机取一项」，与 RA2 不符）
##   [Projectile] Image=   可见弹体外形的动画/单帧 SHP

const NOMINAL_FPS := 15.0
# One immutable blend resource for all bright animation instances.
static var _additive_material:CanvasItemMaterial

static func additive_material() -> CanvasItemMaterial:
	if _additive_material==null:
		_additive_material=CanvasItemMaterial.new()
		_additive_material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	return _additive_material


var anim: Dictionary = {}
var frame: int = 0
var fps: float = NOMINAL_FPS
var bright: bool = false
var node_scale: float = 1.0
var tint: Color = Color.WHITE
var draw_offset := Vector2.ZERO # visual height; fog still checks ground origin

var _age: float = 0.0

## Fire-and-forget callers can batch tiny rifle flashes without changing play() handles.
static func play_transient(host: Node, pos: Vector2, image: String, px_scale: float = 1.0, is_bright: bool = false) -> bool:
	if host == null or image.is_empty(): return false
	var batch = preload("res://scripts/core/rifle_fx_batch.gd")
	if not batch.supports(image.to_upper()): return play(host, pos, image, px_scale, is_bright) != null
	var anim := RA2Art.fx(image)
	if anim.is_empty(): return false
	batch.emit(host, pos, anim, px_scale, is_bright)
	var sound := str(anim.get("sound", ""))
	if not sound.is_empty(): Ra2Sfx.play(sound, pos)
	return true

## 在世界坐标 pos 播放一次动画；无素材时返回 null（调用方回退程序化特效）
static func play(host: Node, pos: Vector2, image: String, px_scale: float = 1.0, is_bright: bool = false) -> Node:
	if host == null or image == "":
		return null
	var m: Dictionary = RA2Art.fx(image)
	if m.is_empty():
		return null
	var f := Ra2Fx.new()
	f.anim = m
	f.fps = maxf(1.0, float(m.get("fps", NOMINAL_FPS)))
	f.node_scale = px_scale
	f.bright = is_bright
	f.position = pos
	f.z_as_relative = false
	f.z_index = DepthLayers.FX + 1   # 绝对层级：特效恒在实体之上（不带相对父节点）
	if is_bright:
		f.material = additive_material()
	host.add_child(f)
	f.queue_redraw()
	# 命中/爆炸冲击音：art.ini StartSound=（缺省回退 Report=），由 sfx_build 抽取到 sound_specs。
	# 只在新动画生成时播一次，避免逐帧重复。
	var snd := str(m.get("sound", ""))
	if snd != "" and Ra2Sfx != null:
		Ra2Sfx.play(snd, pos)
	return f

## 随机取一项。RA2 里只有 EMEffect=yes 的弹头才是随机；其余一律走 play_impact()。
static func play_any(host: Node, pos: Vector2, images: Array, px_scale: float = 1.0, is_bright: bool = false) -> Node:
	if images == null or images.is_empty():
		return null
	var pick := str(images[randi() % images.size()])
	return play(host, pos, pick, px_scale, is_bright)

## 弹着表现（第 8 批，统一入口）：AnimList 按伤害选档 + Sparky 火花 + Bright 闪光。
## 返回是否播放了动画；没有素材时返回 false，由调用方回退程序化特效。
static func play_impact(host: Node, warhead_id: String, damage: float, pos: Vector2) -> bool:
	if host == null or warhead_id == "" or not Ra2Damage.has(warhead_id):
		return false
	var bright := Ra2Damage.is_bright(warhead_id)
	var anim := Ra2Damage.pick_impact_anim(warhead_id, damage)
	var played := false
	if anim != "":
		played = play_transient(host, pos, anim, 1.0, bright)
	if Ra2Damage.is_sparky(warhead_id):
		Effects.spawn_sparks(pos, clampi(int(damage / 12.0), 3, 14))
	if bright and damage >= 50.0:
		Effects.spawn_flash(pos, 16.0 + minf(damage, 400.0) * 0.05)
	return played

## 地面灼痕（第 8 批）：由 [Warhead] Deform= / DeformThreshhold= 决定。
## 贴花层按需创建并挂在 host 下，z_index = DepthLayers.DECAL（贴地、低于一切实体）。
static func spawn_scorch(host: Node, warhead_id: String, damage: float, pos: Vector2) -> void:
	if host == null or warhead_id == "":
		return
	if not Ra2Damage.should_deform(warhead_id, damage):
		return
	var layer: Node = host.get_node_or_null("__decals")
	if layer == null:
		var d := DecalLayer.new()
		d.name = "__decals"
		d.z_as_relative = false
		d.z_index = DepthLayers.DECAL    # 绝对层级：贴花贴地，低于一切实体
		host.add_child(d)
		layer = d
	layer.call("add_scorch", pos, Ra2Damage.deform_radius_px(warhead_id), clampf(damage / 400.0, 0.25, 1.0))

## 8 向炮口火光选择：RA2 的 Anim= 列表顺序为 N, NE, E, SE, S, SW, W, NW。
## screen_dir 是【绘制空间（屏幕）】方向（引擎里炮塔角度就在这个空间）。
static func pick_directional(images: Array, screen_dir: Vector2) -> String:
	if images.is_empty():
		return ""
	if images.size() < 8:
		return str(images[0])
	var d := screen_dir
	if d.length() < 0.001:
		d = Vector2(0.0, -1.0)
	var idx := int(round((rad_to_deg(d.angle()) + 90.0) / 45.0))
	idx = ((idx % 8) + 8) % 8
	return str(images[idx])

func start_at_frame(first: int) -> void:
	frame = clampi(first, 0, int(anim.count) - 1)
	_age = frame / fps
	queue_redraw()

func _process(delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(38)
	if anim.is_empty():
		queue_free()
		return
	_age += delta
	var n := int(anim.get("count", 1))
	var f := int(floor(_age * fps))
	if f >= n:
		queue_free()
		return
	if f != frame:
		frame = f
		queue_redraw()

func _draw() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(39)
	if anim.is_empty():
		return
	Iso.begin(self)
	var tex: Texture2D = anim.get("tex")
	if tex == null:
		return
	var cell: Vector2 = anim.get("cell", Vector2.ZERO)
	var src: Rect2 = RA2Art.fx_rect(anim, frame)
	if src.size == Vector2.ZERO and cell != Vector2.ZERO:
		src = Rect2(Vector2.ZERO, cell)
	var sz := cell * node_scale
	draw_texture_rect_region(tex, Rect2(draw_offset - sz * 0.5, sz), src, tint)

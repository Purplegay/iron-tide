extends Node2D
class_name ResourceNode
## 地表矿石与宝石。采集车会往返于此。
##
## RA2/YR TIB/GEM 是可通行的地表覆盖层，不是实体障碍。
## radius 仍用于绘制、采集拾取和禁止建筑覆盖矿区，不生成物理碰撞体。
##
## RA2 ore growth is advanced centrally by EconomyCycle. Extension mode keeps
## its linear refill economy. Gems are finite in both modes.
##
## Original TIB/GEM overlays: 12 density frames, three local variants.
## Quantities, regeneration and existing collection/path contracts are unchanged.

var amount: float = 6000.0:
	set(value):
		var threshold := 0.5 if BattleRequest.extensions_enabled() else 0.000001
		var changed := (amount <= threshold) != (value <= threshold)
		amount = value
		if changed and is_inside_tree() and get_parent() is Battle:
			get_parent().radar_ore_revision += 1
var resource_kind := "ore"
var max_amount: float = 6000.0
var radius: float = 34.0:
	set(value):
		radius = value
		# Save restoration applies fields after the node enters the battle.
		if is_inside_tree():
			var world := get_parent() as Battle
			if world != null:
				world.ore_neighborhood.max_unit_radius = maxf(world.ore_neighborhood.max_unit_radius, radius)
## Existing adapter: ordinary ore takes about 50 seconds to refill from empty.
const REGEN_FRACTION := 0.02
var regen_rate: float = 0.0
var depleted: bool = false
var _ore_texture: Texture2D
var native_variant := -1
var _ore_variant := 1
var _drawn_frame := -2
var _drawn_radius := -1.0
## (M6) 矿点认领（弱引用）：采集车分流用，避免多车扎堆同一堆矿。车销毁后自动失效。
var _claim: WeakRef = null

func claim_by(u: Object) -> void:
	_claim = weakref(u)

func claim_release(u: Object) -> void:
	if _claim != null and _claim.get_ref() == u:
		_claim = null

## 是否已被「其它」采集车认领（自己认领返回 false）。
func claim_held_by(u: Object) -> bool:
	if _claim == null:
		return false
	var o: Object = _claim.get_ref()
	if o == null or not is_instance_valid(o):
		_claim = null
		return false
	return o != u

func claim_owner() -> Object:
	if _claim == null:
		return null
	var o: Object = _claim.get_ref()
	return o if is_instance_valid(o) else null

func _enter_tree() -> void:
	var world := get_parent() as Battle
	if world != null:
		world.radar_ore_revision += 1
		world.ore_neighborhood.register(self, radius, false)
		set_notify_local_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and is_inside_tree():
		var world := get_parent() as Battle
		if world != null:
			world.radar_ore_revision += 1
			world.ore_neighborhood.relocate(self)

func _exit_tree() -> void:
	var world := get_parent() as Battle
	if world != null:
		world.radar_ore_revision += 1
		world.ore_neighborhood.remove(self)

func _ready() -> void:
	add_to_group("resource_nodes")
	Events.view_changed.connect(func(_view): queue_redraw())
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var layout := BattleRequest.native_ore_map()
	if not layout.is_empty():
		preload("res://scripts/world/native_ore.gd").load_art(self, layout)
		regen_rate = 0
		set_process(false)
		return
	_ore_variant = 1 + posmod(int(position.x) * 31 + int(position.y) * 57, 3)
	_ore_texture = load("res://assets/ra2/resources/%s-%d.png" % [resource_kind, _ore_variant])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if regen_rate <= 0.0:
		regen_rate = max_amount * REGEN_FRACTION
	if resource_kind == "gems":
		regen_rate = 0.0

## 是否已被采空（采集车据此更换矿点）。
func is_empty() -> bool:
	return amount <= (0.5 if BattleRequest.extensions_enabled() else 0.000001)

func _process(delta: float) -> void:
	if delta <= 0.0 or get_parent().get("paused") == true or get_parent().get("ended") == true:
		return
	if BattleRequest.extensions_enabled() and amount < max_amount:
		amount = minf(max_amount, amount + regen_rate * delta)
		if amount > max_amount * 0.05:
			depleted = false
	if density_frame() != _drawn_frame or radius != _drawn_radius:
		queue_redraw()

func extract(v: float) -> float:
	var taken := minf(maxf(0.0, amount), maxf(0.0, v))
	amount = maxf(0.0, amount - taken)
	if amount <= 0.0:
		depleted = true
	if native_variant >= 0 and taken > 0: queue_redraw()
	return taken

func density_frame() -> int:
	if amount <= 0.000001:
		return -1
	if native_variant >= 0: return clampi(ceili(amount)-1, 0, 11)
	return clampi(ceili(amount / maxf(0.000001, max_amount) * 12.0) - 1, 0, 11)

func _draw() -> void:
	var frame := density_frame()
	_drawn_frame = frame
	_drawn_radius = radius
	if frame < 0 or _ore_texture == null:
		return
	# Overlay pixels already contain RA2's diamond projection. Cancel the camera's
	# ground shear before drawing, so the original 60x30 patch is not flattened twice.
	Iso.begin(self)
	if native_variant >= 0:
		var size_px := 55.0 * sqrt(2.0)
		draw_texture_rect_region(_ore_texture, Rect2(-size_px/2, -size_px*.75, size_px, size_px), Rect2(frame*60, native_variant*60, 60, 60))
		return
	var scale := radius / 34.2
	var source := Rect2(Vector2(frame % 6, frame / 6) * 60.0, Vector2(60, 60))
	draw_texture_rect_region(_ore_texture, Rect2(Vector2(-30, -45) * scale, Vector2(60, 60) * scale), source)

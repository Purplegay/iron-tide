extends RefCounted
const PATHS:Dictionary={
	"CLNT":"res://assets/ui/heroes/clint_icon.tres","ARND":"res://assets/ui/heroes/arnold_icon.tres","STLN":"res://assets/ui/heroes/stallone_icon.tres",
	"FV":"res://assets/ui/heroes/yinpian.png",
	"HARV":"res://assets/ui/heroes/laocheng.png",
	"E1": "res://assets/ui/heroes/e1.png",
	"E2": "res://assets/ui/heroes/e2.png",
	"MTNK": "res://assets/ui/heroes/mtnk.png",
	"HTNK": "res://assets/ui/heroes/htnk.png",
	"ORCA": "res://assets/ui/heroes/orca.png",
	"TTNK": "res://assets/ui/heroes/ttnk.png",
}
const DRIVER_IDS := ["MTNK", "HTNK", "ORCA", "TTNK", "FV", "HARV"]

const DRIVER_UNLOCK_HINT := "驾驶员头像 · 随这位英雄完成任意一章同行委托并获胜后解锁。"

static func switch_action(id: String) -> String:
	return "换用载具头像" if showing_driver(id) else "换用驾驶员头像"

static func driver_unlocked(id: String) -> bool:
	return id in DRIVER_IDS and not MetaProgress.hero_story_archive.get(id, {}).is_empty()

static func showing_driver(id: String) -> bool:
	return MetaProgress.driver_portraits.has(id) and driver_unlocked(id)

static func choose_driver(id: String, enabled: bool) -> bool:
	if not driver_unlocked(id):
		return false
	var previous := MetaProgress.driver_portraits.duplicate()
	if enabled:
		MetaProgress.driver_portraits[id] = true
	else:
		MetaProgress.driver_portraits.erase(id)
	if not MetaProgress.save():
		MetaProgress.driver_portraits = previous
		return false
	MetaProgress.hero_portrait_changed.emit()
	return true

# Hollywood portraits keep their cropped art and draw their caption at the final UI size.
static func draw_button_name(button: Button, id: String) -> void:
	var frame := button.get_theme_stylebox("normal")
	var width := float(button.get_theme_constant("icon_max_width"))
	var size := button.icon.get_size() * (width / button.icon.get_width())
	var top := (button.size.y - size.y) * 0.5
	draw_name(button, Rect2(Vector2(frame.get_margin(SIDE_LEFT), top), size), id)

static func draw_name(control: Control, rect: Rect2, id: String) -> void:
	var font := control.get_theme_font("font", "Label")
	var font_size := clampi(roundi(rect.size.y * 0.20), 8, 16)
	var height := ceilf(font.get_height(font_size))
	var strip := Rect2(Vector2(rect.position.x, rect.end.y - height), Vector2(rect.size.x, height))
	control.draw_rect(strip, Color(0.02, 0.025, 0.03, 0.94))
	var baseline := strip.position + Vector2(0, font.get_ascent(font_size))
	control.draw_string(font, baseline, MetaProgress.Academy.HEROES[id], HORIZONTAL_ALIGNMENT_CENTER, strip.size.x, font_size, Color.WHITE)

static var cache:Dictionary={}
static func texture(id:String) -> Texture2D:
	if not MetaProgress.Academy.HEROES.has(id):return null
	var path:String=str(PATHS.get(id,GameData.ra2_cameo_path(id)))
	if showing_driver(id):path = path.get_basename() + "-driver.png"
	if path.is_empty():return null
	if not cache.has(path):cache[path]=load(path)
	return cache[path]

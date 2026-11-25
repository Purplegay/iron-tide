extends RefCounted
const PATHS:Dictionary={
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

static var cache:Dictionary={}
static func texture(id:String) -> Texture2D:
	if not MetaProgress.Academy.HEROES.has(id):return null
	var path:String=str(PATHS.get(id,GameData.ra2_cameo_path(id)))
	if showing_driver(id):path = path.get_basename() + "-driver.png"
	if path.is_empty():return null
	if not cache.has(path):cache[path]=load(path)
	return cache[path]

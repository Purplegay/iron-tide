extends RefCounted
## 播放资源与收藏目录共用同一份影片清单。

const FIRST_UNLOCK_REWARD := {"diamonds":5, "war_points":25, "credits":150}

static func reward_text() -> String:
	return "钻石 +%d · 战略点 +%d · 军需券 +%d" % [
		FIRST_UNLOCK_REWARD.diamonds, FIRST_UNLOCK_REWARD.war_points, FIRST_UNLOCK_REWARD.credits]

const GROUPS := [
	{"faction":"allied", "chapter":"01", "title":"时间流逝", "folder":"allied_first", "clips":[
		["A01_F00E", "出击简报", "进入《时间流逝》"],
		["A01_P01E", "伊娃的战场简报", "在旧金山接到伊娃的通讯"],
		["A01_P02E", "时间转移", "时光机恢复供电，准备出发"],
		["A01_P03E", "抵达过去", "穿越成功后收到谭雅的通讯"],
	]},
	{"faction":"allied", "chapter":"07", "title":"脑死", "folder":"allied_finale", "clips":[
		["A07_F00E", "出击简报", "进入《脑死》"],
		["A07_P01E", "火地岛作战简报", "接到伊娃的战场简报"],
		["A08_F00E", "盟军结局", "赢得《脑死》"],
	]},
	{"faction":"allied", "chapter":"02", "title":"好莱坞梦一场", "folder":"hollywood", "clips":[
		["A02_F00E", "出击简报", "进入《好莱坞梦一场》"],
		["A02_P01E", "机场报告", "接到机场附近的基地车报告"],
		["A02_P02E", "部队回收厂", "收到伊娃关于部队回收厂的通报"],
		["A02_P03E", "卡维利的通讯", "在好莱坞找到克林特后收到卡维利的通讯"],
	]},
	{"faction":"soviet", "chapter":"01", "title":"时空转移", "folder":"time_shift", "separate_audio":true, "clips":[
		["S01_F00E", "出击简报", "进入《时空转移》"],
		["S01_P01E", "索菲亚的战场简报", "接到夺取时光机的战场简报"],
		["S01_P02E", "第一次穿越", "启动时光机并完成第一次穿越"],
		["S01_P03E", "第二次穿越", "再次启动时光机，抵达目标时代"],
	]},
	{"faction":"soviet", "chapter":"07", "title":"首脑游戏", "folder":"head_games", "clips":[
		["S07_F00E", "出击简报", "进入《首脑游戏》"],
		["S07_P01E", "要塞与心灵信标", "接到索菲亚的要塞简报"],
		["S07_P02E", "尤里的警告", "在普通或困难难度建成核弹井或铁幕，等尤里建成基因突变器并播出影片。开头的语音挑衅不算。"],
		["S08_F00E", "苏军结局", "赢得《首脑游戏》"],
	]},
]

## 按所属关卡排序，不按影片编号（例如 A08 是第 07 关的结局）。
static func groups_for_faction(faction: String) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for group in GROUPS:
		if group.faction == faction:
			groups.append(group)
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.chapter) < int(b.chapter))
	return groups

static func media(id: String) -> Dictionary:
	for group in GROUPS:
		for clip in group.clips:
			if clip[0] == id:
				var base := "res://assets/ra2/%s/%s" % [group.folder,id]
				if id == "A01_P01E": return {"video":base+".ogv", "audio":"res://assets/ra2/allied_first/a01_p01.wav"}
				return {"video":base+".ogv", "audio":"res://assets/ra2/sfx/allied_finale/a07_p01.wav" if id=="A07_P01E" else (base+".ogg" if group.get("separate_audio",false) else "")}
	return {}

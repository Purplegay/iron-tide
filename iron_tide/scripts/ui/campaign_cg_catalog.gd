extends RefCounted
## 播放资源与收藏目录共用同一份影片清单。

const FIRST_UNLOCK_REWARD := {"diamonds":5, "war_points":25, "credits":150}

static func reward_text() -> String:
	return "钻石 +%d · 战略点 +%d · 军需券 +%d" % [
		FIRST_UNLOCK_REWARD.diamonds, FIRST_UNLOCK_REWARD.war_points, FIRST_UNLOCK_REWARD.credits]

const GROUPS := [
	{"faction":"allied", "chapter":"02", "title":"好莱坞梦一场", "folder":"hollywood", "clips":[
		["A02_F00E", "出击简报", "进入《好莱坞梦一场》"],
		["A02_P01E", "机场报告", "接到机场附近的基地车报告"],
		["A02_P02E", "部队回收厂", "收到伊娃关于部队回收厂的通报"],
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
		["S07_P02E", "尤里的警告", "在战场收到尤里的警告"],
		["S08_F00E", "苏军结局", "赢得《首脑游戏》"],
	]},
]

static func media(id: String) -> Dictionary:
	for group in GROUPS:
		for clip in group.clips:
			if clip[0] == id:
				var base := "res://assets/ra2/%s/%s" % [group.folder,id]
				return {"video":base+".ogv", "audio":base+".ogg" if group.get("separate_audio",false) else ""}
	return {}

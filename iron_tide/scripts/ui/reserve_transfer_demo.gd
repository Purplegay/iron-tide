extends RefCounted
## Examples use the displayed rank-three native reserve, not the player's loadout.
const LENGTH:=24.0

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/8)
	var local:=fposmod(t,8)
	var reserve:Dictionary=MetaProgress.talent_options("SHK").tesla_reserve
	var layer:float=reserve.ranks[2].value
	var interval:float=reserve.intervals[3]
	var original:float=layer*int(reserve.stack_limits[3])
	var fraction:float=MetaProgress.talent_options("SHK").reserve_transfer.values.damage[rank]
	var carry:=original*fraction
	var release:float=[7.0,1.5,4.5][part]
	var fresh:float=mini(int(reserve.stack_limits[3]),floori((release-1)/interval))*layer
	var used:=maxf(carry,fresh)
	var stored:=local>=1 and local<release
	var natural:float=original if local<1 else mini(int(reserve.stack_limits[3]),floori((minf(local,release)-1)/interval))*layer
	var title:String=["储存无到期 · 新蓄电更强","尽早再开火 · 使用转储","自然与转储 · 只取较强值"][part]
	var text:="满层普通主电击击杀 · 只保留额外增伤"
	if stored:text="储存 +%.0f%% · 无到期计时 · 新蓄电 +%.0f%%"%[carry,natural]
	elif local>=release:text="本次采用 +%.0f%% · 击杀也不再转储"%used
	return {"time":t,"local":local,"part":part,"active":stored,"value":fraction*100,"charges":0,"original":original,"carry":carry,"stored":carry if stored else 0.,"natural":natural,"fresh":fresh,"used":used,"release":release,"title":title,"text":text}

static func draw(view,origin:Vector2,s:Dictionary) -> void:
	var first:Vector2=view.MAIN_POINT
	var next:=first+Vector2(-40,50)
	view.draw_string(ThemeDB.fallback_font,Vector2(10,18),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	view.draw_string(ThemeDB.fallback_font,Vector2(10,35),"停火蓄电3级示例：+%.0f%% × %.0f%% = 储存+%.0f%%"%[s.original,s.value,s.carry],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.SKY_BLUE)
	view.draw_circle(first,8,Color.SALMON if s.local<1 else Color.DIM_GRAY)
	view.draw_circle(next,8,Color.SALMON if s.local<s.release else Color.DIM_GRAY)
	for item in [[1.0,first],[s.release,next]]:
		if s.local>=item[0] and s.local<item[0]+.2:view.draw_line(origin,item[1],Color.GOLD,3,true)
		if s.local>=item[0]:
			view.draw_line(item[1]-Vector2(6,6),item[1]+Vector2(6,6),Color.ORANGE,2)
			view.draw_line(item[1]-Vector2(-6,6),item[1]+Vector2(-6,6),Color.ORANGE,2)
	if s.active:view.draw_arc(origin,25,0,TAU,32,Color.GOLD,2,true)
	view.draw_string(ThemeDB.fallback_font,origin+Vector2(-45,30),"当前储存 +%.0f%%"%s.stored,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GOLD)
	if s.local>=s.release:
		view.draw_string(ThemeDB.fallback_font,Vector2(10,125),"本次发射前：转储%.0f%% / 新蓄电%.0f%% → 实际%.0f%%"%[s.carry,s.fresh,s.used],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)

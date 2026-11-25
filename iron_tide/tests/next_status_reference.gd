extends RefCounted
const STATUS_REFERENCES = [["temporal_by","超时空抹除","正在被超时空单位抹除","hourglass"],["controller","心灵控制","受敌方心灵控制","focus"],["parasite","寄生","被恐怖机器人寄生","attack"],["squid","乌贼缠绕","正在被乌贼缠绕","naval"]]
const STACK_ICONS = {"蓄电":"spark","扩散":"rad_growth","主热":"attack","副热":"split","稳流":"ps_phase"}
const HIT_LABELS = {"Echo":"炮击重演","Flux":"稳流命中","Tag":"目标标记","Ping":"航标通报","Burst":"强化命中"}
const BUFF_ICONS = {"cooldown":"reload","regen":"heal","dodge":"smoke","stun":"electric","tesla_emp":"electric","defense":"guard","crit":"focus","accuracy":"focus"}
## Read-only adapter shared by world markers, HUD cells and tooltips.
const Icons=preload("res://scripts/ui/progression_icon.gd")
const Stacks=preload("res://scripts/ui/talent_stack_indicator.gd")
const TIMERS={
	"chrono_left":["超时空恢复","暂时无法行动","hourglass"],
	"iron_left":["铁幕","铁幕防护生效","guard"],
	"blackout":["断电","电子设备暂时离线","electric"],
	"c4_left":["C4 炸药","倒计时结束后爆破","explosive"],
	"slope_left":["斜面突进","正面防护与起步加速","ap_slope"],
	"buoy_left":["搜索浮标","搜索范围内潜艇","ap_buoy"],
	"contact_left":["航标通报","共享被标记目标视野","ps_contact"],
	"echo_left":["镜像诱饵","临时诱饵仍在场","ap_decoy"],
	"echo_cloaked":["折光隐身","隐身期间按原规则解除","ap_decoy"],
	"twin_left":["双炮窗口","双炮强化窗口生效","ap_twin"],
	"squid_suppression":["乌贼压制","被压制期间不能正常攻击","naval"],
}

static func row(id:String,name:String,text:String,icon:String,left:=0.0,debuff:=false,stacks:=-1,limit:=0) -> Dictionary:
	return {"id":id,"kind":id,"name":name,"text":text,"icon":icon,"left":left,"dur":maxf(left,1),"timed":left>0,"stacks":stacks,"limit":limit,"col":Color.TOMATO if debuff else Color.CYAN,"col2":Color.TRANSPARENT,"debuff":debuff}

static func append_native(unit,out:Array) -> void:
	var s:Dictionary=unit.special
	if unit.hold_position:out.append(row("hold_position","固守","保持当前位置，不主动追击","guard"))
	if unit._deployed:out.append(row("deployed","部署形态","当前处于部署姿态","defense"))
	if s.get("echo_cloaked",false):out.append(row("echo_cloak","折光隐身","隐身期间按原技能规则解除","smoke",float(s.get("echo_bonus_left",0))))
	for key in TIMERS:
		if not s.has(key) or not s[key] is float and not s[key] is int:continue
		if float(s[key])<=0:continue
		var spec:Array=TIMERS[key]
		out.append(row(key,spec[0],spec[1],spec[2],float(s[key]),key in ["chrono_left","blackout","c4_left","squid_suppression"]))
	for spec in STATUS_REFERENCES:
		if AlliedAbilities.alive(s.get(spec[0])):out.append(row(spec[0],spec[1],spec[2],spec[3],0,true))
	if s.has("ivan_bomb"):out.append(row("ivan_bomb","伊万炸弹","炸弹到期爆炸，可由工程师拆除","explosive",float(s.ivan_bomb.left),true))
	if s.has("hero_wreck"):out.append(row("hero_wreck","等待复活","英雄残骸，战斗天赋暂停","heart",float(s.hero_wreck.get("left",0))))
	if s.has("furnace_prone"):
		var detail:="卧倒火力与护盾生效"
		if unit.side=="ally":detail+="；当前护盾 %.0f"%s.furnace_prone.hp
		out.append(row("furnace_prone","金鳞战垒",detail,"ap_furnace_bastion",float(s.furnace_prone.left)))
	var shield:Dictionary=s.get("hero_stationary_shield",{})
	if float(shield.get("hp",0))>0:out.append(row("hero_stationary_shield","重装护盾","当前护盾 %.0f"%shield.hp if unit.side=="ally" else "护盾生效","guard",float(shield.get("left",0))))
	if s.has("furnace_flak_life"):out.append(row("furnace_flak_life","龙卫截空","临时防空护卫，生命随时间衰减","ps_furnace_flak",maxf(0,float(s.furnace_flak_life.life)-float(s.furnace_flak_life.age))))
	var domain:Dictionary=s.get("domain_card",{})
	if domain.has("active"):
		var card:=GameData.get_skill(domain.active)
		out.append(row("domain_active",str(card.name),str(card.desc),str(card.id),float(domain.left)))
	if float(domain.get("charge",0))>0:
		var card:=GameData.get_skill(unit.passive.get("id",""))
		out.append(row("domain_charge",str(card.get("name","蓄能")),"蓄能 %.1f / 2 秒"%domain.charge,str(card.get("id","reload"))))
	for layer in Stacks.rows(unit):
		var icon:String=STACK_ICONS.get(layer.label,"rank")
		out.append(row("stack_"+layer.label,layer.label,"当前目标的叠层；随真实战斗状态更新",icon,0,false,layer.count,layer.limit))
	if unit._stun_timer>0 and not unit.has_buff("stun") and not unit.has_buff("tesla_emp"):out.append(row("stun","眩晕","暂时无法行动","electric",unit._stun_timer,true))
	if unit._back_in:out.append(row("reverse","倒车","保持朝向倒车移动","reverse"))
	for ability in unit.skills:
		if not ability.is_active():continue
		var present:=false
		for e in out:
			if e.get("name","")==ability.display_name or e.get("icon","")==ability.id:present=true;break
		if not present:out.append(row("active_"+ability.id,ability.display_name,ability.desc,ability.id,ability.active_left))
	for key in unit.get_meta_list():
		if not str(key).begins_with("faction_hit_") and key not in [&"reaper_heat_fx",&"reaper_split_fx"]:continue
		var effect=unit.get_meta(key)
		if not is_instance_valid(effect) or effect.is_queued_for_deletion():continue
		var label:String=HIT_LABELS.get(effect.card_label,"分射命中" if key==&"reaper_split_fx" else "热量命中")
		out.append(row(str(key),label,"刚受到对应技能命中","attack",maxf(0,effect.LIFETIME-effect.age),true,effect.stacks))

static func normalize(entries:Array) -> Array:
	var out:Array=[]
	var used:Dictionary={}
	for raw in entries:
		var e:Dictionary=raw.duplicate()
		var id:String=str(e.get("id",e.get("kind","status")))
		var occurrence:int=int(used.get(id,0));used[id]=occurrence+1
		e.id=id if occurrence==0 else id+"_"+str(occurrence)
		e.icon=e.get("icon",BUFF_ICONS.get(e.get("kind",""),e.get("kind","spark")))
		e.stacks=int(e.get("stacks",-1));e.limit=int(e.get("limit",0))
		e.timed=e.get("timed",float(e.get("left",0))>0)
		out.append(e)
	return out

static func tooltip(e:Dictionary) -> String:
	var text:=str(e.get("name","状态"))
	var detail:=str(e.get("text",""))
	if detail!=text and not detail.is_empty():text+="\n"+detail
	if int(e.get("stacks",-1))>=0:
		text+="\n层数：%d"%int(e.stacks)
		if int(e.get("limit",0))>0:text+=" / %d"%int(e.limit)
	if e.get("timed",false):text+="\n剩余：%.1f 秒"%BattleClock.real_seconds(maxf(0,float(e.get("left",0))))
	else:text+="\n持续至触发条件结束"
	return text

static func draw_world(unit,canvas:CanvasItem,origin:Vector2) -> void:
	var entries:Array=unit.buff_entries()
	if entries.is_empty():return
	var count:=mini(entries.size(),6)
	var bar:Rect2=unit.hp_bar_rect()
	var start:Vector2=origin+Vector2(bar.position.x-5-12-(count-1)*14,bar.get_center().y-6)
	for i in count:
		var e:Dictionary=entries[i]
		var rect:=Rect2(start+Vector2(i*14,0),Vector2(12,12))
		canvas.draw_rect(rect.grow(1),Color("#101b26"))
		canvas.draw_texture_rect(Icons.texture(str(e.icon)),rect,false)
		if e.get("debuff",false):canvas.draw_rect(rect,Color.TOMATO,false,1)
		var number:=""
		if i==5 and entries.size()>6:number="+%d"%(entries.size()-5)
		elif int(e.stacks)>=0:number=str(e.stacks)
		if not number.is_empty():
			var pos:=rect.end+Vector2(-6,0)
			canvas.draw_string_outline(ThemeDB.fallback_font,pos,number,HORIZONTAL_ALIGNMENT_LEFT,-1,8,2,Color.BLACK)
			canvas.draw_string(ThemeDB.fallback_font,pos,number,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color.WHITE)

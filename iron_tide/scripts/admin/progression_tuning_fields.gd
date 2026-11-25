extends RefCounted
const LABELS:={"value":"基础效果值","base":"0级效果值","damage":"伤害系数","defense":"减伤比例","shield":"护盾比例","hits":"命中次数","count":"数量","shots":"发射次数","targets":"额外目标数","radius":"范围","duration":"持续时间","cooldown":"冷却秒数","cooldown_by_rank":"冷却秒数","strength_by_rank":"等级强度倍率","intervals":"触发间隔秒数","stack_limits":"层数上限","prepare":"准备秒数","reload":"装填缩短比例","sight":"视野增加格数","slow":"减速比例","speed":"移速比例","chance":"触发概率","heal":"治疗比例","range":"范围","delay":"延迟秒数"}
const COUNTS:=["hits","count","shots","targets","bounces","stack_limits","twin_hits","objective_by_rank"]
const FRACTIONS:=["defense","slow","chance","reload","shield","heal"]
const RELAY_LABELS:={"relay_cap":"余波储量上限／施法舰生命比例","relay_duration":"余波护盾持续秒数"}
const EXTRA_LABELS:={"attack":"攻击加成","attack_by_rank":"攻击倍率","blast":"爆炸系数","branch_by_rank":"副攻击系数","burst_by_rank":"爆发系数","cap":"上限","cloak":"隐形秒数","contact_cooldowns":"标记冷却秒数","contact_seconds":"标记秒数","cooldown_reduction":"冷却缩短比例","dive":"潜航秒数","drive_seconds":"行驶秒数","echo_seconds":"回响秒数","guard":"保护效果","heal_seconds":"治疗秒数","hp":"生命比例","hp_by_rank":"生命比例","idle":"静止秒数","interval":"间隔秒数","life":"持续秒数","life_by_rank":"持续秒数","lock":"锁定秒数","objective_by_rank":"目标次数","primary_bonus_by_rank":"主攻击加成","pulse":"脉冲效果","rof_by_rank":"攻速比例","shield_by_rank":"护盾比例","speed_by_rank":"移速比例","speed_time":"移速持续秒数","swap":"切换效果","trigger_interval":"触发间隔秒数","twin_extra_chance":"追加发射概率","twin_hits":"强化发数","twin_windows":"强化窗口秒数"}

static func collect(definition:Dictionary) -> Array:
	var result:Array=[]
	if definition.has("parameter_fields"):
		for key:String in definition.parameter_fields:
			var field:Dictionary=definition.parameter_fields[key].duplicate(true)
			field.path="values/"+key
			field.value=definition.values[key]
			result.append(field)
		return result
	walk(definition,"",result)
	return result

static func walk(value:Variant,path:String,out:Array) -> void:
	if value is Dictionary:
		for key in value:
			if key in ["version","cost","price","unlock_cost","icon","rarity_weight"]:continue
			if path.is_empty() and key=="value" and value.get("expansion",false):continue # Expansion effects consume named values, not this unused placeholder.
			if path.is_empty() and key in ["base","ranks"] and value.has("values"):continue # Derived talent labels, not gameplay inputs.
			walk(value[key],str(key) if path.is_empty() else path+"/"+str(key),out)
	elif value is Array:
		for i in value.size():walk(value[i],path+"/"+str(i),out)
	elif value is float or value is int:
		var parts:=path.split("/")
		var semantic:=parts[0]
		if semantic=="values" and parts.size()>1:semantic=parts[1]
		var integer:bool=semantic in COUNTS
		var minimum:=1.0 if (integer and value>0) or semantic=="prepare" else minf(0,float(value))
		if "cooldown" in semantic or semantic=="intervals":minimum=.1 if value>0 else 0.0
		if semantic in ["life","life_by_rank","charge_seconds","linger"] and value>0:minimum=.05
		var maximum:=maxf(10000,float(value))
		if semantic in FRACTIONS and float(value)<=1:maximum=.95 if semantic in ["defense","reload","slow"] else 1.0
		var label:String=LABELS.get(semantic,EXTRA_LABELS.get(semantic,RELAY_LABELS.get(semantic,semantic)))
		if semantic=="power":label="原生机制强度倍率"
		if parts[-1].is_valid_int():label+=" · Lv."+parts[-1]
		elif parts[0]=="ranks" and parts.size()>2:label="效果值 · Lv."+str(int(parts[1])+1)
		var hint:="原始配置单位；比例0.2表示20%，倍率1表示100%。范围以参数原有单位为准。"
		if semantic=="radius":hint="普通技能radius使用世界坐标像素；values/radius使用该技能说明中的格数。1格=55像素。"
		out.append({"path":path,"label":label,"value":value,"minimum":minimum,"maximum":maximum,"integer":integer,"step":1.0 if integer else .001,"hint":hint})

static func read(root:Variant,path:String) -> Variant:
	var current:Variant=root
	for part in path.split("/"):current=current[int(part)] if current is Array else current[part]
	return current

static func write(root:Variant,path:String,value:float) -> void:
	var parts:=path.split("/");var current:Variant=root
	for i in parts.size()-1:current=current[int(parts[i])] if current is Array else current[parts[i]]
	if current is Array:current[int(parts[-1])]=value
	else:current[parts[-1]]=value

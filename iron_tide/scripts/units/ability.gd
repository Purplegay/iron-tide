extends RefCounted
class_name Ability
## 单位技能运行时（红警3 式）。
## 一个 Ability 实例承载一份技能数据的运行时状态：冷却、持续时间、激活标记。
## 数值/效果全部数据驱动，effect 为 "attack_buff"、"heal"、"stun" 等 token，
## 多个 token 用 "+" 连接（如 "attack_buff+defense_buff"）。

var id: String = ""
var display_name: String = ""
var desc: String = ""
var effect: String = ""
var cooldown: float = 10.0
var duration: float = 0.0
var value: float = 0.0
var radius: float = 0.0
var target: String = "self"

var cd_left: float = 0.0
var active_left: float = 0.0

var _effects: PackedStringArray = PackedStringArray()


static func cooldown_text(seconds:float) -> String:
	return String.num(seconds,1).trim_suffix(".0")

static func cooldown_at_rank(definition:Dictionary, rank:int) -> float:
	var ranks:Array=definition.get("cooldown_by_rank",[])
	if not ranks.is_empty(): return float(ranks[clampi(rank,0,ranks.size()-1)])
	return maxf(0.2,float(definition.get("cooldown",10.0)))

func setup(p_def: Dictionary, rank:int=0) -> void:
	id = str(p_def.get("id", ""))
	display_name = str(p_def.get("name", id))
	desc = str(p_def.get("desc", ""))
	if p_def.get("expansion",false):desc=preload("res://scripts/rules/expansion_catalog.gd").description(p_def,rank)
	effect = str(p_def.get("effect", ""))
	cooldown = cooldown_at_rank(p_def,rank)
	duration = maxf(0.0, float(p_def.get("duration", 0.0)))
	value = float(p_def.get("value", 0.0))
	radius = maxf(0.0, float(p_def.get("radius", 0.0)))
	target = str(p_def.get("target", "self"))
	_effects = PackedStringArray()
	for token in effect.split("+", false):
		var t := token.strip_edges()
		if t != "":
			_effects.append(t)


func effects() -> PackedStringArray:
	return _effects


func effect_has(p_token: String) -> bool:
	return _effects.has(p_token)


func is_instant() -> bool:
	## 即时效果（治疗 / 瘫痪）不需要持续时间。
	return effect_has("heal") or effect_has("stun")


func tick(p_delta: float) -> void:
	if cd_left > 0.0:
		cd_left = maxf(0.0, cd_left - p_delta)
	if active_left > 0.0:
		active_left = maxf(0.0, active_left - p_delta)


func ready() -> bool:
	return cd_left <= 0.0


func is_active() -> bool:
	return active_left > 0.0


func cd_frac() -> float:
	return clampf(cd_left / maxf(0.01, cooldown), 0.0, 1.0)


func trigger_cooldown(p_scale: float = 1.0) -> void:
	## p_scale > 1 表示冷却缩短（局外技能强化带来的冷却收益）。
	var s := maxf(0.5, p_scale)
	cd_left = cooldown / s
	active_left = duration

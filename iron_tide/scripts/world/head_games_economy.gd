extends RefCounted

const ID := "yr_head_games"
const ACCOUNTS := ["s07_yuri", "s07_soviet", "s07_allied"]

static func initialize(world, legacy := false) -> void:
	if world.allied_state.has("s07_accounts"): return
	# Retail BadGuy1/2/3 each have Credits=400 (hundreds).
	var opening:float = maxf(0.0,world.enemy_funds)/3.0 if legacy else 40000.0
	world.allied_state.s07_accounts={}
	for key in ACCOUNTS: world.allied_state.s07_accounts[key]=opening
	world.enemy_funds=0.0

static func account(wing:int) -> String:
	return ACCOUNTS[clampi(wing+1,0,2)]

static func owner(world, actor) -> String:
	if actor.side=="enemy" and world.mission.get("id")==ID:
		return account(int(actor.special.get("head_games_wing",-1)))
	return actor.side

static func same_refinery_house(world, miner, refinery) -> bool:
	if refinery.side!=miner.side: return false
	return world==null or owner(world,miner)==owner(world,refinery)

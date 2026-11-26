extends RefCounted
## Normal-match progression is one file transaction: rewards and receipts commit together.
const CampaignPayout = preload("res://scripts/rules/campaign_payout.gd")

static func commit(world,result:Dictionary,eligible_win:bool) -> bool:
	var before:Dictionary={"academy":MetaProgress.academy.duplicate(true),
		"currency":MetaProgress.currency.duplicate(true),"stats":MetaProgress.stats.duplicate(true),
		"cards":MetaProgress.unlocked_skills.duplicate(),"cosmetics":MetaProgress.owned_cosmetics.duplicate(true),
		"receipts":MetaProgress.settled_matches.duplicate(true)}
	var appearances:=preload("res://scripts/world/production_counts.gd").settle(world,eligible_win,false)
	if eligible_win:appearances.append_array(MetaProgress.award_victory_skins(BattleRequest.victory_difficulty(),false))
	var rewards:Dictionary={}
	if not world.skirmish and world.mission.has("first_win_reward"):
		result.campaign_settlement = true
		rewards = CampaignPayout.settle(world.mission, result)
		if world.mission.id == "yr_hollywood" and CampaignPayout.is_normal_win(result):
			rewards.recruits=MetaProgress.Academy.Stars.recruit_survivors(world,MetaProgress.academy)
	elif not world.skirmish and world.mission.get("endless",false):
		rewards = MetaProgress.apply_battle_result(result,false)
	elif BattleRequest.extensions_enabled() and not bool(result.draw):
		rewards = MetaProgress.apply_battle_result(result,false)
	if not MetaProgress.save():
		MetaProgress.academy=before.academy;MetaProgress.currency=before.currency;MetaProgress.stats=before.stats
		MetaProgress.unlocked_skills.assign(before.cards);MetaProgress.owned_cosmetics=before.cosmetics
		MetaProgress.settled_matches=before.receipts
		return false
	result.cosmetic_rewards=appearances;result.rewards=rewards
	Events.meta_changed.emit()
	return true

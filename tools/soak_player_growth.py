"""Opt-in, isolated soak hooks for AI using the checkpoint's player cards/talents.

Only copied project scripts are changed. Ownership, targeting, AI difficulty,
economy and movement orders retain their real side. No player save is edited.
"""
from pathlib import Path
import shutil


def patch(project: Path):
    def replace(relative, old, new, count=1):
        path = project / relative
        text = path.read_text('utf8')
        if text.count(old) != count:
            raise RuntimeError(f'Growth probe hook changed: {relative}: {old!r}')
        path.write_text(text.replace(old, new), 'utf8')

    request = 'scripts/autoload/battle_request.gd'
    replace(request, 'side!="ally":return', 'not is_house(side):return', 2)
    unit = project / 'scripts/units/unit.gd'
    text = unit.read_text('utf8')
    start = text.index('func _load_equipped_skills(')
    end = text.index('\nfunc equip_hero_cards(', start)
    section = text[start:end].replace('side=="ally"', 'BattleRequest.is_house(side)').replace('side == "ally"', 'BattleRequest.is_house(side)')
    text = text[:start] + section + text[end:]
    old = '\t\tvar ab = data.get("abilities", {})'
    assert text.count(old) == 1
    text = text.replace(old, '\t\tvar ab = BattleRequest.unit_loadout(unit_id) if BattleRequest.is_house(side) else data.get("abilities", {})')
    unit.write_text(text, 'utf8')
    replace('scripts/units/unit.gd', 'if side == "ally" or special.has("auto_w_hit_left"):', 'if BattleRequest.is_house(side) or special.has("auto_w_hit_left"):')
    replace('scripts/units/unit_expansion_idle.gd', 'if unit.side == "ally":', 'if BattleRequest.is_house(unit.side):')
    replace('scripts/units/expansion_rules.gd', 'actor.side=="ally"', 'BattleRequest.is_house(actor.side)')
    replace('scripts/units/electric_cards.gd', 'unit.side=="ally"', 'BattleRequest.is_house(unit.side)', 4)
    replace('scripts/units/expansion_cards.gd', 'actor is Building and actor.side=="ally"', 'actor is Building and BattleRequest.is_house(actor.side)')
    replace('scripts/units/faction_cards.gd', 'actor is Building and actor.side=="ally"', 'actor is Building and BattleRequest.is_house(actor.side)')
    replace('scripts/buildings/building.gd', 'building_id=="NAFLAK" and side=="ally"', 'building_id=="NAFLAK" and BattleRequest.is_house(side)')
    replace('scripts/units/auto_w.gd', 'actor.side != "ally"', 'not BattleRequest.is_house(actor.side)', 2)
    replace('scripts/units/auto_w.gd', 'is_unlocked(TECH, actor.side)', 'is_unlocked(TECH, "ally")')
    replace('scripts/units/auto_w.gd', 'static func evaluate(actor) -> bool:', '''static var soak_casts:Dictionary={}
static func evaluate(actor) -> bool:
	var used:=soak_evaluate(actor)
	if used:
		var key:String=actor.side+"/"+card_id(actor)
		soak_casts[key]=int(soak_casts.get(key,0))+1
	return used

static func soak_evaluate(actor) -> bool:''')
    replace('scripts/buildings/tesla_pulse.gd', 'building.side!="ally"', 'not BattleRequest.is_house(building.side)')
    replace('scripts/buildings/tesla_pulse.gd', 'building.side=="ally"', 'BattleRequest.is_house(building.side)')
    shutil.copy2(Path(__file__).with_suffix('.gd'), project / 'soak_player_growth.gd')
    replace('soak.gd', '\tvar expected_map :=', '\tif not BattleRequest.extensions_enabled():\n\t\tpush_error("Player growth workload requires extension mode")\n\t\tget_tree().quit(2)\n\t\treturn\n\tvar growth_audit := preload("res://soak_player_growth.gd").apply(world)\n\tvar expected_map :=')
    replace('soak.gd', '\tresult.initial_state=initial_state', '\tresult.player_growth=growth_audit\n\tresult.player_growth_final=preload("res://soak_player_growth.gd").audit(world)\n\tresult.initial_state=initial_state')

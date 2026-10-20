class_name DamageCalculator
extends RefCounted
## The damage formula and building durability loss.
## final = max(0, base + territory_modifier - sum(building reductions) - reaction reduction)

const L3_DURABILITY_LOSS: int = 2
const DEFAULT_DURABILITY_LOSS: int = 1


static func calculate(base: int, territory_modifier: int, building_reductions: Array[int], reaction_reduction: int) -> int:
	var total: int = base + territory_modifier - reaction_reduction
	for r: int in building_reductions:
		total -= r
	return maxi(0, total)


static func durability_loss(level: int) -> int:
	return L3_DURABILITY_LOSS if level >= 3 else DEFAULT_DURABILITY_LOSS


## Full breakdown for one town. Returns
## {"final", "base", "territory", "reaction", "buildings": [{"uid", "amount"}]}.
static func breakdown(state: MatchState, player: PlayerState, disaster: DisasterDefinition,
		base: int, reaction_reduction: int) -> Dictionary:
	var terr: TerritoryDefinition = state.catalog.territory(player.territory_id)
	var terr_mod: int = 0
	if terr != null:
		terr_mod = terr.damage_modifier(disaster.tags)
	var reductions: Array[int] = []
	var used: Array[Dictionary] = []
	for b: BuildingInstance in player.buildings:
		var def: BuildingDefinition = state.catalog.building(b.def_id)
		var amount: int = def.reduction_against(disaster.tags)
		if amount > 0:
			reductions.append(amount)
			used.append({"uid": b.uid, "amount": amount})
	return {
		"final": calculate(base, terr_mod, reductions, reaction_reduction),
		"base": base, "territory": terr_mod, "reaction": reaction_reduction, "buildings": used,
	}


## Read-only forecast of what a disaster would do to one town, for the UI. Uses the same
## breakdown() as real resolution so the preview cannot drift from the rules.
## Returns {"min", "max" (final damage across the disaster's base range), "territory",
## "reaction", "buildings": [{"uid", "amount"}]}.
static func preview(state: MatchState, player: PlayerState, disaster: DisasterDefinition,
		reaction_reduction: int = 0, fixed_base: int = -1) -> Dictionary:
	var lo: int = disaster.damage_min if fixed_base < 0 else fixed_base
	var hi: int = disaster.damage_max if fixed_base < 0 else fixed_base
	var low: Dictionary = breakdown(state, player, disaster, lo, reaction_reduction)
	var high: Dictionary = breakdown(state, player, disaster, hi, reaction_reduction)
	return {
		"min": low["final"], "max": high["final"], "base_min": lo, "base_max": hi,
		"territory": low["territory"], "reaction": reaction_reduction, "buildings": low["buildings"],
	}


## Reduces durability. Returns true if the building is destroyed (durability 0).
static func damage_building(building: BuildingInstance, amount: int) -> bool:
	building.durability = maxi(0, building.durability - amount)
	return building.durability == 0

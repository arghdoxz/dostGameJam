class_name VictoryEvaluator
extends RefCounted
## The three win conditions and their tiebreaks (GAME_DESIGN section 8).

const EVACUATION_CENTER_ID: String = "bld_evacuation_center"
const EARLY_WARNING_ID: String = "bld_early_warning_system"

const REASON_LAST_STANDING: String = "last_standing"
const REASON_PREPAREDNESS: String = "preparedness"
const REASON_ROUND_CAP: String = "round_cap"
const REASON_SIMULTANEOUS: String = "simultaneous_elimination"


static func supplies_in_reserve(state: MatchState, player: PlayerState) -> int:
	var n: int = 0
	for c: CardInstance in player.reserve:
		if Payment.kind_of(state.catalog, c) == ResourceCardDef.KIND_SUPPLIES:
			n += 1
	return n


## Number of the three preparedness objectives a town has completed (0 to 3).
static func objectives_completed(state: MatchState, player: PlayerState) -> int:
	var n: int = 0
	if player.has_building(EVACUATION_CENTER_ID):
		n += 1
	if player.has_building(EARLY_WARNING_ID):
		n += 1
	if supplies_in_reserve(state, player) >= state.config.prep_win_supplies:
		n += 1
	return n


static func meets_preparedness(state: MatchState, player: PlayerState) -> bool:
	return not player.eliminated and objectives_completed(state, player) == 3


## Winner ids if exactly one town is left, else an empty array.
static func last_standing(state: MatchState) -> Array[int]:
	var living: Array[PlayerState] = state.living_players()
	var out: Array[int] = []
	if living.size() == 1:
		out.append(living[0].id)
	return out


## Highest RP among living towns; ties break on objectives, then intact buildings, else shared.
static func round_cap_winners(state: MatchState) -> Array[int]:
	var candidates: Array[PlayerState] = state.living_players()
	candidates = _keep_best(candidates, func(p: PlayerState) -> int: return p.rp)
	if candidates.size() > 1:
		candidates = _keep_best(candidates, func(p: PlayerState) -> int: return objectives_completed(state, p))
	if candidates.size() > 1:
		candidates = _keep_best(candidates, func(p: PlayerState) -> int: return p.buildings.size())
	var out: Array[int] = []
	for p: PlayerState in candidates:
		out.append(p.id)
	return out


## All remaining towns hit 0 RP together: highest total durability wins, else shared.
## durability_before maps player id -> durability before the killing blow (approved
## 2026-10-20); a player missing from it falls back to current durability.
static func simultaneous_winners(players: Array[PlayerState], durability_before: Dictionary = {}) -> Array[int]:
	var best: Array[PlayerState] = _keep_best(players, func(p: PlayerState) -> int:
		return int(durability_before.get(p.id, p.total_durability())))
	var out: Array[int] = []
	for p: PlayerState in best:
		out.append(p.id)
	return out


static func _keep_best(players: Array[PlayerState], score: Callable) -> Array[PlayerState]:
	var best: int = -1
	var out: Array[PlayerState] = []
	for p: PlayerState in players:
		var s: int = int(score.call(p))
		if s > best:
			best = s
			out.clear()
			out.append(p)
		elif s == best:
			out.append(p)
	return out


static func finish(state: MatchState, winners: Array[int], reason: String, events: Array[GameEvent]) -> void:
	state.phase = MatchState.Phase.GAME_OVER
	state.pending = null
	state.winner_ids = winners
	state.end_reason = reason
	events.append(GameEvent.new("game_over", {"winners": winners.duplicate(), "reason": reason}))

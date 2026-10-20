class_name TurnSystem
extends RefCounted
## Turn flow: Recovery (own Forecasts, building effects, preparedness win) -> Draw -> Play -> End.
## A round is one full table rotation; the match ends when the round cap is passed.


static func begin_turn(state: MatchState, events: Array[GameEvent]) -> void:
	events.append(GameEvent.new("turn_started", {"player": state.current_player, "round": state.round_number}))
	run_recovery(state, events)


## Resolves the current player's Forecasts one at a time. A Reaction window pauses this;
## DisasterResolver calls back in when the window closes.
static func run_recovery(state: MatchState, events: Array[GameEvent]) -> void:
	var cur: PlayerState = state.current()
	while true:
		var f: PendingDisaster = _next_forecast(state, cur.id)
		if f == null:
			break
		state.forecasts.erase(f)
		if DisasterResolver.begin_resolution(state, f, MatchState.Resume.RECOVERY, events):
			return
		if state.is_over():
			return
	if cur.eliminated:
		advance_turn(state, events)
		return
	for b: BuildingInstance in cur.buildings:
		var heal: int = state.catalog.building(b.def_id).start_turn_heal
		if heal > 0 and cur.rp < state.config.starting_rp:
			var healed: int = mini(heal, state.config.starting_rp - cur.rp)
			cur.rp += healed
			events.append(GameEvent.new("building_effect", {
				"player": cur.id, "building": b.uid, "healed": healed, "rp": cur.rp}))
	if VictoryEvaluator.meets_preparedness(state, cur):
		VictoryEvaluator.finish(state, [cur.id] as Array[int], VictoryEvaluator.REASON_PREPAREDNESS, events)
		return
	state.phase = MatchState.Phase.DRAW
	state.plays_remaining = state.config.plays_per_turn


static func end_turn(state: MatchState, events: Array[GameEvent]) -> void:
	events.append(GameEvent.new("turn_ended", {"player": state.current_player}))
	advance_turn(state, events)


## Moves to the next living player. Eliminated players who still have Forecasts in play
## get a recovery-only turn so those Forecasts resolve.
static func advance_turn(state: MatchState, events: Array[GameEvent]) -> void:
	var n: int = state.players.size()
	var crossed: bool = false
	var next: int = -1
	for k: int in range(1, n + 1):
		var cand: int = (state.current_player + k) % n
		if cand == state.first_player:
			crossed = true
		if not state.players[cand].eliminated or _has_forecast_from(state, cand):
			next = cand
			break
	if next < 0:
		VictoryEvaluator.finish(state, VictoryEvaluator.round_cap_winners(state), VictoryEvaluator.REASON_ROUND_CAP, events)
		return
	if crossed:
		if state.round_number >= state.config.round_cap:
			# Approved 2026-10-20: outstanding Forecasts resolve at the cap, then scoring.
			if not state.forecasts.is_empty():
				events.append(GameEvent.new("final_resolution_started", {"forecasts": state.forecasts.size()}))
			run_final_resolution(state, events)
			return
		state.round_number += 1
		events.append(GameEvent.new("round_started", {"round": state.round_number}))
	state.current_player = next
	begin_turn(state, events)


## Round cap reached: resolves every outstanding Forecast in cast order (each with its normal
## Reaction window), then decides the match on RP. A Reaction window pauses this;
## DisasterResolver calls back in when the window closes.
static func run_final_resolution(state: MatchState, events: Array[GameEvent]) -> void:
	while not state.forecasts.is_empty():
		var f: PendingDisaster = state.forecasts.pop_front()
		if DisasterResolver.begin_resolution(state, f, MatchState.Resume.FINAL, events):
			return
		if state.is_over():
			return
	VictoryEvaluator.finish(state, VictoryEvaluator.round_cap_winners(state), VictoryEvaluator.REASON_ROUND_CAP, events)


static func _next_forecast(state: MatchState, caster_id: int) -> PendingDisaster:
	for f: PendingDisaster in state.forecasts:
		if f.caster_id == caster_id:
			return f
	return null


static func _has_forecast_from(state: MatchState, caster_id: int) -> bool:
	return _next_forecast(state, caster_id) != null

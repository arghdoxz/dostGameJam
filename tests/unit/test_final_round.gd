extends TestCase
## Round-cap behavior approved 2026-10-20: outstanding Forecasts resolve (with Reaction windows,
## in cast order) before the final scoring.


func _forecast(s: MatchState, seq: int, caster: int, targets: Array[int], card: String, dis: String, level: int, base: int) -> PendingDisaster:
	var pd: PendingDisaster = PendingDisaster.new()
	pd.seq = seq
	pd.caster_id = caster
	pd.card_def_id = card
	pd.disaster_id = dis
	pd.level = level
	pd.base_damage = base
	pd.targets = targets
	pd.is_forecast = true
	s.forecasts.append(pd)
	return pd


## Last seat of the final round is about to end their turn.
func _final_round_match(players: int = 2) -> MatchState:
	var s: MatchState = play_match(players)
	s.first_player = 0
	s.round_number = s.config.round_cap
	s.current_player = players - 1
	s.phase = MatchState.Phase.PLAY
	return s


func test_final_round_forecast_resolves_before_scoring() -> void:
	var s: MatchState = _final_round_match()
	_forecast(s, 1, 0, [1] as Array[int], "dis_earthquake", "disaster_earthquake", 3, 6)
	var ev: Array[GameEvent] = apply(s, EndTurnAction.new(1))
	assert_true(has_event(ev, "final_resolution_started"))
	assert_false(s.is_over(), "the forecast must resolve before the game ends")
	assert_eq(s.phase, MatchState.Phase.REACTION)
	assert_eq(s.resume, MatchState.Resume.FINAL)
	assert_eq(s.actor_id(), 1, "the target gets a Reaction window")
	var ev2: Array[GameEvent] = apply(s, PassReactionAction.new(1))
	assert_true(has_event(ev2, "damage_dealt"))
	assert_eq(s.players[1].rp, 14, "6 base damage, no buildings, no territory modifier")
	assert_true(s.is_over())
	assert_eq(s.end_reason, VictoryEvaluator.REASON_ROUND_CAP)
	assert_eq(s.winner_ids, [0] as Array[int], "the final forecast changed who has the highest RP")


func test_final_round_forecast_can_be_reacted_to() -> void:
	var s: MatchState = _final_round_match()
	_forecast(s, 1, 0, [1] as Array[int], "dis_earthquake", "disaster_earthquake", 3, 6)
	var go_bag: CardInstance = give(s, 1, "prep_go_bag")
	apply(s, EndTurnAction.new(1))
	apply(s, ReactAction.new(1, go_bag.uid, [] as Array[int]))
	assert_eq(s.players[1].rp, 15, "Go Bag reduces the final forecast by 1")
	assert_true(s.is_over())


func test_final_round_elimination_ends_match_as_last_standing() -> void:
	var s: MatchState = _final_round_match()
	s.players[1].rp = 3
	_forecast(s, 1, 0, [1] as Array[int], "dis_earthquake", "disaster_earthquake", 3, 6)
	apply(s, EndTurnAction.new(1))
	apply(s, PassReactionAction.new(1))
	assert_true(s.players[1].eliminated)
	assert_true(s.is_over())
	assert_eq(s.end_reason, VictoryEvaluator.REASON_LAST_STANDING)
	assert_eq(s.winner_ids, [0] as Array[int])


func test_final_round_forecasts_resolve_in_cast_order() -> void:
	var s: MatchState = _final_round_match()
	_forecast(s, 1, 0, [1] as Array[int], "dis_earthquake", "disaster_earthquake", 3, 6)
	_forecast(s, 2, 1, [0] as Array[int], "dis_typhoon", "disaster_typhoon", 2, 4)
	var first: Array[GameEvent] = apply(s, EndTurnAction.new(1))
	assert_eq(int(find_event(first, "disaster_revealed").data["caster"]), 0, "oldest forecast first")
	var second: Array[GameEvent] = apply(s, PassReactionAction.new(1))
	var rev: GameEvent = find_event(second, "disaster_revealed")
	assert_true(rev != null, "the second forecast opens its own window")
	assert_eq(int(rev.data["caster"]), 1)
	assert_false(s.is_over())
	assert_eq(s.actor_id(), 0)
	apply(s, PassReactionAction.new(0))
	assert_true(s.is_over())
	assert_eq(s.players[1].rp, 14)
	assert_true(s.players[0].rp < 20)


func test_final_round_without_forecasts_scores_immediately() -> void:
	var s: MatchState = _final_round_match()
	var ev: Array[GameEvent] = apply(s, EndTurnAction.new(1))
	assert_false(has_event(ev, "final_resolution_started"))
	assert_true(s.is_over())
	assert_eq(s.end_reason, VictoryEvaluator.REASON_ROUND_CAP)


func test_final_round_fizzled_forecast_does_not_block_scoring() -> void:
	var s: MatchState = _final_round_match()
	# Flood skips towns with a Drainage System: the target built one during the warning.
	add_building(s, 1, "bld_drainage_system")
	_forecast(s, 1, 0, [1] as Array[int], "dis_flood", "disaster_flood", 2, 5)
	var ev: Array[GameEvent] = apply(s, EndTurnAction.new(1))
	assert_true(has_event(ev, "disaster_fizzled"))
	assert_true(s.is_over())
	assert_eq(s.players[1].rp, 20)

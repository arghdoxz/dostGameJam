extends TestCase


func test_last_town_standing_wins() -> void:
	var s: MatchState = play_match()
	s.players[1].rp = 1
	var c: CardInstance = give(s, 0, "dis_landslide")
	var a: PlayCardAction = PlayCardAction.new(0, c.uid)
	a.target_player_id = 1
	apply(s, a)
	var ev: Array[GameEvent] = apply(s, PassReactionAction.new(1))
	assert_true(has_event(ev, "game_over"))
	assert_true(s.is_over())
	assert_eq(s.winner_ids, [0] as Array[int])
	assert_eq(s.end_reason, VictoryEvaluator.REASON_LAST_STANDING)


func test_preparedness_win_at_start_of_turn() -> void:
	var s: MatchState = play_match()
	add_building(s, 0, "bld_evacuation_center")
	add_building(s, 0, "bld_early_warning_system")
	add_reserve(s, 0, 3)
	var ev: Array[GameEvent] = []
	TurnSystem.begin_turn(s, ev)
	assert_true(s.is_over())
	assert_eq(s.winner_ids, [0] as Array[int])
	assert_eq(s.end_reason, VictoryEvaluator.REASON_PREPAREDNESS)


func test_preparedness_needs_all_three_objectives() -> void:
	var s: MatchState = play_match()
	add_building(s, 0, "bld_evacuation_center")
	add_reserve(s, 0, 3)
	assert_eq(VictoryEvaluator.objectives_completed(s, s.players[0]), 2)
	var ev: Array[GameEvent] = []
	TurnSystem.begin_turn(s, ev)
	assert_false(s.is_over())
	add_building(s, 0, "bld_early_warning_system")
	assert_true(VictoryEvaluator.meets_preparedness(s, s.players[0]))


func test_preparedness_not_checked_for_other_players_turn() -> void:
	var s: MatchState = play_match()
	add_building(s, 1, "bld_evacuation_center")
	add_building(s, 1, "bld_early_warning_system")
	add_reserve(s, 1, 3)
	assert_false(s.is_over(), "only checked at the start of the owner's turn")
	apply(s, EndTurnAction.new(0))
	assert_true(s.is_over())
	assert_eq(s.winner_ids, [1] as Array[int])


func test_round_cap_highest_rp_wins() -> void:
	var s: MatchState = play_match()
	s.round_number = s.config.round_cap
	s.current_player = 1
	s.players[0].rp = 10
	s.players[1].rp = 15
	apply(s, EndTurnAction.new(1))
	assert_true(s.is_over())
	assert_eq(s.end_reason, VictoryEvaluator.REASON_ROUND_CAP)
	assert_eq(s.winner_ids, [1] as Array[int])


func test_round_counter_advances_after_full_rotation() -> void:
	var s: MatchState = play_match(3)
	s.first_player = 0
	apply(s, EndTurnAction.new(0))
	apply(s, DrawAction.new(1, CardDefinition.DeckKind.TOWN))
	apply(s, EndTurnAction.new(1, ActionEnumerator.default_discards(s, s.players[1])))
	assert_eq(s.round_number, 1)
	apply(s, DrawAction.new(2, CardDefinition.DeckKind.TOWN))
	apply(s, EndTurnAction.new(2, ActionEnumerator.default_discards(s, s.players[2])))
	assert_eq(s.round_number, 2)
	assert_eq(s.current_player, 0)


func test_tiebreak_objectives_then_buildings_then_shared() -> void:
	var s: MatchState = play_match(3)
	for p: PlayerState in s.players:
		p.rp = 12
	add_building(s, 0, "bld_evacuation_center")
	assert_eq(VictoryEvaluator.round_cap_winners(s), [0] as Array[int], "more objectives wins the RP tie")
	s.players[0].buildings.clear()
	add_building(s, 1, "bld_seawall")
	add_building(s, 1, "bld_drainage_system")
	add_building(s, 2, "bld_seawall")
	assert_eq(VictoryEvaluator.round_cap_winners(s), [1] as Array[int], "more intact buildings breaks the next tie")
	s.players[1].buildings.pop_back()
	var shared: Array[int] = VictoryEvaluator.round_cap_winners(s)
	assert_eq(shared.size(), 2, "still level: shared win between players 1 and 2")
	assert_true(shared.has(1) and shared.has(2))


func test_simultaneous_elimination_highest_durability_wins() -> void:
	var s: MatchState = play_match(3)
	var ev: Array[GameEvent] = []
	DisasterResolver.eliminate(s, s.players[0], ev)
	var pd: PendingDisaster = PendingDisaster.new()
	pd.seq = 1
	pd.caster_id = 0
	pd.card_def_id = "dis_earthquake"
	pd.disaster_id = "disaster_earthquake"
	pd.level = 3
	pd.base_damage = 6
	pd.targets = [1, 2] as Array[int]
	pd.is_forecast = true
	s.forecasts.append(pd)
	s.players[1].rp = 1
	s.players[2].rp = 1
	var durable: BuildingInstance = add_building(s, 1, "bld_seawall")
	s.current_player = 2
	s.phase = MatchState.Phase.PLAY
	apply(s, EndTurnAction.new(2))
	assert_eq(s.phase, MatchState.Phase.REACTION, "a dead caster's forecast still resolves")
	assert_true(durable.durability == 3)
	apply(s, PassReactionAction.new(1))
	apply(s, PassReactionAction.new(2))
	assert_true(s.is_over())
	assert_eq(s.end_reason, VictoryEvaluator.REASON_SIMULTANEOUS)
	assert_eq(s.winner_ids, [1] as Array[int])


func test_simultaneous_tiebreak_uses_durability_before_the_blow() -> void:
	var s: MatchState = play_match(3)
	var ev: Array[GameEvent] = []
	DisasterResolver.eliminate(s, s.players[0], ev)
	var pd: PendingDisaster = PendingDisaster.new()
	pd.seq = 1
	pd.caster_id = 0
	pd.card_def_id = "dis_earthquake"
	pd.disaster_id = "disaster_earthquake"
	pd.level = 3
	pd.base_damage = 6
	pd.targets = [1, 2] as Array[int]
	pd.is_forecast = true
	s.forecasts.append(pd)
	s.players[1].rp = 1
	s.players[2].rp = 1
	# Retrofitted Structures wears down by 2 against the quake (3 -> 1); Seawall is untouched.
	# Before the blow both towns have durability 3: a tie. After it, player 2 would lead 3 to 1.
	var retrofit: BuildingInstance = add_building(s, 1, "bld_retrofitted_structures")
	add_building(s, 2, "bld_seawall")
	s.current_player = 2
	s.phase = MatchState.Phase.PLAY
	apply(s, EndTurnAction.new(2))
	apply(s, PassReactionAction.new(1))
	apply(s, PassReactionAction.new(2))
	assert_true(s.is_over())
	assert_eq(s.end_reason, VictoryEvaluator.REASON_SIMULTANEOUS)
	assert_true(retrofit.durability == 1, "the building really was worn down by the blow")
	var winners: Array[int] = s.winner_ids
	winners.sort()
	assert_eq(winners, [1, 2] as Array[int], "pre-blow durability ties, so the win is shared")


func test_simultaneous_elimination_tie_is_shared() -> void:
	var a: PlayerState = PlayerState.new()
	a.id = 1
	var b: PlayerState = PlayerState.new()
	b.id = 2
	var winners: Array[int] = VictoryEvaluator.simultaneous_winners([a, b] as Array[PlayerState])
	assert_eq(winners, [1, 2] as Array[int])

extends TestCase
## Edge cases from the Prompt 3 list: empty decks, unaffordable plays, fizzled and chained
## disasters, eliminated targets, stale or duplicate actions, restart during resolution.


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


func test_draw_effect_on_an_empty_deck_reshuffles_the_just_discarded_cards() -> void:
	# The played card and its payment hit the discard pile before the effect runs, so an
	# empty Town deck is refilled from them instead of the draw being lost.
	var s: MatchState = play_match()
	s.town_deck.clear()
	s.town_discard.clear()
	var card: CardInstance = give(s, 0, "prep_early_warning_broadcast")
	var funds: Array[int] = give_n(s, 0, "res_funds", 1)
	var ev: Array[GameEvent] = apply(s, PlayCardAction.new(0, card.uid, funds))
	assert_true(has_event(ev, "card_played"))
	assert_true(has_event(ev, "deck_reshuffled"))
	assert_false(has_event(ev, "action_rejected"))
	assert_eq(s.players[0].hand.size(), 2, "both discarded cards came back as the two draws")
	assert_eq(s.town_discard.size(), 0)


func test_draw_effect_with_one_card_left_draws_it_then_reshuffles() -> void:
	var s: MatchState = play_match()
	var last: CardInstance = s.town_deck[0]
	s.town_deck.clear()
	s.town_deck.append(last)
	s.town_discard.clear()
	var card: CardInstance = give(s, 0, "prep_early_warning_broadcast")
	var funds: Array[int] = give_n(s, 0, "res_funds", 1)
	var ev: Array[GameEvent] = apply(s, PlayCardAction.new(0, card.uid, funds))
	var drawn: int = 0
	for e: GameEvent in ev:
		if e.type == "card_drawn":
			drawn += 1
	assert_eq(drawn, 2)
	assert_true(has_event(ev, "deck_reshuffled"))
	assert_eq(s.players[0].hand.size(), 2)


func test_exhausted_draw_is_skipped_for_the_turn_draw() -> void:
	var s: MatchState = started_match()
	s.town_deck.clear()
	s.town_discard.clear()
	s.disaster_deck.clear()
	s.disaster_discard.clear()
	var hand_before: int = s.players[0].hand.size()
	var ev: Array[GameEvent] = apply(s, DrawAction.new(0, CardDefinition.DeckKind.TOWN))
	assert_true(has_event(ev, "draw_skipped"))
	assert_eq(s.phase, MatchState.Phase.PLAY, "the turn continues with no draw")
	assert_eq(s.players[0].hand.size(), hand_before)


func test_unaffordable_card_is_rejected_and_state_unchanged() -> void:
	var s: MatchState = play_match()
	var seawall: CardInstance = give(s, 0, "bld_seawall")
	var before: String = snapshot(s)
	var ev: Array[GameEvent] = apply(s, PlayCardAction.new(0, seawall.uid))
	assert_true(has_event(ev, "action_rejected"))
	assert_eq(snapshot(s), before)


func test_disaster_without_targets_fizzles_and_costs_once() -> void:
	var s: MatchState = play_match()
	add_building(s, 1, "bld_drainage_system")
	var flood: CardInstance = give(s, 0, "dis_flood")
	var pay: Array[int] = give_n(s, 0, "res_funds", 1)
	var ev: Array[GameEvent] = apply(s, PlayCardAction.new(0, flood.uid, pay))
	assert_true(has_event(ev, "disaster_fizzled"))
	assert_false(has_event(ev, "forecast_placed"))
	assert_eq(s.forecasts.size(), 0)
	assert_eq(s.phase, MatchState.Phase.PLAY, "no Reaction window opens for a fizzle")
	assert_eq(s.disaster_discard.size(), 1, "the disaster card is discarded exactly once")
	var paid_in_discard: int = 0
	for c: CardInstance in s.town_discard:
		if c.uid == pay[0]:
			paid_in_discard += 1
	assert_eq(paid_in_discard, 1, "the payment is discarded exactly once")


func test_eliminated_town_cannot_be_targeted() -> void:
	var s: MatchState = play_match(3)
	var ev: Array[GameEvent] = []
	DisasterResolver.eliminate(s, s.players[1], ev)
	var slide: CardInstance = give(s, 0, "dis_landslide")
	var a: PlayCardAction = PlayCardAction.new(0, slide.uid)
	a.target_player_id = 1
	var before: String = snapshot(s)
	var res: Array[GameEvent] = apply(s, a)
	assert_true(has_event(res, "action_rejected"))
	assert_eq(snapshot(s), before)
	var t: Array[int] = DisasterResolver.compute_targets(s, 0, s.catalog.disaster("disaster_typhoon"), -1)
	assert_eq(t, [2] as Array[int], "area disasters skip eliminated towns")


func test_building_destroyed_then_secondary_damage_hits_the_survivor() -> void:
	var s: MatchState = play_match()
	var weak: BuildingInstance = add_building(s, 1, "bld_retrofitted_structures")
	weak.durability = 1
	var strong: BuildingInstance = add_building(s, 1, "bld_seawall")
	_forecast(s, 1, 0, [1] as Array[int], "dis_earthquake", "disaster_earthquake", 3, 6)
	s.current_player = 1
	apply(s, EndTurnAction.new(1))
	var ev: Array[GameEvent] = apply(s, PassReactionAction.new(1))
	assert_true(has_event(ev, "building_destroyed"), "retrofit wears out against a level 3 quake")
	assert_eq(s.players[1].buildings.size(), 1)
	assert_eq(strong.durability, 2, "earthquake's secondary effect hits the remaining building")
	assert_eq(s.players[1].rp, 16, "base 6 minus Retrofitted Structures' 2 against earthquakes")


func test_forecast_chain_with_elimination_drops_later_forecasts_on_the_dead() -> void:
	var s: MatchState = play_match(3)
	s.players[2].rp = 1
	_forecast(s, 1, 0, [1, 2] as Array[int], "dis_earthquake", "disaster_earthquake", 3, 6)
	_forecast(s, 2, 0, [2] as Array[int], "dis_typhoon", "disaster_typhoon", 2, 4)
	s.current_player = 2
	apply(s, EndTurnAction.new(2))
	apply(s, PassReactionAction.new(1))
	apply(s, PassReactionAction.new(2))
	assert_true(s.players[2].eliminated)
	assert_eq(s.forecasts.size(), 0, "the forecast aimed only at the dead town is removed")
	assert_false(s.is_over(), "two towns are still alive")
	assert_eq(s.phase, MatchState.Phase.DRAW, "recovery continued to the caster's draw")
	assert_eq(s.current_player, 0)


func test_eliminated_caster_forecast_resolves_on_a_ghost_turn_then_skips() -> void:
	var s: MatchState = play_match(3)
	var ev: Array[GameEvent] = []
	DisasterResolver.eliminate(s, s.players[0], ev)
	_forecast(s, 1, 0, [1] as Array[int], "dis_typhoon", "disaster_typhoon", 2, 4)
	s.current_player = 2
	apply(s, EndTurnAction.new(2))
	assert_eq(s.phase, MatchState.Phase.REACTION)
	apply(s, PassReactionAction.new(1))
	assert_true(s.players[1].rp < 20)
	assert_eq(s.current_player, 1, "the dead caster's turn is skipped after the forecast resolves")
	assert_eq(s.phase, MatchState.Phase.DRAW)


func test_duplicate_action_is_rejected_without_changing_state() -> void:
	var s: MatchState = play_match()
	var supplies: CardInstance = give(s, 0, "res_supplies")
	var a: ReserveAction = ReserveAction.new(0, supplies.uid)
	var first: Array[GameEvent] = apply(s, a)
	assert_false(has_event(first, "action_rejected"))
	var before: String = snapshot(s)
	var second: Array[GameEvent] = apply(s, a)
	assert_true(has_event(second, "action_rejected"))
	assert_eq(snapshot(s), before)
	assert_eq(s.players[0].reserve.size(), 1)


func test_out_of_turn_and_wrong_phase_actions_are_rejected() -> void:
	var s: MatchState = started_match()
	var before: String = snapshot(s)
	assert_true(has_event(apply(s, DrawAction.new(1, CardDefinition.DeckKind.TOWN)), "action_rejected"), "not your turn")
	assert_true(has_event(apply(s, EndTurnAction.new(0)), "action_rejected"), "must draw before ending")
	assert_true(has_event(apply(s, PassReactionAction.new(0)), "action_rejected"), "no reaction window")
	assert_eq(snapshot(s), before)


func test_hand_limit_requires_exact_discards() -> void:
	var s: MatchState = play_match()
	give_n(s, 0, "res_materials", s.config.hand_limit + 2)
	var rejected: Array[GameEvent] = apply(s, EndTurnAction.new(0))
	assert_true(has_event(rejected, "action_rejected"), "must discard the excess")
	var discards: Array[int] = ActionEnumerator.default_discards(s, s.players[0])
	assert_eq(discards.size(), 2)
	var ok: Array[GameEvent] = apply(s, EndTurnAction.new(0, discards))
	assert_true(has_event(ok, "cards_discarded"))
	assert_eq(s.players[0].hand.size(), s.config.hand_limit)


func test_actions_are_rejected_after_game_over() -> void:
	var s: MatchState = play_match()
	VictoryEvaluator.finish(s, [0] as Array[int], VictoryEvaluator.REASON_LAST_STANDING, [] as Array[GameEvent])
	var ev: Array[GameEvent] = apply(s, EndTurnAction.new(0))
	assert_true(has_event(ev, "action_rejected"))


func test_abandon_during_reaction_leaves_a_clean_slate() -> void:
	var ctrl: MatchController = MatchController.new()
	var cat: ContentCatalog = catalog()
	var seats: Array[Dictionary] = [{"name": "A", "territory_id": "terr_coastal"}, {"name": "B", "territory_id": "terr_riverside"}]
	assert_eq(ctrl.start(cat, seats, 3), "")
	ctrl.state.phase = MatchState.Phase.PLAY
	ctrl.state.plays_remaining = 1
	var slide: CardInstance = CardInstance.new(ctrl.state.new_uid(), "dis_landslide")
	ctrl.state.players[ctrl.state.current_player].hand.append(slide)
	var a: PlayCardAction = PlayCardAction.new(ctrl.state.current_player, slide.uid)
	a.target_player_id = 1 - ctrl.state.current_player
	assert_true(ctrl.submit(a))
	assert_eq(ctrl.state.phase, MatchState.Phase.REACTION)
	ctrl.abandon()
	assert_false(ctrl.has_match())
	assert_false(ctrl.submit(PassReactionAction.new(0)), "no actions after abandon")
	assert_eq(ctrl.legal_actions().size(), 0)
	assert_eq(ctrl.start(cat, seats, 4), "")
	assert_eq(ctrl.state.phase, MatchState.Phase.DRAW)
	assert_true(ctrl.state.pending == null)
	assert_eq(ctrl.state.forecasts.size(), 0)
	assert_eq(ctrl.action_log.size(), 0)
	ctrl.free()


func test_submit_ignores_reentrant_calls() -> void:
	var ctrl: MatchController = MatchController.new()
	var seats: Array[Dictionary] = [{"name": "A", "territory_id": "terr_coastal"}, {"name": "B", "territory_id": "terr_riverside"}]
	ctrl.start(catalog(), seats, 5)
	var inner: Array = []
	ctrl.events_emitted.connect(func(_e: Array[GameEvent]) -> void:
		if inner.is_empty():
			inner.append(ctrl.submit(DrawAction.new(ctrl.state.current_player, CardDefinition.DeckKind.TOWN))))
	var first: bool = ctrl.submit(DrawAction.new(ctrl.state.current_player, CardDefinition.DeckKind.TOWN))
	assert_true(first)
	assert_eq(inner.size(), 1)
	assert_false(bool(inner[0]), "a submit from inside a handler is refused")
	assert_eq(ctrl.action_log.size(), 1, "only the outer action was logged")
	ctrl.free()

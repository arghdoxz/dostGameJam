extends TestCase


## Plays a disaster card for player `caster` (paying with `pay_def` cards if the level needs it).
func _cast(s: MatchState, caster: int, card_def: String, target: int = -1) -> Array[GameEvent]:
	var c: CardInstance = give(s, caster, card_def)
	var cost: Dictionary = s.catalog.card(card_def).cost
	var pay: Dictionary = Payment.auto_pay(s, s.players[caster], cost)
	if not bool(pay["ok"]):
		give_n(s, caster, "res_materials", int(cost.get("any", 0)))
		pay = Payment.auto_pay(s, s.players[caster], cost)
	var a: PlayCardAction = PlayCardAction.new(caster, c.uid, pay["uids"] as Array[int])
	a.target_player_id = target
	return apply(s, a)


func test_l1_resolves_immediately_with_reaction_window() -> void:
	var s: MatchState = play_match()
	var ev: Array[GameEvent] = _cast(s, 0, "dis_landslide", 1)
	assert_eq(s.phase, MatchState.Phase.REACTION)
	assert_eq(s.actor_id(), 1)
	assert_true(has_event(ev, "disaster_revealed"))
	assert_eq(s.forecasts.size(), 0)
	var ev2: Array[GameEvent] = apply(s, PassReactionAction.new(1))
	var dmg: GameEvent = find_event(ev2, "damage_dealt")
	assert_true(dmg != null)
	assert_eq(s.players[1].rp, 20 - int(dmg.data["amount"]))
	assert_true(int(dmg.data["amount"]) >= 2 and int(dmg.data["amount"]) <= 3)
	assert_eq(s.phase, MatchState.Phase.PLAY)
	assert_eq(s.actor_id(), 0, "play returns to the caster")


func test_l2_becomes_public_forecast() -> void:
	var s: MatchState = play_match()
	var ev: Array[GameEvent] = _cast(s, 0, "dis_typhoon")
	assert_true(has_event(ev, "forecast_placed"))
	assert_eq(s.forecasts.size(), 1)
	assert_eq(s.players[1].rp, 20, "no damage yet")
	assert_eq(s.phase, MatchState.Phase.PLAY)


func test_forecast_resolves_at_start_of_casters_next_turn() -> void:
	var s: MatchState = play_match()
	_cast(s, 0, "dis_typhoon")
	apply(s, EndTurnAction.new(0))
	assert_eq(s.current_player, 1)
	assert_eq(s.phase, MatchState.Phase.DRAW)
	apply(s, DrawAction.new(1, CardDefinition.DeckKind.TOWN))
	apply(s, EndTurnAction.new(1, ActionEnumerator.default_discards(s, s.players[1])))
	assert_eq(s.current_player, 0)
	assert_eq(s.phase, MatchState.Phase.REACTION, "forecast strikes at start of caster's turn")
	assert_eq(s.actor_id(), 1)
	apply(s, PassReactionAction.new(1))
	assert_true(s.players[1].rp < 20)
	assert_eq(s.forecasts.size(), 0)
	assert_eq(s.phase, MatchState.Phase.DRAW, "turn continues after resolution")
	assert_eq(s.actor_id(), 0)


func test_forecasts_resolve_in_cast_order() -> void:
	var s: MatchState = play_match()
	var ev: Array[GameEvent] = []
	DisasterResolver.cast(s, 0, CardInstance.new(s.new_uid(), "dis_typhoon"), -1, ev)
	DisasterResolver.cast(s, 0, CardInstance.new(s.new_uid(), "dis_earthquake"), -1, ev)
	assert_eq(s.forecasts.size(), 2)
	assert_true(s.forecasts[0].seq < s.forecasts[1].seq)
	apply(s, EndTurnAction.new(0))
	apply(s, DrawAction.new(1, CardDefinition.DeckKind.TOWN))
	apply(s, EndTurnAction.new(1, ActionEnumerator.default_discards(s, s.players[1])))
	assert_eq(s.pending.disaster_id, "disaster_typhoon", "first cast resolves first")
	apply(s, PassReactionAction.new(1))
	assert_eq(s.phase, MatchState.Phase.REACTION, "second forecast opens its own window")
	assert_eq(s.pending.disaster_id, "disaster_earthquake")


func test_forecast_removed_when_target_eliminated() -> void:
	var s: MatchState = play_match(3)
	var ev: Array[GameEvent] = []
	DisasterResolver.cast(s, 0, CardInstance.new(s.new_uid(), "dis_typhoon"), -1, ev)
	assert_eq(s.forecasts[0].targets.size(), 2)
	DisasterResolver.eliminate(s, s.players[1], ev)
	assert_eq(s.forecasts[0].targets.size(), 1)
	assert_false(s.forecasts[0].targets.has(1))
	DisasterResolver.eliminate(s, s.players[2], ev)
	assert_eq(s.forecasts.size(), 0, "forecast with no targets disappears")


func test_condition_targeting_with_no_matches_fizzles() -> void:
	var s: MatchState = play_match()
	add_building(s, 1, "bld_drainage_system")
	var ev: Array[GameEvent] = _cast(s, 0, "dis_flood")
	assert_true(has_event(ev, "disaster_fizzled"))
	assert_eq(s.forecasts.size(), 0)
	assert_eq(s.phase, MatchState.Phase.PLAY)


func test_forecast_condition_rechecked_at_resolution() -> void:
	var s: MatchState = play_match()
	_cast(s, 0, "dis_flood")
	assert_eq(s.forecasts.size(), 1)
	add_building(s, 1, "bld_drainage_system")
	apply(s, EndTurnAction.new(0))
	apply(s, DrawAction.new(1, CardDefinition.DeckKind.TOWN))
	apply(s, EndTurnAction.new(1, ActionEnumerator.default_discards(s, s.players[1])))
	assert_eq(s.players[1].rp, 20, "town that built Drainage in the warning gap is spared")
	assert_eq(s.phase, MatchState.Phase.DRAW)


func test_reaction_reduces_damage() -> void:
	var s: MatchState = play_match()
	give(s, 1, "prep_go_bag")
	_cast(s, 0, "dis_landslide", 1)
	var go: CardInstance = s.players[1].hand[0]
	var ev: Array[GameEvent] = apply(s, ReactAction.new(1, go.uid))
	assert_true(has_event(ev, "reaction_played"))
	var dmg: GameEvent = find_event(ev, "damage_dealt")
	assert_eq(int(dmg.data["reaction"]), 1)
	assert_eq(s.players[1].rp, 20 - int(dmg.data["amount"]))
	assert_eq(s.town_discard.size(), 1, "reaction card was discarded")


func test_every_affected_player_gets_a_window_in_turn_order() -> void:
	var s: MatchState = play_match(4)
	var ev: Array[GameEvent] = []
	DisasterResolver.cast(s, 1, CardInstance.new(s.new_uid(), "dis_el_nino_drought"), -1, ev)
	assert_eq(s.phase, MatchState.Phase.REACTION)
	assert_eq(s.pending.targets, [2, 3, 0] as Array[int])
	assert_eq(s.actor_id(), 2)
	s.current_player = 1
	apply(s, PassReactionAction.new(2))
	assert_eq(s.actor_id(), 3)
	apply(s, PassReactionAction.new(3))
	assert_eq(s.actor_id(), 0)
	apply(s, PassReactionAction.new(0))
	assert_eq(s.phase, MatchState.Phase.PLAY)


func test_buildings_reduce_damage_and_lose_durability() -> void:
	var s: MatchState = play_match()
	var seawall: BuildingInstance = add_building(s, 1, "bld_seawall")
	var ev: Array[GameEvent] = []
	DisasterResolver.cast(s, 0, CardInstance.new(s.new_uid(), "dis_storm_surge"), 1, ev)
	assert_eq(s.forecasts.size(), 1)
	apply(s, EndTurnAction.new(0))
	apply(s, DrawAction.new(1, CardDefinition.DeckKind.TOWN))
	apply(s, EndTurnAction.new(1, ActionEnumerator.default_discards(s, s.players[1])))
	var ev2: Array[GameEvent] = apply(s, PassReactionAction.new(1))
	var dmg: GameEvent = find_event(ev2, "damage_dealt")
	assert_eq(int(dmg.data["amount"]), 4, "base 6, Riverside weak to flood +1, Seawall -3")
	assert_true(seawall.durability < 3, "L3 costs the seawall durability")


func test_secondary_effect_and_destruction() -> void:
	var s: MatchState = play_match()
	var b: BuildingInstance = add_building(s, 1, "bld_retrofitted_structures")
	var ev: Array[GameEvent] = []
	DisasterResolver.cast(s, 0, CardInstance.new(s.new_uid(), "dis_earthquake"), -1, ev)
	apply(s, EndTurnAction.new(0))
	apply(s, DrawAction.new(1, CardDefinition.DeckKind.TOWN))
	apply(s, EndTurnAction.new(1, ActionEnumerator.default_discards(s, s.players[1])))
	var ev2: Array[GameEvent] = apply(s, PassReactionAction.new(1))
	assert_eq(s.players[1].rp, 20 - 4, "6 - 2 from Retrofitted Structures")
	assert_true(has_event(ev2, "building_destroyed"), "3 - 2 (L3 loss) - 1 (earthquake secondary) = 0")
	assert_true(s.players[1].find_building(b.uid) == null)
	assert_eq(s.town_discard.size() >= 1, true)


func test_drought_discards_reserve_cards() -> void:
	var s: MatchState = play_match()
	add_reserve(s, 1, 2)
	_cast(s, 0, "dis_el_nino_drought")
	apply(s, PassReactionAction.new(1))
	assert_eq(s.players[1].reserve.size(), 1)


func test_elimination_discards_everything() -> void:
	var s: MatchState = play_match(3)
	s.players[1].rp = 1
	give_n(s, 1, "res_funds", 2)
	add_building(s, 1, "bld_seawall")
	add_reserve(s, 1, 1)
	_cast(s, 0, "dis_landslide", 1)
	var ev: Array[GameEvent] = apply(s, PassReactionAction.new(1))
	assert_true(has_event(ev, "player_eliminated"))
	var p: PlayerState = s.players[1]
	assert_true(p.eliminated)
	assert_eq(p.hand.size() + p.buildings.size() + p.reserve.size(), 0)
	assert_eq(s.phase, MatchState.Phase.PLAY, "two towns remain, match continues")
	var again: Array[GameEvent] = []
	assert_eq(DisasterResolver.compute_targets(s, 0, s.catalog.disaster("disaster_landslide"), 1).size(), 0, "eliminated towns cannot be targeted")
	assert_true(again.is_empty())


func test_territory_trait_applies_in_resolution() -> void:
	var s: MatchState = play_match()
	# P1 is Riverside (weak to flood, so +1). No Drainage so the flood hits.
	_cast(s, 0, "dis_flood")
	apply(s, EndTurnAction.new(0))
	apply(s, DrawAction.new(1, CardDefinition.DeckKind.TOWN))
	apply(s, EndTurnAction.new(1, ActionEnumerator.default_discards(s, s.players[1])))
	var ev: Array[GameEvent] = apply(s, PassReactionAction.new(1))
	var dmg: GameEvent = find_event(ev, "damage_dealt")
	assert_eq(int(dmg.data["territory"]), 1)
	assert_eq(int(dmg.data["amount"]), int(dmg.data["base"]) + 1)

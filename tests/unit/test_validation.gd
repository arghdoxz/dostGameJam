extends TestCase


func _reject(s: MatchState, a: GameAction, expect_fragment: String) -> void:
	var before: String = snapshot(s)
	var v: ValidationResult = RulesEngine.validate(s, a)
	assert_false(v.ok, "should be rejected: " + expect_fragment)
	assert_true(v.reason.contains(expect_fragment), "reason was '%s'" % v.reason)
	var ev: Array[GameEvent] = RulesEngine.apply(s, a)
	assert_true(has_event(ev, "action_rejected"))
	assert_eq(snapshot(s), before, "state must be unchanged after a rejected action")


func test_play_out_of_turn() -> void:
	var s: MatchState = play_match()
	var c: CardInstance = give(s, 1, "bld_seawall")
	_reject(s, PlayCardAction.new(1, c.uid), "not your turn")


func test_unaffordable_card() -> void:
	var s: MatchState = play_match()
	var c: CardInstance = give(s, 0, "bld_seawall")
	_reject(s, PlayCardAction.new(0, c.uid), "Cost not paid")


func test_wrong_or_excess_payment() -> void:
	var s: MatchState = play_match()
	var c: CardInstance = give(s, 0, "bld_seawall")
	var funds: Array[int] = give_n(s, 0, "res_funds", 2)
	_reject(s, PlayCardAction.new(0, c.uid, funds), "Cost not paid")
	var mats: Array[int] = give_n(s, 0, "res_materials", 3)
	_reject(s, PlayCardAction.new(0, c.uid, mats), "exactly")


func test_self_target_rejected() -> void:
	var s: MatchState = play_match()
	var c: CardInstance = give(s, 0, "dis_landslide")
	var a: PlayCardAction = PlayCardAction.new(0, c.uid)
	a.target_player_id = 0
	_reject(s, a, "yourself")


func test_eliminated_target_rejected() -> void:
	var s: MatchState = play_match(3)
	var ev: Array[GameEvent] = []
	DisasterResolver.eliminate(s, s.players[2], ev)
	var c: CardInstance = give(s, 0, "dis_landslide")
	var a: PlayCardAction = PlayCardAction.new(0, c.uid)
	a.target_player_id = 2
	_reject(s, a, "eliminated")


func test_second_play_rejected_without_extra_play() -> void:
	var s: MatchState = play_match()
	var c: CardInstance = give(s, 0, "prep_go_bag")
	assert_true(RulesEngine.validate(s, PlayCardAction.new(0, c.uid)).ok == false, "Go Bag is a Reaction")
	var heal: CardInstance = give(s, 0, "prep_community_pantry")
	var pay: Array[int] = give_n(s, 0, "res_materials", 1)
	assert_true(RulesEngine.validate(s, PlayCardAction.new(0, heal.uid, pay)).ok)
	apply(s, PlayCardAction.new(0, heal.uid, pay))
	var second: CardInstance = give(s, 0, "prep_early_warning_broadcast")
	var pay2: Array[int] = give_n(s, 0, "res_funds", 1)
	_reject(s, PlayCardAction.new(0, second.uid, pay2), "No plays left")


func test_extra_play_allows_second_play() -> void:
	var s: MatchState = play_match()
	var map: CardInstance = give(s, 0, "prep_hazard_mapping")
	var pay: Array[int] = give_n(s, 0, "res_funds", 1)
	apply(s, PlayCardAction.new(0, map.uid, pay))
	assert_eq(s.plays_remaining, 1, "Hazard Mapping uses a play and grants one")
	var c2: CardInstance = give(s, 0, "bld_seawall")
	var p2: Array[int] = give_n(s, 0, "res_materials", 2)
	assert_true(RulesEngine.validate(s, PlayCardAction.new(0, c2.uid, p2)).ok)


func test_reaction_outside_window_rejected() -> void:
	var s: MatchState = play_match()
	var c: CardInstance = give(s, 0, "prep_go_bag")
	_reject(s, ReactAction.new(0, c.uid), "No Reaction window")
	_reject(s, PassReactionAction.new(0), "No Reaction window")


func test_end_turn_requires_hand_limit() -> void:
	var s: MatchState = play_match()
	give_n(s, 0, "res_materials", 9)
	_reject(s, EndTurnAction.new(0), "Discard exactly 2")
	var extra: Array[int] = [s.players[0].hand[0].uid, s.players[0].hand[1].uid]
	var v: ValidationResult = RulesEngine.validate(s, EndTurnAction.new(0, extra))
	assert_true(v.ok, v.reason)


func test_cannot_end_turn_before_drawing() -> void:
	var s: MatchState = started_match()
	assert_eq(s.phase, MatchState.Phase.DRAW)
	_reject(s, EndTurnAction.new(0), "Draw a card")


func test_resource_and_reaction_cards_cannot_be_played() -> void:
	var s: MatchState = play_match()
	var r: CardInstance = give(s, 0, "res_materials")
	_reject(s, PlayCardAction.new(0, r.uid), "spent as payment")
	var g: CardInstance = give(s, 0, "prep_go_bag")
	_reject(s, PlayCardAction.new(0, g.uid), "Reaction window")


func test_repair_needs_damaged_building() -> void:
	var s: MatchState = play_match()
	var b: BuildingInstance = add_building(s, 0, "bld_seawall")
	var c: CardInstance = give(s, 0, "prep_bayanihan")
	var pay: Array[int] = give_n(s, 0, "res_supplies", 1)
	var a: PlayCardAction = PlayCardAction.new(0, c.uid, pay)
	a.target_building_uid = b.uid
	_reject(s, a, "undamaged")
	b.durability = 1
	assert_true(RulesEngine.validate(s, a).ok)
	apply(s, a)
	assert_eq(b.durability, 3, "repair 2 capped by max durability 3")


func test_game_over_rejects_everything() -> void:
	var s: MatchState = play_match()
	var ev: Array[GameEvent] = []
	VictoryEvaluator.finish(s, [0] as Array[int], "test", ev)
	var v: ValidationResult = RulesEngine.validate(s, EndTurnAction.new(0))
	assert_false(v.ok)

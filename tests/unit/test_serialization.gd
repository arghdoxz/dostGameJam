extends TestCase


func _round_trip(a: GameAction) -> void:
	var d1: Dictionary = a.to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(d1))
	var back: GameAction = ActionFactory.from_dict(parsed as Dictionary)
	assert_true(back != null, "factory must rebuild " + a.type)
	if back != null:
		assert_eq(back.type, a.type)
		assert_eq(JSON.stringify(back.to_dict()), JSON.stringify(d1))


func test_every_action_round_trips_through_json() -> void:
	_round_trip(DrawAction.new(1, CardDefinition.DeckKind.DISASTER))
	var p: PlayCardAction = PlayCardAction.new(2, 9, [4, 5] as Array[int])
	p.target_player_id = 3
	p.target_building_uid = 11
	_round_trip(p)
	_round_trip(ReserveAction.new(0, 7))
	_round_trip(ReactAction.new(1, 8, [2] as Array[int]))
	_round_trip(PassReactionAction.new(3))
	_round_trip(EndTurnAction.new(0, [1, 2] as Array[int]))


func test_unknown_action_type_returns_null() -> void:
	assert_true(ActionFactory.from_dict({"type": "nonsense"}) == null)


func test_replaying_logged_actions_reproduces_state() -> void:
	var s: MatchState = started_match(2, 99)
	var log: Array[Dictionary] = []
	var a1: DrawAction = DrawAction.new(0, CardDefinition.DeckKind.TOWN)
	log.append(a1.to_dict())
	apply(s, a1)
	var a2: EndTurnAction = EndTurnAction.new(0, ActionEnumerator.default_discards(s, s.players[0]))
	log.append(a2.to_dict())
	apply(s, a2)
	var r: MatchState = started_match(2, 99)
	for d: Dictionary in log:
		apply(r, ActionFactory.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary))
	assert_eq(snapshot(r), snapshot(s))

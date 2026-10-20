extends TestCase


func test_auto_pay_uses_hand_then_reserve() -> void:
	var s: MatchState = play_match()
	give_n(s, 0, "res_materials", 1)
	add_reserve(s, 0, 1)
	var pay: Dictionary = Payment.auto_pay(s, s.players[0], {"materials": 1, "supplies": 1})
	assert_true(bool(pay["ok"]))
	assert_eq((pay["uids"] as Array).size(), 2)
	assert_eq(Payment.check(s, s.players[0], {"materials": 1, "supplies": 1}, pay["uids"] as Array[int]), "")


func test_auto_pay_prefers_hand_supplies_over_reserve() -> void:
	var s: MatchState = play_match()
	var hand_supply: Array[int] = give_n(s, 0, "res_supplies", 1)
	add_reserve(s, 0, 1)
	var pay: Dictionary = Payment.auto_pay(s, s.players[0], {"supplies": 1})
	assert_eq((pay["uids"] as Array[int])[0], hand_supply[0])


func test_reserve_supplies_can_pay_any_cost() -> void:
	var s: MatchState = play_match()
	add_reserve(s, 0, 2)
	var pay: Dictionary = Payment.auto_pay(s, s.players[0], {"any": 2})
	assert_true(bool(pay["ok"]))
	var ev: Array[GameEvent] = []
	Payment.spend(s, s.players[0], pay["uids"] as Array[int], ev)
	assert_eq(s.players[0].reserve.size(), 0)
	assert_eq(s.town_discard.size(), 2)


func test_unaffordable_cost() -> void:
	var s: MatchState = play_match()
	give_n(s, 0, "res_funds", 1)
	assert_false(bool(Payment.auto_pay(s, s.players[0], {"materials": 1})["ok"]))
	assert_false(bool(Payment.auto_pay(s, s.players[0], {"any": 2})["ok"]))


func test_check_rejects_non_resource_and_duplicates() -> void:
	var s: MatchState = play_match()
	var b: CardInstance = give(s, 0, "bld_seawall")
	assert_ne(Payment.check(s, s.players[0], {"any": 1}, [b.uid] as Array[int]), "")
	var m: Array[int] = give_n(s, 0, "res_materials", 1)
	assert_ne(Payment.check(s, s.players[0], {"any": 2}, [m[0], m[0]] as Array[int]), "")


func test_free_cost_needs_empty_payment() -> void:
	var s: MatchState = play_match()
	assert_eq(Payment.check(s, s.players[0], {}, [] as Array[int]), "")
	var m: Array[int] = give_n(s, 0, "res_materials", 1)
	assert_ne(Payment.check(s, s.players[0], {}, m), "")


func test_reserve_action_is_free_and_supplies_only() -> void:
	var s: MatchState = play_match()
	var sup: CardInstance = give(s, 0, "res_supplies")
	var mat: CardInstance = give(s, 0, "res_materials")
	assert_false(RulesEngine.validate(s, ReserveAction.new(0, mat.uid)).ok)
	apply(s, ReserveAction.new(0, sup.uid))
	assert_eq(s.players[0].reserve.size(), 1)
	assert_eq(s.plays_remaining, s.config.plays_per_turn, "Reserve does not use a play")

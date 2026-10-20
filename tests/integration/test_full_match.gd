extends TestCase
## Seeded bot matches from setup to game over. The bot only picks among actions that
## ActionEnumerator reports as legal, and everything still goes through RulesEngine.

const MAX_STEPS: int = 6000


## Plays a whole match. Returns {"state", "log", "event_types"}.
func _play(players: int, match_seed: int, bot_seed: int) -> Dictionary:
	var s: MatchState = new_match(players, match_seed)
	var log: Array[Dictionary] = []
	var types: Dictionary = {}
	for e: GameEvent in RulesEngine.start_match(s):
		types[e.type] = true
	var bot: RandomNumberGenerator = RandomNumberGenerator.new()
	bot.seed = bot_seed
	var steps: int = 0
	while not s.is_over() and steps < MAX_STEPS:
		steps += 1
		var actions: Array[GameAction] = ActionEnumerator.legal_actions(s)
		var pick: GameAction = _choose(s, actions, bot)
		log.append(pick.to_dict())
		for e: GameEvent in RulesEngine.apply(s, pick):
			types[e.type] = true
	return {"state": s, "log": log, "event_types": types, "steps": steps}


func _choose(s: MatchState, actions: Array[GameAction], bot: RandomNumberGenerator) -> GameAction:
	var non_end: Array[GameAction] = []
	var end_action: GameAction = null
	for a: GameAction in actions:
		if a is EndTurnAction or a is PassReactionAction:
			end_action = a
		else:
			non_end.append(a)
	if non_end.is_empty():
		return end_action if end_action != null else actions[0]
	if end_action != null and s.phase == MatchState.Phase.PLAY and bot.randf() < 0.25:
		return end_action
	return non_end[bot.randi_range(0, non_end.size() - 1)]


func test_two_player_matches_reach_game_over() -> void:
	for seed_value: int in [1, 2, 3, 4, 5]:
		var r: Dictionary = _play(2, seed_value, seed_value + 100)
		var s: MatchState = r["state"] as MatchState
		assert_true(s.is_over(), "2p seed %d finished in %d steps" % [seed_value, int(r["steps"])])
		assert_false(s.winner_ids.is_empty(), "a winner is recorded")
		assert_ne(s.end_reason, "")


func test_four_player_matches_reach_game_over() -> void:
	for seed_value: int in [11, 12, 13, 14, 15]:
		var r: Dictionary = _play(4, seed_value, seed_value + 100)
		var s: MatchState = r["state"] as MatchState
		assert_true(s.is_over(), "4p seed %d finished in %d steps" % [seed_value, int(r["steps"])])
		assert_false(s.winner_ids.is_empty())


func test_three_player_match_reaches_game_over() -> void:
	var r: Dictionary = _play(3, 21, 121)
	assert_true((r["state"] as MatchState).is_over())


func test_matches_exercise_core_systems() -> void:
	var seen: Dictionary = {}
	for seed_value: int in range(30, 40):
		var r: Dictionary = _play(4, seed_value, seed_value)
		for k: Variant in (r["event_types"] as Dictionary).keys():
			seen[k] = true
	for needed: String in ["card_drawn", "card_played", "cost_paid", "building_built", "disaster_cast",
			"forecast_placed", "disaster_revealed", "damage_dealt", "reaction_passed", "game_over", "round_started"]:
		assert_true(seen.has(needed), "bot matches should produce event: " + needed)


func test_same_seed_and_actions_are_deterministic() -> void:
	var a: Dictionary = _play(3, 42, 7)
	var b: Dictionary = _play(3, 42, 7)
	assert_eq(snapshot(a["state"] as MatchState), snapshot(b["state"] as MatchState))
	assert_eq(JSON.stringify(a["log"]), JSON.stringify(b["log"]))


func test_replaying_the_action_log_reproduces_the_final_state() -> void:
	var r: Dictionary = _play(4, 55, 9)
	var original: MatchState = r["state"] as MatchState
	var replay: MatchState = new_match(4, 55)
	RulesEngine.start_match(replay)
	for d: Dictionary in (r["log"] as Array):
		var action: GameAction = ActionFactory.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary)
		var v: ValidationResult = RulesEngine.validate(replay, action)
		assert_true(v.ok, "logged action must be legal on replay: " + v.reason)
		RulesEngine.apply(replay, action)
	assert_eq(snapshot(replay), snapshot(original))


func test_fresh_match_after_a_finished_one_is_clean() -> void:
	var r: Dictionary = _play(2, 61, 5)
	assert_true((r["state"] as MatchState).is_over())
	var again: MatchState = new_match(2, 62)
	RulesEngine.start_match(again)
	assert_false(again.is_over())
	assert_eq(again.round_number, 1)
	for p: PlayerState in again.players:
		assert_eq(p.rp, again.config.starting_rp)
		assert_false(p.eliminated)
		assert_eq(p.buildings.size(), 0)


func test_setup_validation() -> void:
	var cat: ContentCatalog = catalog()
	var one: Array[Dictionary] = [{"name": "A", "territory_id": "terr_coastal"}]
	assert_false(RulesEngine.validate_setup(cat.config, cat, one).ok, "needs 2+ players")
	var dup: Array[Dictionary] = [
		{"name": "A", "territory_id": "terr_coastal"}, {"name": "B", "territory_id": "terr_coastal"}]
	assert_false(RulesEngine.validate_setup(cat.config, cat, dup).ok, "territories must be distinct")
	var bad: Array[Dictionary] = [
		{"name": "A", "territory_id": "terr_coastal"}, {"name": "B", "territory_id": "terr_nowhere"}]
	assert_false(RulesEngine.validate_setup(cat.config, cat, bad).ok)
	var five: Array[Dictionary] = []
	for i: int in range(5):
		five.append({"name": "P%d" % i, "territory_id": cat.territory_ids()[i]})
	assert_false(RulesEngine.validate_setup(cat.config, cat, five).ok, "at most 4 players")
	var good: Array[Dictionary] = [
		{"name": "A", "territory_id": "terr_coastal"}, {"name": "B", "territory_id": "terr_upland"}]
	assert_true(RulesEngine.validate_setup(cat.config, cat, good).ok)

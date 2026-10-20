class_name TestCase
extends RefCounted
## Base class for tests. Methods named test_* are run by tests/run_tests.gd.
## Provides assertions and helpers for building match states without any UI.

const REGISTRY_PATH: String = "res://content/content_registry.tres"

static var _catalog: ContentCatalog

var failures: Array[String] = []
var assertion_count: int = 0


func assert_true(cond: bool, msg: String = "") -> void:
	assertion_count += 1
	if not cond:
		failures.append("assert_true failed. " + msg)


func assert_false(cond: bool, msg: String = "") -> void:
	assertion_count += 1
	if cond:
		failures.append("assert_false failed. " + msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	assertion_count += 1
	if actual != expected:
		failures.append("expected %s but got %s. %s" % [str(expected), str(actual), msg])


func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	assertion_count += 1
	if actual == unexpected:
		failures.append("expected a value other than %s. %s" % [str(unexpected), msg])


func catalog() -> ContentCatalog:
	if _catalog == null:
		_catalog = ContentCatalog.from_registry(load(REGISTRY_PATH) as ContentRegistry)
	return _catalog


## Territories in sorted id order: coastal, riverside, upland, urban_lowland, volcanic_foothills.
func new_match(players: int = 2, seed_value: int = 1) -> MatchState:
	var cat: ContentCatalog = catalog()
	var ids: Array[String] = cat.territory_ids()
	ids.sort()
	var seats: Array[Dictionary] = []
	for i: int in range(players):
		seats.append({"name": "P%d" % i, "territory_id": ids[i]})
	return RulesEngine.new_match(cat.config, cat, seats, seed_value)


## A match where player 0 goes first and the turn has begun (Draw phase).
func started_match(players: int = 2, seed_value: int = 1) -> MatchState:
	var s: MatchState = new_match(players, seed_value)
	s.first_player = 0
	s.current_player = 0
	var ev: Array[GameEvent] = []
	TurnSystem.begin_turn(s, ev)
	return s


## A started match already in the Play phase with empty hands, for scripted scenarios.
func play_match(players: int = 2, seed_value: int = 1) -> MatchState:
	var s: MatchState = started_match(players, seed_value)
	for p: PlayerState in s.players:
		p.hand.clear()
	s.phase = MatchState.Phase.PLAY
	s.plays_remaining = s.config.plays_per_turn
	return s


func give(s: MatchState, player_id: int, def_id: String) -> CardInstance:
	var c: CardInstance = CardInstance.new(s.new_uid(), def_id)
	s.players[player_id].hand.append(c)
	return c


func give_n(s: MatchState, player_id: int, def_id: String, n: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(n):
		out.append(give(s, player_id, def_id).uid)
	return out


func add_building(s: MatchState, player_id: int, def_id: String) -> BuildingInstance:
	var b: BuildingInstance = BuildingInstance.new(s.new_uid(), def_id, s.catalog.building(def_id).durability)
	s.players[player_id].buildings.append(b)
	return b


func add_reserve(s: MatchState, player_id: int, n: int) -> void:
	for i: int in range(n):
		s.players[player_id].reserve.append(CardInstance.new(s.new_uid(), "res_supplies"))


func apply(s: MatchState, action: GameAction) -> Array[GameEvent]:
	return RulesEngine.apply(s, action)


func has_event(events: Array[GameEvent], type: String) -> bool:
	for e: GameEvent in events:
		if e.type == type:
			return true
	return false


func find_event(events: Array[GameEvent], type: String) -> GameEvent:
	for e: GameEvent in events:
		if e.type == type:
			return e
	return null


func snapshot(s: MatchState) -> String:
	return JSON.stringify(s.to_dict())

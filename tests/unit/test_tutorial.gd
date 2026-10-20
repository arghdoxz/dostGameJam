extends TestCase
## The tutorial: its arranged match, and a headless walk through the whole lesson. The walk
## plays every ACTION step's intended move through RulesEngine and checks that the step was NOT
## already complete before the move and IS complete after it, so no step can be skipped by
## accident or be impossible to finish.

const HIGHLIGHT_KEYS: Array[String] = [
	"", "map", "header", "end_turn", "log", "piles", "hand", "actions", "disaster", "summary",
	"cover_ready", "seat_actor",
]


func _tutorial_match() -> MatchState:
	var s: MatchState = RulesEngine.new_match(catalog().config, catalog(), TutorialScenario.seats(), TutorialScenario.SEED)
	TutorialScenario.arrange(s)
	RulesEngine.start_match(s)
	return s


func _count_cards(s: MatchState) -> int:
	var n: int = s.town_deck.size() + s.town_discard.size() + s.disaster_deck.size() + s.disaster_discard.size()
	for p: PlayerState in s.players:
		n += p.hand.size() + p.reserve.size()
	return n


func test_scenario_arranges_hands_without_creating_cards() -> void:
	var plain: MatchState = new_match(2, TutorialScenario.SEED)
	var s: MatchState = _tutorial_match()
	assert_eq(_count_cards(s), _count_cards(plain), "arranging must only move cards")
	assert_eq(s.first_player, 0, "the learner (You) goes first")
	assert_eq(s.current_player, 0)
	assert_eq(s.phase, MatchState.Phase.DRAW)
	assert_eq(s.players[0].hand.size(), TutorialScenario.YOU_HAND.size())
	assert_eq(s.players[1].hand.size(), TutorialScenario.RIVAL_HAND.size())
	for id: String in TutorialScenario.YOU_HAND:
		assert_true(_has(s.players[0], id), "You should hold " + id)
	for id: String in TutorialScenario.RIVAL_HAND:
		assert_true(_has(s.players[1], id), "Rival should hold " + id)
	assert_eq(s.town_deck.back().def_id, TutorialScenario.TOWN_TOP[0], "top of the Town deck is stacked")
	assert_eq(s.disaster_deck.back().def_id, TutorialScenario.DISASTER_TOP[0], "top of the Disaster deck is stacked")


func _has(p: PlayerState, def_id: String) -> bool:
	for c: CardInstance in p.hand:
		if c.def_id == def_id:
			return true
	return false


func test_scenario_uids_are_unique() -> void:
	var s: MatchState = _tutorial_match()
	var seen: Dictionary = {}
	var all: Array[CardInstance] = []
	all.append_array(s.town_deck)
	all.append_array(s.disaster_deck)
	for p: PlayerState in s.players:
		all.append_array(p.hand)
	for c: CardInstance in all:
		assert_false(seen.has(c.uid), "duplicate card uid %d" % c.uid)
		seen[c.uid] = true


func test_every_step_is_well_formed() -> void:
	var steps: Array[TutorialStep] = TutorialScript.build()
	assert_true(steps.size() >= 20, "a real lesson, not a stub")
	var ids: Dictionary = {}
	for st: TutorialStep in steps:
		assert_false(ids.has(st.id), "duplicate step id " + st.id)
		ids[st.id] = true
		assert_ne(st.title, "", st.id + " needs a title")
		if st.id != "finish":
			assert_ne(st.body, "", st.id + " needs text")
		if st.kind == TutorialStep.Kind.ACTION:
			assert_true(st.done.is_valid(), st.id + " needs a completion test")
			assert_ne(st.success, "", st.id + " needs a success line")
		var key: String = st.highlight
		var ok: bool = HIGHLIGHT_KEYS.has(key) or key.begins_with("seat:")
		if key.begins_with("card:"):
			ok = catalog().card(key.substr(5)) != null
		assert_true(ok, "unknown highlight key '%s' in %s" % [key, st.id])
	assert_eq(steps.back().id, "finish")


func test_lesson_can_be_completed_step_by_step() -> void:
	var s: MatchState = _tutorial_match()
	var steps: Array[TutorialStep] = TutorialScript.build()
	var selected: String = ""
	var target: int = -1
	for st: TutorialStep in steps:
		if st.kind != TutorialStep.Kind.ACTION:
			continue
		var before: TutorialContext = _ctx(s, [] as Array[GameEvent], selected, target)
		before.cover_visible = st.id == "welcome"
		before.summary_visible = st.over_summary
		assert_false(bool(st.done.call(before)), "%s must not be complete before the learner acts" % st.id)
		if st.ui_selected != "":
			selected = st.ui_selected
		if st.ui_target >= 0:
			target = st.ui_target
		var events: Array[GameEvent] = []
		var played: bool = false
		if st.intent.is_valid():
			for a: Variant in (st.intent.call(s) as Array):
				var action: GameAction = a as GameAction
				assert_true(action != null, "%s: the intended action does not exist" % st.id)
				if action == null:
					return
				var v: ValidationResult = RulesEngine.validate(s, action)
				assert_true(v.ok, "%s: intended action rejected: %s" % [st.id, v.reason])
				if not v.ok:
					return
				events.append_array(RulesEngine.apply(s, action))
				played = true
		var after: TutorialContext = _ctx(s, events, selected, target)
		after.age = 5.0
		after.summary_seen = st.over_summary
		assert_true(bool(st.done.call(after)), "%s must be complete after the intended action" % st.id)
		if played:
			selected = ""
			target = -1
	assert_false(s.is_over(), "the lesson must not end the match")
	assert_eq(s.round_number, 3, "the lesson runs through round 3")
	assert_true(s.players[0].has_building("bld_seawall"), "the learner built the Seawall")
	assert_true(s.players[1].rp < s.config.starting_rp, "the Typhoon hurt Ben")


func _ctx(s: MatchState, events: Array[GameEvent], selected: String, target: int) -> TutorialContext:
	var c: TutorialContext = TutorialContext.new()
	c.state = s
	c.events = events
	c.selected_def = selected
	c.chosen_target = target
	return c


func test_wrong_actions_never_complete_a_step() -> void:
	# Off-script moves (ending the turn immediately) must leave later steps unfinished, never crash.
	var s: MatchState = _tutorial_match()
	var steps: Array[TutorialStep] = TutorialScript.build()
	RulesEngine.apply(s, DrawAction.new(0, CardDefinition.DeckKind.TOWN))
	RulesEngine.apply(s, EndTurnAction.new(0))
	for st: TutorialStep in steps:
		if st.id == "build_seawall" or st.id == "bank_supplies":
			var c: TutorialContext = _ctx(s, [] as Array[GameEvent], "", -1)
			assert_false(bool(st.done.call(c)), st.id + " stays open (Skip step handles it)")

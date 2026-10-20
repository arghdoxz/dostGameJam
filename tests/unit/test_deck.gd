extends TestCase


func _total(counts: Dictionary) -> int:
	var n: int = 0
	for k: Variant in counts.keys():
		n += int(counts[k])
	return n


func test_decks_built_from_config_and_hands_dealt() -> void:
	var s: MatchState = new_match(3)
	var cfg: MatchConfig = s.config
	assert_eq(s.town_deck.size(), _total(cfg.town_deck) - 3 * cfg.starting_hand)
	assert_eq(s.disaster_deck.size(), _total(cfg.disaster_deck))
	for p: PlayerState in s.players:
		assert_eq(p.hand.size(), cfg.starting_hand)
		assert_eq(p.rp, cfg.starting_rp)


func test_card_uids_are_unique() -> void:
	var s: MatchState = new_match(4)
	var seen: Dictionary = {}
	var dup: bool = false
	var all: Array[CardInstance] = []
	all.append_array(s.town_deck)
	all.append_array(s.disaster_deck)
	for p: PlayerState in s.players:
		all.append_array(p.hand)
	for c: CardInstance in all:
		if seen.has(c.uid):
			dup = true
		seen[c.uid] = true
	assert_false(dup)


func test_draw_moves_card_from_deck_to_hand() -> void:
	var s: MatchState = started_match()
	var before_deck: int = s.disaster_deck.size()
	var before_hand: int = s.players[0].hand.size()
	apply(s, DrawAction.new(0, CardDefinition.DeckKind.DISASTER))
	assert_eq(s.disaster_deck.size(), before_deck - 1)
	assert_eq(s.players[0].hand.size(), before_hand + 1)
	assert_eq(s.phase, MatchState.Phase.PLAY)


func test_reshuffle_when_deck_empty() -> void:
	var s: MatchState = started_match()
	s.town_deck.clear()
	s.town_discard.append(CardInstance.new(s.new_uid(), "res_funds"))
	s.town_discard.append(CardInstance.new(s.new_uid(), "res_funds"))
	var ev: Array[GameEvent] = apply(s, DrawAction.new(0, CardDefinition.DeckKind.TOWN))
	assert_true(has_event(ev, "deck_reshuffled"))
	assert_eq(s.town_deck.size(), 1)
	assert_eq(s.town_discard.size(), 0)


func test_empty_deck_draw_rejected_but_other_deck_ok() -> void:
	var s: MatchState = started_match()
	s.town_deck.clear()
	s.town_discard.clear()
	assert_false(RulesEngine.validate(s, DrawAction.new(0, CardDefinition.DeckKind.TOWN)).ok)
	assert_true(RulesEngine.validate(s, DrawAction.new(0, CardDefinition.DeckKind.DISASTER)).ok)


func test_both_decks_empty_skips_draw() -> void:
	var s: MatchState = started_match()
	for d: Array[CardInstance] in [s.town_deck, s.town_discard, s.disaster_deck, s.disaster_discard]:
		d.clear()
	var hand: int = s.players[0].hand.size()
	var ev: Array[GameEvent] = apply(s, DrawAction.new(0, CardDefinition.DeckKind.TOWN))
	assert_true(has_event(ev, "draw_skipped"))
	assert_eq(s.players[0].hand.size(), hand)
	assert_eq(s.phase, MatchState.Phase.PLAY)


func test_same_seed_gives_same_deal() -> void:
	var a: MatchState = new_match(2, 777)
	var b: MatchState = new_match(2, 777)
	assert_eq(snapshot(a), snapshot(b))
	var c: MatchState = new_match(2, 778)
	assert_ne(snapshot(a), snapshot(c))


func test_discard_goes_to_matching_pile() -> void:
	var s: MatchState = play_match()
	DeckSystem.discard(s, CardInstance.new(s.new_uid(), "dis_flood"))
	DeckSystem.discard(s, CardInstance.new(s.new_uid(), "res_funds"))
	assert_eq(s.disaster_discard.size(), 1)
	assert_eq(s.town_discard.size(), 1)

extends TestCase
## The UI's damage previews and "why can't I" explanations come from the rules code. These tests
## pin them to what resolution actually does.


func _flood_forecast(s: MatchState, target: int, base: int) -> void:
	var pd: PendingDisaster = PendingDisaster.new()
	pd.seq = 1
	pd.caster_id = 0
	pd.card_def_id = "dis_flood"
	pd.disaster_id = "disaster_flood"
	pd.level = 2
	pd.base_damage = base
	pd.targets = [target] as Array[int]
	pd.is_forecast = true
	s.forecasts.append(pd)


func test_preview_matches_actual_damage_with_buildings_and_territory() -> void:
	var s: MatchState = play_match()
	add_building(s, 1, "bld_seawall")
	add_building(s, 1, "bld_drainage_system")
	var dis: DisasterDefinition = s.catalog.disaster("disaster_flood")
	var pv: Dictionary = DamageCalculator.preview(s, s.players[1], dis, 0, 5)
	# Riverside is weak to flood (+1): 5 + 1 - 3 - 1 = 2.
	assert_eq(int(pv["min"]), 2)
	assert_eq(int(pv["max"]), 2)
	assert_eq(int(pv["territory"]), 1)
	assert_eq((pv["buildings"] as Array).size(), 2)
	# Drainage System also exempts its owner from flood forecasts, so aim an equivalent disaster
	# directly through the resolver instead.
	var pd: PendingDisaster = PendingDisaster.new()
	pd.disaster_id = "disaster_flood"
	pd.card_def_id = "dis_flood"
	pd.level = 2
	pd.base_damage = 5
	pd.targets = [1] as Array[int]
	pd.caster_id = 0
	s.pending = pd
	s.phase = MatchState.Phase.REACTION
	apply(s, PassReactionAction.new(1))
	assert_eq(20 - s.players[1].rp, int(pv["min"]), "preview equals the damage actually dealt")


func test_preview_includes_reaction_reduction() -> void:
	var s: MatchState = play_match()
	var go_bag: CardInstance = give(s, 1, "prep_go_bag")
	var dis: DisasterDefinition = s.catalog.disaster("disaster_flood")
	var before: Dictionary = DamageCalculator.preview(s, s.players[1], dis, 0, 5)
	var after: Dictionary = DamageCalculator.preview(s, s.players[1], dis, 1, 5)
	assert_eq(int(before["min"]) - int(after["min"]), 1)
	var pd: PendingDisaster = PendingDisaster.new()
	pd.disaster_id = "disaster_flood"
	pd.card_def_id = "dis_flood"
	pd.level = 2
	pd.base_damage = 5
	pd.targets = [1] as Array[int]
	s.pending = pd
	s.phase = MatchState.Phase.REACTION
	apply(s, ReactAction.new(1, go_bag.uid, [] as Array[int]))
	assert_eq(20 - s.players[1].rp, int(after["min"]))


func test_preview_range_follows_the_disasters_base_range() -> void:
	var s: MatchState = play_match()
	var dis: DisasterDefinition = s.catalog.disaster("disaster_flood")
	var pv: Dictionary = DamageCalculator.preview(s, s.players[0], dis)
	assert_eq(int(pv["base_min"]), 4)
	assert_eq(int(pv["base_max"]), 5)
	assert_eq(int(pv["max"]) - int(pv["min"]), 1)


func test_damage_text_names_every_contribution() -> void:
	var s: MatchState = play_match()
	add_building(s, 1, "bld_seawall")
	var dis: DisasterDefinition = s.catalog.disaster("disaster_flood")
	var line: String = DamageText.preview_line(s, 1, dis, 1, 5)
	assert_true(line.contains("base 5"), line)
	assert_true(line.contains("territory +1"), line)
	assert_true(line.contains("Seawall -3"), line)
	assert_true(line.contains("reaction -1"), line)


func test_explain_reasons() -> void:
	var s: MatchState = started_match()
	for p: PlayerState in s.players:
		p.hand.clear()
	var seawall: CardInstance = give(s, 0, "bld_seawall")
	var mat: CardInstance = give(s, 0, "res_materials")
	var go_bag: CardInstance = give(s, 0, "prep_go_bag")
	var theirs: CardInstance = give(s, 1, "bld_seawall")
	assert_eq(s.phase, MatchState.Phase.DRAW)
	assert_eq(ActionEnumerator.explain(s, 0, seawall.uid), "Draw a card first.")
	assert_eq(ActionEnumerator.explain(s, 1, theirs.uid), "Not your turn.")
	s.phase = MatchState.Phase.PLAY
	s.plays_remaining = 1
	assert_true(ActionEnumerator.explain(s, 0, seawall.uid).begins_with("Cannot afford it"), "only one Materials in hand")
	assert_true(ActionEnumerator.explain(s, 0, go_bag.uid).begins_with("Reactions are played"))
	assert_true(ActionEnumerator.explain(s, 0, mat.uid).contains("spent automatically"))
	give(s, 0, "res_materials")
	assert_eq(ActionEnumerator.explain(s, 0, seawall.uid), "", "affordable now")
	s.plays_remaining = 0
	assert_eq(ActionEnumerator.explain(s, 0, seawall.uid), "No plays left this turn.")
	s.plays_remaining = 1
	var bay: CardInstance = give(s, 0, "prep_bayanihan")
	give(s, 0, "res_supplies")
	assert_eq(ActionEnumerator.explain(s, 0, bay.uid), "You have no damaged building to repair.")


func test_explain_matches_legal_actions() -> void:
	var s: MatchState = play_match()
	give_n(s, 0, "res_materials", 2)
	var seawall: CardInstance = give(s, 0, "bld_seawall")
	var unaffordable: CardInstance = give(s, 0, "bld_evacuation_center")
	var acts: Array[GameAction] = ActionEnumerator.legal_actions(s)
	var usable: Dictionary = {}
	for a: GameAction in acts:
		if a is PlayCardAction:
			usable[(a as PlayCardAction).card_uid] = true
	assert_true(usable.has(seawall.uid))
	assert_eq(ActionEnumerator.explain(s, 0, seawall.uid), "")
	assert_false(usable.has(unaffordable.uid))
	assert_ne(ActionEnumerator.explain(s, 0, unaffordable.uid), "")

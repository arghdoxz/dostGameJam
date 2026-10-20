class_name TutorialScript
extends RefCounted
## The tutorial lesson plan for TutorialScenario. Every step teaches something the game really
## does; each ACTION step is finished by doing it in the real UI. Completion tests only look at
## the match state (and the few UI facts in TutorialContext), so an off-script click can never
## leave a step impossible to finish without the Skip button.


static func build() -> Array[TutorialStep]:
	var out: Array[TutorialStep] = []

	var s: TutorialStep = TutorialStep.action("welcome", "Welcome, Mayor",
		"You are the mayor of a town with 20 Resilience Points (RP). Build defenses and strike your rival with disasters.\n\n"
		+ "You WIN by being the last town standing, by completing the Preparedness goal, or by having the most RP after round 10. "
		+ "A town at 0 RP is eliminated.\n\n"
		+ "This tutorial is a 2-player hot-seat game and you play BOTH mayors: Ana (first) and Ben. "
		+ "The dark screen hides a player's cards while the device changes hands. Press \"I am ready\".",
		"cover_ready", func(c: TutorialContext) -> bool: return not c.cover_visible, "Cover closed.")
	s.over_cover = true
	out.append(s)

	out.append(TutorialStep.info("board", "The table",
		"The map in the middle shows each town as a region, with its buildings as tokens and incoming disasters as hazard tokens. "
		+ "Click a region (or a player's mat) to choose a disaster target. The decks are at the bottom corners.", "map"))
	out.append(TutorialStep.info("seat", "Your mat",
		"Your mat shows your RP bar, your territory (it resists one hazard and is weak to others), and counts of cards in Hand and Reserve. "
		+ "\"Prep n/3\" counts Preparedness goals. Hover a mat for the full list of buildings.", "seat_actor"))
	out.append(TutorialStep.info("header", "The status bar",
		"The top bar shows the round, whose turn it is, the current phase and a hint about what you can do. "
		+ "A turn is: Draw one card, Play one card, End Turn.", "header"))

	s = TutorialStep.action("draw", "Draw a card",
		"Every turn starts by drawing one card. The Town deck holds resources, buildings and preparedness cards; "
		+ "the Disaster deck holds disasters. Click either deck.", "piles",
		func(c: TutorialContext) -> bool: return c.state.phase != MatchState.Phase.DRAW or c.state.current_player != 0 \
			or c.state.round_number > 1,
		"You drew a card.")
	s.intent = func(st: MatchState) -> Array: return [DrawAction.new(0, CardDefinition.DeckKind.TOWN)]
	out.append(s)

	s = TutorialStep.action("select_seawall", "Select a card",
		"Your hand is fanned along the bottom. Click the Seawall to select it. Cards that cannot be used right now are dimmed.",
		"card:bld_seawall",
		func(c: TutorialContext) -> bool: return c.selected_def == "bld_seawall" or c.me().has_building("bld_seawall"),
		"Seawall selected.")
	s.ui_selected = "bld_seawall"
	out.append(s)

	out.append(TutorialStep.info("read_panel", "Read the card",
		"The panel on the right explains the selected card: what it does, what it costs, and a button for each thing you can do with it. "
		+ "The Seawall costs 2 Materials and cuts Flood and Storm Surge damage by 3. Each time a building reduces damage it loses durability.",
		"actions"))

	s = TutorialStep.action("build_seawall", "Build the Seawall",
		"Press the \"Play\" button. Its cost is paid automatically by discarding the Materials named on the button "
		+ "(\"Choose payment...\" lets you pick the cards yourself). You get one play per turn.", "actions",
		func(c: TutorialContext) -> bool: return c.me().has_building("bld_seawall"),
		"Seawall built: it now shows on your region of the map.")
	s.ui_selected = "bld_seawall"
	s.intent = func(st: MatchState) -> Array: return [_find_play(st, 0, "bld_seawall")]
	out.append(s)

	s = TutorialStep.action("bank_supplies", "Bank Supplies",
		"Supplies are special. Select the Supplies card and press \"Bank in Reserve\". It is free and uses no play. "
		+ "Reserve Supplies can still be spent later, and 3 of them count toward the Preparedness win.", "card:res_supplies",
		func(c: TutorialContext) -> bool: return c.me().reserve.size() >= 1,
		"Supplies banked: Reserve is now 1.")
	s.ui_selected = "res_supplies"
	s.intent = func(st: MatchState) -> Array: return [_find_reserve(st, 0)]
	out.append(s)

	s = TutorialStep.action("why_not", "Why can't I play this?",
		"Select Barangay Drill. It is a Reaction card, so it cannot be played now. When a card is unusable, "
		+ "the panel explains why instead of just doing nothing.", "card:prep_barangay_drill",
		func(c: TutorialContext) -> bool: return c.selected_def == "prep_barangay_drill" or c.state.current_player != 0 \
			or c.state.round_number > 1,
		"Now you know where to look when a card is dimmed.")
	s.ui_selected = "prep_barangay_drill"
	out.append(s)

	s = TutorialStep.action("end_turn_you", "End your turn",
		"You have used your play. Press End Turn. (If you hold more than 7 cards you must discard down first.)", "end_turn",
		func(c: TutorialContext) -> bool: return c.state.current_player != 0 or c.state.round_number > 1,
		"Turn over. Play passes to Ben.")
	s.intent = func(st: MatchState) -> Array: return [EndTurnAction.new(0)]
	out.append(s)

	s = TutorialStep.action("draw_rival", "Ben: draw",
		"It is Ben's turn now. Draw a card from either deck.", "piles",
		func(c: TutorialContext) -> bool: return c.state.current_player != 1 or c.state.phase != MatchState.Phase.DRAW \
			or c.state.round_number > 1,
		"Ben drew a card.")
	s.intent = func(st: MatchState) -> Array: return [DrawAction.new(1, CardDefinition.DeckKind.DISASTER)]
	out.append(s)

	s = TutorialStep.action("select_landslide", "Pick a disaster",
		"Select the Landslide disaster card. The panel shows the predicted damage to each town it could hit.", "card:dis_landslide",
		func(c: TutorialContext) -> bool: return c.selected_def == "dis_landslide" or c.state.pending != null \
			or c.state.round_number > 1,
		"Landslide selected.")
	s.ui_selected = "dis_landslide"
	out.append(s)

	s = TutorialStep.action("pick_target", "Choose a target",
		"Landslide hits one rival. Click \"Ana\" on the map or on her mat to aim it. A disaster can never target its own caster.",
		"seat:0",
		func(c: TutorialContext) -> bool: return c.chosen_target == 0 or c.state.pending != null or c.state.round_number > 1,
		"Target chosen.")
	s.ui_selected = "dis_landslide"
	s.ui_target = 0
	out.append(s)

	s = TutorialStep.action("cast_landslide", "Cast it",
		"Press \"Play on Ana\". A Minor (level 1) disaster strikes immediately, but the target gets a chance to react first.",
		"actions",
		func(c: TutorialContext) -> bool: return c.state.pending != null or c.has_event("disaster_cast") or c.state.round_number > 1,
		"Landslide cast.")
	s.ui_selected = "dis_landslide"
	s.ui_target = 0
	s.intent = func(st: MatchState) -> Array: return [_find_play(st, 1, "dis_landslide", 0)]
	out.append(s)

	s = TutorialStep.action("react", "Reaction window",
		"A disaster is striking you! The panel lists the damage. Select Go Bag and press \"React with this card\" to cut the damage by 1, "
		+ "or press \"Do not react\". Everyone hit gets this window, in turn order.", "disaster",
		func(c: TutorialContext) -> bool: return c.state.phase != MatchState.Phase.REACTION or c.state.round_number > 1,
		"Reaction done. Damage is calculated next.")
	s.over_cover = false
	s.ui_selected = "prep_go_bag"
	s.intent = func(st: MatchState) -> Array: return [_find_react(st, 0, "prep_go_bag")]
	out.append(s)

	s = TutorialStep.action("summary_landslide", "What happened",
		"After a disaster this panel lists the damage and anything destroyed. Your RP dropped; the Seawall did not help because it only "
		+ "reduces Flood and Storm Surge. Press Continue.", "summary",
		func(c: TutorialContext) -> bool: return (c.summary_seen and not c.summary_visible) or (c.age > 8.0 and not c.cover_visible and not c.summary_visible),
		"Summary closed.")
	s.over_summary = true
	out.append(s)

	s = TutorialStep.action("end_turn_rival", "End Ben's turn",
		"Press End Turn.", "end_turn",
		func(c: TutorialContext) -> bool: return c.state.round_number > 1,
		"Round 2 begins.")
	s.intent = func(st: MatchState) -> Array: return [EndTurnAction.new(1)]
	out.append(s)

	s = TutorialStep.action("draw_round2", "Round 2: draw",
		"A round is one full turn for every player. Draw a card as Ana again.", "piles",
		func(c: TutorialContext) -> bool: return c.state.round_number > 1 and (c.state.current_player != 0 \
			or c.state.phase != MatchState.Phase.DRAW),
		"Drawn.")
	s.intent = func(st: MatchState) -> Array: return [DrawAction.new(0, CardDefinition.DeckKind.TOWN)]
	out.append(s)

	s = TutorialStep.action("select_typhoon", "A bigger disaster",
		"Select the Typhoon. It is a Severe (level 2) disaster that hits every opponent and costs 1 resource card.", "card:dis_typhoon",
		func(c: TutorialContext) -> bool: return c.selected_def == "dis_typhoon" or not c.state.forecasts.is_empty(),
		"Typhoon selected.")
	s.ui_selected = "dis_typhoon"
	out.append(s)

	s = TutorialStep.action("cast_typhoon", "Cast it as a Forecast",
		"Press \"Play\". Level 2 and 3 disasters do not hit at once. They become a public FORECAST on the map "
		+ "and strike at the start of your NEXT turn. That gives Ben a full turn to prepare.", "actions",
		func(c: TutorialContext) -> bool: return not c.state.forecasts.is_empty(),
		"Forecast placed: see the hazard token on Ben's region.")
	s.ui_selected = "dis_typhoon"
	s.intent = func(st: MatchState) -> Array: return [_find_play(st, 0, "dis_typhoon")]
	out.append(s)

	s = TutorialStep.action("summary_forecast", "The warning",
		"The forecast is announced here and stays visible on Ben's region until it resolves. Press Continue.", "summary",
		func(c: TutorialContext) -> bool: return (c.summary_seen and not c.summary_visible) or (c.age > 8.0 and not c.cover_visible and not c.summary_visible),
		"Summary closed.")
	s.over_summary = true
	out.append(s)

	s = TutorialStep.action("end_turn_you2", "End your turn",
		"Press End Turn.", "end_turn",
		func(c: TutorialContext) -> bool: return c.state.current_player != 0,
		"Turn over.")
	s.intent = func(st: MatchState) -> Array: return [EndTurnAction.new(0)]
	out.append(s)

	s = TutorialStep.action("rival_prepares", "Ben: your warning turn",
		"Ben has seen the Typhoon coming. This is the warning turn: build, bank Supplies, or keep a Reaction card ready. "
		+ "Just draw a card to continue.", "piles",
		func(c: TutorialContext) -> bool: return c.state.current_player != 1 or c.state.phase != MatchState.Phase.DRAW,
		"Drawn.")
	s.intent = func(st: MatchState) -> Array: return [DrawAction.new(1, CardDefinition.DeckKind.TOWN)]
	out.append(s)

	s = TutorialStep.action("end_turn_rival2", "End Ben's turn",
		"Press End Turn. The Typhoon resolves at the start of the next turn.", "end_turn",
		func(c: TutorialContext) -> bool: return c.state.current_player != 1 or c.state.round_number > 2,
		"The Typhoon arrives.")
	s.intent = func(st: MatchState) -> Array: return [EndTurnAction.new(1)]
	out.append(s)

	s = TutorialStep.action("react_forecast", "The forecast arrives",
		"The Typhoon strikes Ben. He may react with a Reaction card from his hand "
		+ "(Pre-emptive Evacuation costs 1 resource and cuts 2 damage) or press \"Do not react\".", "disaster",
		func(c: TutorialContext) -> bool: return c.state.phase != MatchState.Phase.REACTION,
		"Typhoon resolved.")
	s.ui_selected = "prep_preemptive_evacuation"
	s.intent = func(st: MatchState) -> Array: return [PassReactionAction.new(st.actor_id())]
	out.append(s)

	s = TutorialStep.action("summary_typhoon", "Damage and destruction",
		"The summary shows Ben's damage and any extra effects (a Typhoon also discards a random card). "
		+ "Buildings that reduce damage lose durability and are destroyed at 0. Press Continue.", "summary",
		func(c: TutorialContext) -> bool: return (c.summary_seen and not c.summary_visible) or (c.age > 8.0 and not c.cover_visible and not c.summary_visible),
		"Summary closed.")
	s.over_summary = true
	out.append(s)

	s = TutorialStep.action("draw_round3", "Recover: draw",
		"Back to Ana. Draw a card.", "piles",
		func(c: TutorialContext) -> bool: return c.state.round_number > 2 and c.state.phase != MatchState.Phase.DRAW,
		"Drawn.")
	s.intent = func(st: MatchState) -> Array: return [DrawAction.new(0, CardDefinition.DeckKind.TOWN)]
	out.append(s)

	s = TutorialStep.action("heal", "Recover RP",
		"The Landslide hurt you. Select Relief Operations and press Play: it heals 3 RP (never above 20). "
		+ "It costs 1 Supplies; the button says which card pays (a Supplies card in your hand or in your Reserve).", "card:prep_relief_operations",
		func(c: TutorialContext) -> bool: return c.has_event("healed"),
		"Healed.")
	s.ui_selected = "prep_relief_operations"
	s.intent = func(st: MatchState) -> Array: return [_find_play(st, 0, "prep_relief_operations")]
	out.append(s)

	out.append(TutorialStep.info("endgame", "How games end",
		"A town at 0 RP is eliminated: its cards and buildings are discarded. If one town is left, it wins. "
		+ "If several fall at once the town with more building durability before the blow wins. "
		+ "You also win at the start of your turn if you own an Evacuation Center and an Early Warning System and hold 3+ Supplies in Reserve. "
		+ "After round 10, forecasts still waiting resolve first, then the highest RP wins.", "seat_actor"))

	out.append(TutorialStep.info("tools", "Helpful buttons",
		"\"Log\" shows everything that has happened. \"Restart\" and \"Menu\" (after a confirmation) leave the match. "
		+ "Hover a card, deck or mat for a tooltip. Illegal moves show a message at the bottom of the board.", "log"))

	out.append(TutorialStep.info("finish", "You're ready!",
		"That is the whole game. Start a real match with your own names and territories, or replay this lesson any time from the main menu.", ""))
	return out


# ---------------------------------------------------------------- engine helpers (tests)

static func _uid_of(state: MatchState, pid: int, def_id: String) -> int:
	for c: CardInstance in state.players[pid].hand:
		if c.def_id == def_id:
			return c.uid
	return -1


static func _find_play(state: MatchState, pid: int, def_id: String, target: int = -1) -> GameAction:
	var uid: int = _uid_of(state, pid, def_id)
	for a: GameAction in ActionEnumerator.legal_actions(state):
		if a is PlayCardAction and (a as PlayCardAction).card_uid == uid:
			if target < 0 or (a as PlayCardAction).target_player_id == target:
				return a
	return null


static func _find_reserve(state: MatchState, pid: int) -> GameAction:
	var uid: int = _uid_of(state, pid, "res_supplies")
	return ReserveAction.new(pid, uid)


static func _find_react(state: MatchState, pid: int, def_id: String) -> GameAction:
	var uid: int = _uid_of(state, pid, def_id)
	for a: GameAction in ActionEnumerator.legal_actions(state):
		if a is ReactAction and (a as ReactAction).card_uid == uid:
			return a
	return PassReactionAction.new(pid)

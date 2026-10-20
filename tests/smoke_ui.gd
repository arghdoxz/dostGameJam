extends SceneTree
## UI smoke test: boots the real App scene and drives it through the controller and the screens'
## own code paths. Covers: setup -> board (seat/slot layout, map regions, hand fan), the disaster
## panel during a Reaction window, leaving mid-reaction, the payment picker, a bot playing to
## game over, the results screen, rematch, and 4-player seating. Run with:
##   godot --headless --path . -s res://tests/smoke_ui.gd
## Exit code 0 on success.

var _app: Node
var _step: int = 0
var _wait: int = 0
var _steps: Array[Callable] = []
var _bot: RandomNumberGenerator = RandomNumberGenerator.new()
var _checks: int = 0


func _initialize() -> void:
	_bot.seed = 5
	_app = (load("res://scenes/boot/app.tscn") as PackedScene).instantiate()
	root.add_child(_app)
	_steps = [
		_step_show_setup, _step_start_from_setup, _step_check_board_2p, _step_bot_to_reaction,
		_step_check_disaster_panel, _step_leave_mid_reaction, _step_restart_fresh, _step_payment_picker,
		_step_bot_to_game_over, _step_check_results, _step_rematch, _step_four_players,
		_step_tutorial_start, _step_tutorial_progress, _step_tutorial_restarted, _step_tutorial_exited,
		_step_double_click_lock, _step_long_card_start, _step_long_card_select, _step_long_card_layout,
		_step_forecast_arrives_setup, _step_forecast_arrives_check, _step_setup_error_clears,
		_step_big_hand_start, _step_big_hand_check, _step_done,
	]


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _step >= _steps.size():
		return false
	var c: Callable = _steps[_step]
	_step += 1
	_wait = 3
	c.call()
	return false


# ---------------------------------------------------------------- helpers

func _ctrl() -> MatchController:
	return _app.get("controller") as MatchController


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c: Node in n.get_children():
		out.append_array(_all(c))
	return out


func _first(script_class: Variant) -> Node:
	for n: Node in _all(_app):
		if is_instance_of(n, script_class):
			return n
	return null


func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		push_error("UI SMOKE FAIL: " + msg)
		print("UI SMOKE FAIL: " + msg)
		quit(1)


func _seats(n: int) -> Array[Dictionary]:
	var cat: ContentCatalog = root.get_node("ContentDB").get("catalog") as ContentCatalog
	var ids: Array[String] = cat.territory_ids()
	ids.sort()
	var out: Array[Dictionary] = []
	for i: int in range(n):
		out.append({"name": "Mayor %d" % (i + 1), "territory_id": ids[i]})
	return out


func _bot_act() -> void:
	var ctrl: MatchController = _ctrl()
	var actions: Array[GameAction] = ctrl.legal_actions()
	var pick: GameAction = actions[_bot.randi_range(0, actions.size() - 1)]
	if pick is EndTurnAction or pick is PassReactionAction or _bot.randf() < 0.6:
		ctrl.submit(pick)
	else:
		ctrl.submit(actions[actions.size() - 1])


func _screen_script() -> String:
	var s: Node = _app.get("current_screen") as Node
	return String(s.get_script().resource_path) if s != null and s.get_script() != null else ""


# ---------------------------------------------------------------- steps

func _step_show_setup() -> void:
	_app.call("show_setup")


func _step_start_from_setup() -> void:
	# Drive the real setup screen: default 2 players with distinct territories.
	(_app.get("current_screen") as Node).call("_on_start")


func _step_check_board_2p() -> void:
	var ctrl: MatchController = _ctrl()
	_expect(ctrl.state != null and ctrl.state.players.size() == 2, "setup screen did not start a 2-player match")
	_expect(_screen_script().ends_with("match_screen.gd"), "match screen not showing")
	var board: BoardView = _first(BoardView) as BoardView
	var hand: HandFan = _first(HandFan) as HandFan
	var map: MapView = _first(MapView) as MapView
	_expect(board != null and hand != null and map != null, "board, hand fan or map missing")
	var actor: int = ctrl.state.actor_id()
	var slots: Dictionary = BoardView.slots_for(ctrl.state, actor)
	_expect(int(slots[actor]) == 0, "the acting player must sit at the near edge")
	_expect(board.seat_view(actor) != null and board.seat_view(1 - actor) != null, "a seat view is missing")
	_expect(map._regions.size() == 2, "map should have one region per player")
	# The acting player's hand is fanned: one CardView per card.
	var cards: int = 0
	for n: Node in _all(hand):
		if n is CardView:
			cards += 1
	_expect(cards == ctrl.state.players[actor].hand.size(), "hand fan should show every card in hand")
	# Selecting a card shows its description in the action panel.
	hand.select(ctrl.state.players[actor].hand[0].uid)
	hand.card_selected.emit(ctrl.state.players[actor].hand[0].uid)


func _step_bot_to_reaction() -> void:
	var ctrl: MatchController = _ctrl()
	for i: int in range(3000):
		if ctrl.state.is_over() or ctrl.state.phase == MatchState.Phase.REACTION:
			break
		_bot_act()
	_expect(ctrl.state.phase == MatchState.Phase.REACTION, "the bot never opened a Reaction window")


func _step_check_disaster_panel() -> void:
	var panel: DisasterPanel = _first(DisasterPanel) as DisasterPanel
	_expect(panel != null and panel.visible, "disaster panel must show during a Reaction window")
	var s: MatchState = _ctrl().state
	var board: BoardView = _first(BoardView) as BoardView
	_expect(int(BoardView.slots_for(s, s.actor_id())[s.actor_id()]) == 0, "the reactor sits at the near edge")
	_expect(board.seat_view(s.actor_id()) != null, "reactor seat exists")
	# BUG-016: a seat card must not grow taller than the slot BoardView reserves for it, or it
	# covers the top of the map region behind it.
	for p: PlayerState in s.players:
		var need: float = board.seat_view(p.id).get_combined_minimum_size().y
		_expect(need <= SeatView.SEAT_SIZE.y, "seat %d needs %.0f px but the slot is %.0f" % [p.id, need, SeatView.SEAT_SIZE.y])
	# BUG-010: the card in the middle of the map must be the disaster that is striking.
	var shown: CardDefinition = board.last_play.shown_card()
	_expect(shown != null and shown.id == s.pending.card_def_id,
		"the last-play card must show the disaster in the Reaction window (shows %s, pending %s)" % [
			shown.id if shown != null else "nothing", s.pending.card_def_id])


func _step_leave_mid_reaction() -> void:
	var screen: Node = _app.get("current_screen") as Node
	screen.call("_ask_leave", false)
	var confirm: ConfirmDialog = _first(ConfirmDialog) as ConfirmDialog
	_expect(confirm != null and confirm.visible, "leave confirmation should open")
	confirm.accepted.emit()


func _step_restart_fresh() -> void:
	_expect(_screen_script().ends_with("main_menu.gd"), "leaving should return to the main menu")
	_expect(not _ctrl().has_match(), "the match must be abandoned")
	var err: String = String(_app.call("start_match", _seats(2), 99))
	_expect(err == "", "a fresh match should start after abandoning: " + err)
	var s: MatchState = _ctrl().state
	_expect(s.phase == MatchState.Phase.DRAW and s.pending == null and s.forecasts.is_empty() and s.round_number == 1,
		"the new match must be clean")


func _step_payment_picker() -> void:
	var ctrl: MatchController = _ctrl()
	var s: MatchState = ctrl.state
	var actor: int = s.actor_id()
	ctrl.submit(DrawAction.new(actor, CardDefinition.DeckKind.TOWN))
	ctrl.debug_give_card(actor, "bld_seawall")
	ctrl.debug_give_card(actor, "res_materials")
	ctrl.debug_give_card(actor, "res_materials")
	var seawall_uid: int = -1
	for c: CardInstance in s.players[actor].hand:
		if c.def_id == "bld_seawall":
			seawall_uid = c.uid
	var action: PlayCardAction = null
	for a: GameAction in ctrl.legal_actions():
		if a is PlayCardAction and (a as PlayCardAction).card_uid == seawall_uid:
			action = a as PlayCardAction
	_expect(action != null and not action.payment_uids.is_empty(), "a payable Seawall play should be offered")
	var picker: PaymentPicker = _first(PaymentPicker) as PaymentPicker
	picker.open(s, action)
	_expect(picker.visible, "payment picker should open")
	_expect(not picker._confirm.disabled, "the automatic payment is valid, so Confirm is enabled")
	# Un-tick one card: payment becomes invalid and Confirm must disable.
	for k: Variant in picker._boxes.keys():
		(picker._boxes[k] as CheckBox).button_pressed = false
	_expect(picker._confirm.disabled, "an empty payment must not be confirmable")
	picker._auto_select()
	_expect(not picker._confirm.disabled, "auto-select restores a valid payment")
	var logged: int = ctrl.action_log.size()
	picker._on_confirm()
	_expect(ctrl.action_log.size() == logged + 1, "confirming the payment should submit the play")
	_expect(s.players[actor].has_building("bld_seawall"), "the Seawall should be built")


func _step_bot_to_game_over() -> void:
	var ctrl: MatchController = _ctrl()
	for i: int in range(8000):
		if ctrl.state.is_over():
			break
		_bot_act()
	_expect(ctrl.state.is_over(), "the match did not finish")
	_app.call("show_game_over")


func _step_check_results() -> void:
	_expect(_screen_script().ends_with("game_over_screen.gd"), "GameOver screen is not showing")


func _step_rematch() -> void:
	var screen: Node = _app.get("current_screen") as Node
	screen.emit_signal("rematch_requested")
	var s: MatchState = _ctrl().state
	_expect(_screen_script().ends_with("match_screen.gd"), "rematch should show a match screen")
	_expect(not s.is_over() and s.round_number == 1 and s.forecasts.is_empty(), "rematch must start clean")
	_expect(_ctrl().action_log.is_empty(), "rematch must clear the old action log")


func _step_four_players() -> void:
	var err: String = String(_app.call("start_match", _seats(4), 21))
	_expect(err == "", "4-player match should start: " + err)
	var s: MatchState = _ctrl().state
	var slots: Dictionary = BoardView.slots_for(s, s.actor_id())
	var used: Dictionary = {}
	for k: Variant in slots.keys():
		used[slots[k]] = true
	_expect(used.size() == 4, "four players need four distinct table slots")
	_expect(int(slots[s.actor_id()]) == 0, "the actor sits at the near edge")
	var map: MapView = _first(MapView) as MapView
	_expect(map._regions.size() == 4, "four map regions")


func _step_tutorial_start() -> void:
	_app.call("show_main_menu")
	var btn: Button = null
	for n: Node in _all(_app):
		if n is Button and (n as Button).text.begins_with("How to Play"):
			btn = n as Button
	_expect(btn != null, "the main menu must offer the tutorial")
	btn.pressed.emit()
	_expect(_screen_script().ends_with("match_screen.gd"), "the tutorial should open a match screen")
	var coach: TutorialCoach = _first(TutorialCoach) as TutorialCoach
	_expect(coach != null, "the tutorial must show the coach overlay")
	_expect(coach.current_step().id == "welcome", "the tutorial starts at the welcome step")
	var s: MatchState = _ctrl().state
	_expect(s.players[0].display_name == "Ana" and s.actor_id() == 0, "the learner goes first")
	var cover: PassDeviceScreen = _first(PassDeviceScreen) as PassDeviceScreen
	_expect(cover.visible, "the hot-seat cover is shown first")
	cover.ready_button().pressed.emit()


func _step_tutorial_progress() -> void:
	var coach: TutorialCoach = _first(TutorialCoach) as TutorialCoach
	_expect(coach.step_index() >= 1, "closing the cover completes the welcome step")
	# Skip step and Next work from the UI buttons without a state change.
	var before: int = coach.step_index()
	for n: Node in _all(coach):
		if n is Button and (n as Button).text == "Next" and (n as Button).is_visible_in_tree():
			(n as Button).pressed.emit()
			break
	_expect(coach.step_index() == before + 1, "Next advances an info step")
	# Restart goes back to a fresh tutorial.
	coach.restart_requested.emit()


func _step_tutorial_restarted() -> void:
	var coach: TutorialCoach = _first(TutorialCoach) as TutorialCoach
	_expect(coach != null and coach.step_index() == 0, "Restart tutorial begins again at step 1")
	_expect(_ctrl().state.round_number == 1 and _ctrl().action_log.is_empty(), "restarted tutorial match is fresh")
	coach.exit_requested.emit()


func _step_tutorial_exited() -> void:
	_expect(_screen_script().ends_with("main_menu.gd"), "Exit tutorial returns to the menu")
	_expect(_first(TutorialCoach) == null, "no coach is left behind")
	_expect(not _ctrl().has_match(), "exiting abandons the tutorial match")
	var err: String = String(_app.call("start_match", _seats(2), 77))
	_expect(err == "", "a normal match starts after the tutorial: " + err)
	_expect(_first(TutorialCoach) == null, "a normal match never has a tutorial coach")


func _step_double_click_lock() -> void:
	var ctrl: MatchController = _ctrl()
	for i: int in range(3000):
		if ctrl.state.is_over() or ctrl.state.phase == MatchState.Phase.REACTION:
			break
		_bot_act()
	_expect(ctrl.state.phase == MatchState.Phase.REACTION, "the bot should reach a Reaction window")
	var panel: DisasterPanel = _first(DisasterPanel) as DisasterPanel
	_expect(not panel._pass.disabled, "Do not react starts enabled")
	var logged: int = ctrl.action_log.size()
	panel._on_pass_pressed()
	_expect(panel._pass.disabled, "Do not react locks briefly so a double-click cannot pass the next window")
	_expect(ctrl.action_log.size() == logged + 1, "the first click passes exactly once")


var _board_height: float = 0.0


## BUG-001 regression: a long card description must neither resize the table nor push the action
## buttons out of the action panel / off the screen.
func _step_long_card_start() -> void:
	var err: String = String(_app.call("start_match", _seats(2), 31))
	_expect(err == "", "match for the layout check should start: " + err)
	var ctrl: MatchController = _ctrl()
	var actor: int = ctrl.state.actor_id()
	ctrl.submit(DrawAction.new(actor, CardDefinition.DeckKind.TOWN))
	ctrl.debug_give_card(actor, "dis_typhoon")
	ctrl.debug_give_card(actor, "res_materials")


func _step_long_card_select() -> void:
	var ctrl: MatchController = _ctrl()
	var actor: int = ctrl.state.actor_id()
	_board_height = (_first(BoardView) as BoardView).size.y
	_expect(_board_height > 100.0, "the table should be laid out before the check")
	var typhoon_uid: int = -1
	for c: CardInstance in ctrl.state.players[actor].hand:
		if c.def_id == "dis_typhoon":
			typhoon_uid = c.uid
	var hand: HandFan = _first(HandFan) as HandFan
	hand.select(typhoon_uid)
	hand.card_selected.emit(typhoon_uid)


func _step_long_card_layout() -> void:
	var board: BoardView = _first(BoardView) as BoardView
	_expect(absf(board.size.y - _board_height) < 1.0, "selecting a long card must not resize the table (%f vs %f)" % [board.size.y, _board_height])
	var panel: ActionPanel = _first(ActionPanel) as ActionPanel
	var screen: Rect2 = _app.get_viewport().get_visible_rect()
	var panel_rect: Rect2 = panel.get_global_rect()
	var buttons: int = 0
	for n: Node in _all(panel):
		if n is Button and (n as Button).is_visible_in_tree():
			buttons += 1
			var r: Rect2 = (n as Button).get_global_rect()
			_expect(screen.encloses(r), "action button %s is off screen: %s" % [(n as Button).text, str(r)])
			_expect(panel_rect.grow(1.0).encloses(r), "action button %s is clipped by the panel: %s vs %s" % [(n as Button).text, str(r), str(panel_rect)])
	_expect(buttons >= 1, "the Typhoon should offer a Play button")


## BUG-014 regression: a big hand must stay inside the hand area (tilted corners included), so the
## outer cards are not cut off by the screen edge or pushed under the action panel.
func _step_big_hand_start() -> void:
	var err: String = String(_app.call("start_match", _seats(2), 51))
	_expect(err == "", "match for the big-hand check should start: " + err)
	var ctrl: MatchController = _ctrl()
	var actor: int = ctrl.state.actor_id()
	for i: int in range(6):
		ctrl.debug_give_card(actor, "res_funds")
	_expect(ctrl.state.players[actor].hand.size() >= 12, "the actor should hold a big hand")


func _step_big_hand_check() -> void:
	var hand: HandFan = _first(HandFan) as HandFan
	var area: Rect2 = hand.get_global_rect().grow(1.0)
	# A few pixels of slack: the bottom corners of the tilted outer cards dip about a pixel below the row.
	var screen: Rect2 = _app.get_viewport().get_visible_rect().grow(4.0)
	var cards: int = 0
	for n: Node in _all(hand):
		if not (n is CardView):
			continue
		cards += 1
		var cv: CardView = n as CardView
		var xf: Transform2D = cv.get_global_transform()
		for corner: Vector2 in [Vector2.ZERO, Vector2(cv.size.x, 0.0), Vector2(0.0, cv.size.y), cv.size]:
			var p: Vector2 = xf * corner
			_expect(screen.has_point(p), "a card corner is off screen at %s" % str(p))
			_expect(p.x >= area.position.x and p.x <= area.end.x, "a card corner leaves the hand area at x=%.0f (area %.0f to %.0f)" % [p.x, area.position.x, area.end.x])
	_expect(cards >= 12, "all cards in a big hand are shown")


func _play_def(ctrl: MatchController, pid: int, def_id: String) -> bool:
	for c: CardInstance in ctrl.state.players[pid].hand:
		if c.def_id != def_id:
			continue
		for a: GameAction in ctrl.legal_actions():
			if a is PlayCardAction and (a as PlayCardAction).card_uid == c.uid:
				return ctrl.submit(a)
	return false


## BUG-010 regression: when a forecast arrives turns after it was cast, the card in the middle of
## the map must be that disaster, not whatever card was played last.
func _step_forecast_arrives_setup() -> void:
	var err: String = String(_app.call("start_match", _seats(2), 41))
	_expect(err == "", "match for the forecast check should start: " + err)
	var ctrl: MatchController = _ctrl()
	var a: int = ctrl.state.actor_id()
	var b: int = 1 - a
	ctrl.submit(DrawAction.new(a, CardDefinition.DeckKind.TOWN))
	ctrl.debug_give_card(a, "dis_typhoon")
	ctrl.debug_give_card(a, "res_materials")
	_expect(_play_def(ctrl, a, "dis_typhoon"), "the Typhoon should be castable")
	_expect(not ctrl.state.forecasts.is_empty(), "the Typhoon becomes a forecast")
	ctrl.submit(EndTurnAction.new(a, ActionEnumerator.default_discards(ctrl.state, ctrl.state.players[a])))
	ctrl.submit(DrawAction.new(b, CardDefinition.DeckKind.TOWN))
	ctrl.debug_give_card(b, "bld_seawall")
	ctrl.debug_give_card(b, "res_materials")
	ctrl.debug_give_card(b, "res_materials")
	_expect(_play_def(ctrl, b, "bld_seawall"), "the opponent should be able to build a Seawall")
	ctrl.submit(EndTurnAction.new(b, ActionEnumerator.default_discards(ctrl.state, ctrl.state.players[b])))


func _step_forecast_arrives_check() -> void:
	var s: MatchState = _ctrl().state
	_expect(s.phase == MatchState.Phase.REACTION and s.pending != null and s.pending.is_forecast,
		"the forecast should have arrived and opened a Reaction window")
	var shown: CardDefinition = (_first(BoardView) as BoardView).last_play.shown_card()
	_expect(shown != null and shown.id == "dis_typhoon",
		"the last-play card must show the arriving Typhoon, not the last card played (shows %s)" % [
			shown.id if shown != null else "nothing"])


## BUG-008 regression: an old setup error must not outlive the change that fixed it.
func _step_setup_error_clears() -> void:
	_app.call("show_setup")
	var setup: Node = _app.get("current_screen") as Node
	var err_label: Label = setup.get("_error") as Label
	err_label.text = "Territories must be distinct"
	setup.call("_refresh_rows")
	_expect(err_label.text == "", "changing the player count clears the setup error")
	err_label.text = "Territories must be distinct"
	var opt: OptionButton = (setup.get("_territories") as Array)[0] as OptionButton
	opt.item_selected.emit(1)
	_expect(err_label.text == "", "changing a territory clears the setup error")


func _step_done() -> void:
	print("UI SMOKE OK: %d checks passed (board layout, disaster panel, leave mid-reaction, payment picker, results, rematch, 4 seats, tutorial, double-click lock)" % _checks)
	quit(0)

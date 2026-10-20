extends Control
## The match screen: header, tabletop board (seats, map, decks), the acting player's hand fan,
## the selected card's action panel, and the dialogs. It composes the view components and
## re-renders from MatchController signals. It submits GameActions and never changes state itself.

signal quit_to_menu
signal restart_requested
signal match_finished

var controller: MatchController
var _header: TurnHeader
var _board: BoardView
var _hand: HandFan
var _actions: ActionPanel
var _disaster: DisasterPanel
var _log: EventLog
var _log_panel: PanelContainer
var _summary: ResolutionSummary
var _payment: PaymentPicker
var _discard: DiscardDialog
var _confirm: ConfirmDialog
var _cover: PassDeviceScreen
var _banner: Button
var _status: Label
var _debug: DebugPanel

var _shown_actor: int = -2
var _chosen_target: int = -1
var _queued_events: Array[GameEvent] = []
var _result_notes: Dictionary = {}
var _last_card_id: String = ""
var _last_text: String = ""
var _connected: bool = false
var _leave_is_restart: bool = false


func bind(p_controller: MatchController) -> void:
	controller = p_controller
	_build()
	controller.events_emitted.connect(_on_events)
	controller.state_changed.connect(_refresh)
	controller.action_rejected.connect(_on_rejected)
	controller.match_abandoned.connect(_on_abandoned)
	_connected = true
	_log.append_events(_start_events(), controller.state)
	_refresh()


func _exit_tree() -> void:
	_disconnect_controller()


func _disconnect_controller() -> void:
	if not _connected or controller == null:
		return
	_connected = false
	if controller.events_emitted.is_connected(_on_events):
		controller.events_emitted.disconnect(_on_events)
	if controller.state_changed.is_connected(_refresh):
		controller.state_changed.disconnect(_refresh)
	if controller.action_rejected.is_connected(_on_rejected):
		controller.action_rejected.disconnect(_on_rejected)
	if controller.match_abandoned.is_connected(_on_abandoned):
		controller.match_abandoned.disconnect(_on_abandoned)


func _start_events() -> Array[GameEvent]:
	var s: MatchState = controller.state
	var out: Array[GameEvent] = []
	out.append(GameEvent.new("match_started", {"first_player": s.first_player, "seed": s.seed_value}))
	out.append(GameEvent.new("turn_started", {"player": s.current_player, "round": s.round_number}))
	return out


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 6
	root.offset_right = -8
	root.offset_bottom = -6
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	_header = TurnHeader.new()
	_header.end_turn_requested.connect(_on_end_turn)
	_header.log_toggled.connect(func(on: bool) -> void: _log_panel.visible = on)
	_header.restart_requested.connect(func() -> void: _ask_leave(true))
	_header.menu_requested.connect(func() -> void: _ask_leave(false))
	root.add_child(_header)

	_banner = Button.new()
	_banner.text = "GAME OVER - View results"
	_banner.visible = false
	_banner.pressed.connect(func() -> void: match_finished.emit())
	root.add_child(_banner)

	_board = BoardView.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.draw_requested.connect(_on_draw)
	_board.target_chosen.connect(_on_target_chosen)
	root.add_child(_board)

	_status = Label.new()
	_status.custom_minimum_size = Vector2(0, 24)
	_status.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	root.add_child(_status)

	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 236)
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	# The disaster panel only shows during a Reaction window; the hand fan takes the space back.
	_disaster = DisasterPanel.new()
	_disaster.pass_requested.connect(func() -> void:
		controller.submit(PassReactionAction.new(controller.state.actor_id())))
	bottom.add_child(_disaster)
	_hand = HandFan.new()
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand.card_selected.connect(_on_card_selected)
	bottom.add_child(_hand)
	_actions = ActionPanel.new()
	_actions.action_chosen.connect(_on_action_chosen)
	_actions.payment_requested.connect(func(a: GameAction) -> void: _payment.open(controller.state, a))
	bottom.add_child(_actions)

	_log_panel = PanelContainer.new()
	_log_panel.anchor_left = 1.0
	_log_panel.anchor_right = 1.0
	_log_panel.anchor_top = 0.0
	_log_panel.anchor_bottom = 1.0
	_log_panel.offset_left = -360
	_log_panel.offset_right = -8
	_log_panel.offset_top = 48
	_log_panel.offset_bottom = -250
	_log_panel.visible = false
	_log = EventLog.new()
	_log_panel.add_child(_log)
	add_child(_log_panel)

	_summary = ResolutionSummary.new()
	_summary.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_summary.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_summary.grow_vertical = Control.GROW_DIRECTION_BOTH
	_summary.z_index = 150
	add_child(_summary)

	_payment = PaymentPicker.new()
	_payment.confirmed.connect(_on_action_chosen)
	add_child(_payment)
	_discard = DiscardDialog.new()
	_discard.confirmed.connect(_on_discard_confirmed)
	add_child(_discard)
	_confirm = ConfirmDialog.new()
	_confirm.accepted.connect(_on_leave_accepted)
	add_child(_confirm)

	_debug = DebugPanel.new()
	_debug.bind(controller)
	add_child(_debug)

	_cover = PassDeviceScreen.new()
	_cover.z_index = 300
	_cover.ready_pressed.connect(_flush_summary)
	add_child(_cover)


## UI facts the tutorial coach needs (read only).
func tutorial_info() -> Dictionary:
	var s: MatchState = controller.state
	var sel_def: String = ""
	if s != null and not s.is_over():
		var actor: int = s.actor_id()
		var sel: int = _hand.selected_uid()
		if actor >= 0 and sel >= 0:
			var c: CardInstance = s.players[actor].find_in_hand(sel)
			if c != null:
				sel_def = c.def_id
	return {
		"selected_def": sel_def,
		"chosen_target": _chosen_target,
		"cover_visible": _cover.visible,
		"summary_visible": _summary.visible,
	}


## Screen rectangles for a tutorial highlight key (empty when it is not on screen).
## Keys: map, header, end_turn, log, piles (both decks), hand, card:<def_id>, actions, disaster,
## summary, cover_ready, seat_actor, seat:<player id>.
func highlight_rects(key: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if key == "piles":
		for kind: CardDefinition.DeckKind in [CardDefinition.DeckKind.TOWN, CardDefinition.DeckKind.DISASTER]:
			var pile: Control = _board.pile(kind)
			if pile.is_visible_in_tree():
				out.append(pile.get_global_rect())
		return out
	var r: Rect2 = _highlight_rect(key)
	if r.size.x > 0.0 and r.size.y > 0.0:
		out.append(r)
	return out


func _highlight_rect(key: String) -> Rect2:
	var s: MatchState = controller.state
	var c: Control = null
	if key.begins_with("card:"):
		return _hand.card_rect(key.substr(5))
	if key.begins_with("seat:") and s != null:
		c = _board.seat_view(int(key.substr(5)))
	match key:
		"map":
			c = _board.map
		"header":
			c = _header
		"end_turn":
			c = _header.end_turn_button()
		"log":
			c = _header.log_button()
		"hand":
			c = _hand
		"actions":
			c = _actions
		"disaster":
			c = _disaster
		"summary":
			c = _summary
		"cover_ready":
			c = _cover.ready_button()
		"seat_actor":
			if s != null and s.actor_id() >= 0:
				c = _board.seat_view(s.actor_id())
	if c == null or not c.is_visible_in_tree():
		return Rect2()
	return c.get_global_rect()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F1:
		_debug.visible = not _debug.visible


# ---------------------------------------------------------------- input handlers

func _on_rejected(reason: String) -> void:
	_status.text = "Not allowed: " + reason


func _on_abandoned() -> void:
	_disconnect_controller()


func _on_draw(kind: CardDefinition.DeckKind) -> void:
	_status.text = ""
	controller.submit(DrawAction.new(controller.state.current_player, kind))


func _on_end_turn() -> void:
	_status.text = ""
	var s: MatchState = controller.state
	var player: PlayerState = s.current()
	var excess: int = player.hand.size() - s.config.hand_limit
	if excess > 0:
		_discard.open(s, player, excess)
		return
	controller.submit(EndTurnAction.new(player.id))


func _on_discard_confirmed(uids: Array[int]) -> void:
	controller.submit(EndTurnAction.new(controller.state.current_player, uids))


func _on_card_selected(_uid: int) -> void:
	_chosen_target = -1
	_status.text = ""
	_refresh()


func _on_action_chosen(action: GameAction) -> void:
	_status.text = ""
	_chosen_target = -1
	controller.submit(action)


func _on_target_chosen(pid: int) -> void:
	var s: MatchState = controller.state
	if s == null or s.is_over():
		return
	var uid: int = _hand.selected_uid()
	for a: GameAction in controller.legal_actions():
		if a is PlayCardAction and (a as PlayCardAction).card_uid == uid and (a as PlayCardAction).target_player_id == pid:
			_chosen_target = pid
			_status.text = ""
			_refresh()
			return
	_status.text = "Select a single-target Disaster card first, then click the town you want to strike."


func _ask_leave(restart: bool) -> void:
	var title: String = "Restart the match?" if restart else "Leave the match?"
	var msg: String = "The current match will be abandoned. Any disaster in progress is cancelled and nothing is saved."
	_leave_is_restart = restart
	_confirm.ask(title, msg, "Restart" if restart else "Leave to menu")


func _on_leave_accepted() -> void:
	controller.abandon()
	if _leave_is_restart:
		restart_requested.emit()
	else:
		quit_to_menu.emit()


# ---------------------------------------------------------------- events and rendering

func _on_events(events: Array[GameEvent]) -> void:
	_log.append_events(events, controller.state)
	_queued_events.append_array(events)
	var hit_uids: Array[int] = []
	var results: Dictionary = {}
	var any_damage: bool = false
	for e: GameEvent in events:
		match e.type:
			"card_played":
				_last_card_id = String(e.data["def"])
				_last_text = "%s played %s" % [controller.state.players[int(e.data["player"])].display_name,
					controller.state.catalog.card(_last_card_id).display_name]
			"reaction_played":
				_last_card_id = String(e.data["card"])
				_last_text = "%s reacted" % controller.state.players[int(e.data["player"])].display_name
			"disaster_revealed":
				# The centre card must match the centre text. A forecast that arrives was cast
				# turns ago, so the last played card would otherwise be an unrelated one (BUG-010).
				_last_card_id = "dis_" + String(e.data["disaster"]).trim_prefix("disaster_")
				_last_text = "DISASTER: %s" % controller.state.catalog.card(_last_card_id).display_name
			"damage_dealt":
				any_damage = true
				var pid: int = int(e.data["player"])
				results[pid] = _append_note(results.get(pid, ""), "HIT -%d, RP %d" % [int(e.data["amount"]), int(e.data["rp"])])
			"building_damaged":
				hit_uids.append(int(e.data["building"]))
			"building_destroyed":
				var bp: int = int(e.data["player"])
				results[bp] = _append_note(results.get(bp, ""), "%s DESTROYED" % controller.state.catalog.card(String(e.data["def"])).display_name)
			"player_eliminated":
				var ep: int = int(e.data["player"])
				results[ep] = _append_note(results.get(ep, ""), "ELIMINATED")
	if any_damage:
		_result_notes = results
	elif not events.is_empty():
		_result_notes = {}
	_board.map.note_damaged(hit_uids)


func _append_note(existing: Variant, add: String) -> String:
	var cur: String = String(existing)
	return add if cur == "" else cur + "; " + add


func _refresh() -> void:
	var s: MatchState = controller.state
	if s == null:
		return
	var actor: int = s.actor_id()
	_header.refresh(s)
	var reasons: Dictionary = {}
	if actor >= 0 and not s.is_over():
		for c: CardInstance in s.players[actor].hand:
			reasons[c.uid] = ActionEnumerator.explain(s, actor, c.uid)
	_hand.refresh(s, actor, reasons)
	var actions: Array[GameAction] = controller.legal_actions()
	var sel: int = _hand.selected_uid()
	var sel_def: CardDefinition = null
	if sel >= 0 and actor >= 0:
		var sc: CardInstance = s.players[actor].find_in_hand(sel)
		if sc != null:
			sel_def = s.catalog.card(sc.def_id)
	_actions.refresh(s, actor, sel, actions, _chosen_target)
	_disaster.refresh(s)
	_banner.visible = s.is_over()
	var statuses: Dictionary = _statuses(s, actor)
	var notes: Dictionary = _notes(s, actor, sel_def, actions)
	var targetable: Dictionary = _targetable(s, sel, actions)
	var last_def: CardDefinition = s.catalog.card(_last_card_id) if _last_card_id != "" else null
	_board.refresh(s, actor, statuses, notes, targetable, notes, last_def, _last_text)
	if s.is_over():
		_cover.hide()
	elif actor != _shown_actor:
		_shown_actor = actor
		var detail: String = "Your turn." if s.phase != MatchState.Phase.REACTION else "A disaster is striking. You may react."
		_cover.show_for(s.players[actor].display_name, detail)
	if not _cover.visible:
		_flush_summary()


func _flush_summary() -> void:
	if _queued_events.is_empty():
		return
	var events: Array[GameEvent] = _queued_events.duplicate()
	_queued_events.clear()
	_summary.show_for(events, controller.state)


func _statuses(s: MatchState, actor: int) -> Dictionary:
	var out: Dictionary = {}
	for p: PlayerState in s.players:
		var t: String = ""
		if p.eliminated:
			t = "ELIMINATED"
		elif s.is_over():
			t = "Final: RP %d" % p.rp
		elif s.phase == MatchState.Phase.REACTION and s.pending != null:
			if p.id == actor:
				t = "REACTING NOW"
			elif s.pending.targets.has(p.id):
				t = "Reaction done" if s.pending.targets.find(p.id) < s.pending.reactor_index else "Waiting to react"
			elif p.id == s.pending.caster_id:
				t = "Cast the disaster"
		elif p.id == actor:
			t = "ACTING NOW"
		out[p.id] = t
	return out


## Region/seat notes: live damage predictions during a Reaction window, previews for the selected
## Disaster card, and the results of the last resolution.
func _notes(s: MatchState, actor: int, sel_def: CardDefinition, actions: Array[GameAction]) -> Dictionary:
	var out: Dictionary = {}
	for pid: Variant in _result_notes.keys():
		out[int(pid)] = String(_result_notes[pid])
	if s.is_over():
		return out
	if s.phase == MatchState.Phase.REACTION and s.pending != null:
		var pd: PendingDisaster = s.pending
		var dis: DisasterDefinition = s.catalog.disaster(pd.disaster_id)
		for pid: int in pd.targets:
			var pv: Dictionary = DamageCalculator.preview(s, s.players[pid], dis, int(pd.reductions.get(pid, 0)), pd.base_damage)
			out[pid] = "STRIKE: %d damage expected" % int(pv["max"])
	elif sel_def is DisasterCardDef and actor >= 0:
		var d2: DisasterDefinition = (sel_def as DisasterCardDef).disaster
		var single: bool = d2.targeting == DisasterDefinition.Targeting.SINGLE_OPPONENT
		var ids: Array[int] = []
		if single:
			for p: PlayerState in s.players:
				if p.id != actor and not p.eliminated:
					ids.append(p.id)
		else:
			ids = DisasterResolver.compute_targets(s, actor, d2, -1)
		for pid2: int in ids:
			var pv2: Dictionary = DamageCalculator.preview(s, s.players[pid2], d2)
			var lo: int = int(pv2["min"])
			var hi: int = int(pv2["max"])
			var rng: String = str(lo) if lo == hi else "%d-%d" % [lo, hi]
			var prefix: String = "TARGET CHOSEN" if (single and pid2 == _chosen_target) else ("CAN TARGET" if single else "WOULD HIT")
			out[pid2] = "%s: %s damage" % [prefix, rng]
	return out


func _targetable(s: MatchState, sel: int, actions: Array[GameAction]) -> Dictionary:
	var out: Dictionary = {}
	if s.is_over() or sel < 0:
		return out
	for a: GameAction in actions:
		if a is PlayCardAction and (a as PlayCardAction).card_uid == sel and (a as PlayCardAction).target_player_id >= 0:
			out[(a as PlayCardAction).target_player_id] = true
	return out

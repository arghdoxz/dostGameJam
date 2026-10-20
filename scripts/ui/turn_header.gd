class_name TurnHeader
extends HBoxContainer
## Top bar: round, who acts, the phase with a plain-language hint of what is available,
## and the turn buttons. Decks are drawn by clicking the piles on the board.

signal end_turn_requested
signal log_toggled(visible_now: bool)
signal restart_requested
signal menu_requested

var _info: Label
var _end_turn: Button
var _log: Button


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.clip_text = true
	add_child(_info)
	_end_turn = Button.new()
	_end_turn.text = "End Turn"
	_end_turn.pressed.connect(func() -> void: end_turn_requested.emit())
	add_child(_end_turn)
	_log = Button.new()
	_log.text = "Log"
	_log.toggle_mode = true
	_log.tooltip_text = "Show or hide the event log"
	_log.toggled.connect(func(on: bool) -> void: log_toggled.emit(on))
	add_child(_log)
	var restart: Button = Button.new()
	restart.text = "Restart"
	restart.pressed.connect(func() -> void: restart_requested.emit())
	add_child(restart)
	var menu: Button = Button.new()
	menu.text = "Menu"
	menu.pressed.connect(func() -> void: menu_requested.emit())
	add_child(menu)


## Buttons the tutorial outlines.
func end_turn_button() -> Button:
	return _end_turn


func log_button() -> Button:
	return _log


func refresh(state: MatchState) -> void:
	if state == null:
		return
	var actor: String = "" if state.is_over() else state.players[state.actor_id()].display_name
	var phase_text: String = ""
	var hint: String = ""
	match state.phase:
		MatchState.Phase.DRAW:
			phase_text = "Draw"
			hint = "click the Town deck or Disaster deck to draw"
		MatchState.Phase.PLAY:
			phase_text = "Play (%d play%s left)" % [state.plays_remaining, "" if state.plays_remaining == 1 else "s"]
			hint = "select a card, bank Supplies, or End Turn"
		MatchState.Phase.REACTION:
			phase_text = "Reaction window"
			hint = "play a Reaction card or pass"
		MatchState.Phase.GAME_OVER:
			phase_text = "Game over"
	var turn_owner: String = ""
	if not state.is_over() and state.phase != MatchState.Phase.REACTION:
		turn_owner = "  |  %s's turn" % actor
	elif state.phase == MatchState.Phase.REACTION:
		turn_owner = "  |  %s reacts (turn of %s)" % [actor, state.current().display_name]
	var round_text: String = "Round %d/%d" % [state.round_number, state.config.round_cap]
	_info.text = "%s%s  |  %s%s" % [round_text, turn_owner, phase_text, ("  -  " + hint) if hint != "" else ""]
	_end_turn.disabled = state.phase != MatchState.Phase.PLAY
	_end_turn.tooltip_text = "" if not _end_turn.disabled else "You can end your turn during the Play phase."

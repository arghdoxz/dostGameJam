class_name DiscardDialog
extends ModalPanel
## Lets the active player choose which cards to discard to reach the hand limit when ending
## the turn. Cancel returns to the turn without ending it.

signal confirmed(uids: Array[int])
signal cancelled

var _checks: Dictionary = {}
var _needed: int = 0
var _confirm: Button
var _count: Label


func open(state: MatchState, player: PlayerState, needed: int) -> void:
	_needed = needed
	_checks.clear()
	clear_content()
	content.add_child(UiTheme.heading_label("Hand limit"))
	content.add_child(make_label("Your hand limit is %d. Choose exactly %d card(s) to discard." % [state.config.hand_limit, needed]))
	for c: CardInstance in player.hand:
		var cb: CheckBox = CheckBox.new()
		var def: CardDefinition = state.catalog.card(c.def_id)
		cb.text = "%s (%s)" % [def.display_name, CardText.type_name(def)]
		cb.toggled.connect(func(_on: bool) -> void: _update())
		content.add_child(cb)
		_checks[c.uid] = cb
	_count = make_label("")
	content.add_child(_count)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var cancel: Button = Button.new()
	cancel.text = "Cancel (keep playing)"
	cancel.pressed.connect(func() -> void:
		close_modal()
		cancelled.emit())
	row.add_child(cancel)
	_confirm = Button.new()
	_confirm.text = "Discard selected and end turn"
	_confirm.pressed.connect(func() -> void:
		close_modal()
		confirmed.emit(_selected()))
	row.add_child(_confirm)
	_update()
	open_modal()


func _selected() -> Array[int]:
	var out: Array[int] = []
	for uid: Variant in _checks.keys():
		if (_checks[uid] as CheckBox).button_pressed:
			out.append(int(uid))
	return out


func _update() -> void:
	var n: int = _selected().size()
	_confirm.disabled = n != _needed
	_count.text = "Selected %d of %d." % [n, _needed]

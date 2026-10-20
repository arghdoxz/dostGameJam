class_name PaymentPicker
extends ModalPanel
## Lets the player choose exactly which resource cards (hand or Reserve Supplies) pay a cost.
## Starts from the engine's automatic choice. Confirm stays disabled until Payment.check passes,
## and the reason is shown while it fails.

signal confirmed(action: GameAction)
signal cancelled

var _state: MatchState
var _player: PlayerState
var _action: GameAction
var _cost: Dictionary = {}
var _boxes: Dictionary = {}
var _status: Label
var _confirm: Button


## action is a PlayCardAction or ReactAction whose payment is the starting suggestion.
func open(state: MatchState, action: GameAction) -> void:
	if state == null:
		return
	_state = state
	_action = action
	_player = state.players[action.player_id]
	var card_uid: int = _card_of(action)
	var card: CardInstance = _player.find_in_hand(card_uid)
	if card == null:
		return
	var def: CardDefinition = state.catalog.card(card.def_id)
	_cost = def.cost
	clear_content()
	_boxes.clear()
	content.add_child(UiTheme.heading_label("Pay for %s" % def.display_name))
	content.add_child(make_label("Cost: %s. Tick exactly the cards to spend. Spent cards are discarded." % def.cost_text()))
	var current: Array[int] = _payment_of(action)
	for c: CardInstance in _player.hand:
		if c.uid != card_uid and Payment.kind_of(state.catalog, c) != "":
			_add_option(c, "hand", current)
	for c: CardInstance in _player.reserve:
		_add_option(c, "Reserve", current)
	_status = make_label("")
	content.add_child(_status)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var cancel: Button = Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void:
		close_modal()
		cancelled.emit())
	row.add_child(cancel)
	var auto: Button = Button.new()
	auto.text = "Auto-select"
	auto.pressed.connect(_auto_select)
	row.add_child(auto)
	_confirm = Button.new()
	_confirm.text = "Confirm payment"
	_confirm.pressed.connect(_on_confirm)
	row.add_child(_confirm)
	_update()
	open_modal()


func _add_option(c: CardInstance, where: String, current: Array[int]) -> void:
	var cb: CheckBox = CheckBox.new()
	cb.text = "%s (%s)" % [_state.catalog.card(c.def_id).display_name, where]
	cb.button_pressed = current.has(c.uid)
	cb.toggled.connect(func(_on: bool) -> void: _update())
	content.add_child(cb)
	_boxes[c.uid] = cb


func _chosen() -> Array[int]:
	var out: Array[int] = []
	for uid: Variant in _boxes.keys():
		if (_boxes[uid] as CheckBox).button_pressed:
			out.append(int(uid))
	out.sort()
	return out


func _update() -> void:
	var reason: String = Payment.check(_state, _player, _cost, _chosen())
	_confirm.disabled = reason != ""
	_status.text = "Payment is valid." if reason == "" else "Not valid yet: " + reason


func _auto_select() -> void:
	var pay: Dictionary = Payment.auto_pay(_state, _player, _cost)
	var uids: Array[int] = pay["uids"] as Array[int]
	for uid: Variant in _boxes.keys():
		(_boxes[uid] as CheckBox).button_pressed = uids.has(int(uid))
	_update()


func _on_confirm() -> void:
	var uids: Array[int] = _chosen()
	var out: GameAction
	if _action is ReactAction:
		out = ReactAction.new(_action.player_id, (_action as ReactAction).card_uid, uids)
	else:
		var src: PlayCardAction = _action as PlayCardAction
		var a: PlayCardAction = PlayCardAction.new(src.player_id, src.card_uid, uids)
		a.target_player_id = src.target_player_id
		a.target_building_uid = src.target_building_uid
		out = a
	close_modal()
	confirmed.emit(out)


func _card_of(a: GameAction) -> int:
	if a is ReactAction:
		return (a as ReactAction).card_uid
	return (a as PlayCardAction).card_uid


func _payment_of(a: GameAction) -> Array[int]:
	if a is ReactAction:
		return (a as ReactAction).payment_uids
	return (a as PlayCardAction).payment_uids

class_name ActionPanel
extends PanelContainer
## Details for the selected card: rules text, what it costs and what it would pay, what a
## disaster would do to each target, and one button per legal action. When nothing is legal it
## says why. It builds GameActions but never applies them.

signal action_chosen(action: GameAction)
signal payment_requested(action: GameAction)

## Most action buttons shown before the button list scrolls.
const MAX_VISIBLE_BUTTONS: int = 3
const BUTTON_ROW_HEIGHT: float = 39.0

var _text: Label
var _preview: Label
var _flavor: Label
var _why: Label
var _buttons: VBoxContainer
var _button_scroll: ScrollContainer


## Layout rule: the description scrolls, the action buttons never do (up to MAX_VISIBLE_BUTTONS).
## A long card text must never push the buttons off screen or resize the table above (BUG-001).
func _ready() -> void:
	custom_minimum_size = Vector2(430, 0)
	clip_contents = true
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var text_scroll: ScrollContainer = ScrollContainer.new()
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(text_scroll)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	text_scroll.add_child(texts)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(390, 0)
	texts.add_child(_text)
	_preview = UiTheme.small_label()
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.custom_minimum_size = Vector2(390, 0)
	texts.add_child(_preview)
	_flavor = UiTheme.small_label()
	_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor.custom_minimum_size = Vector2(390, 0)
	texts.add_child(_flavor)
	_why = Label.new()
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.custom_minimum_size = Vector2(390, 0)
	box.add_child(_why)
	_button_scroll = ScrollContainer.new()
	_button_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_button_scroll)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button_scroll.add_child(_buttons)


## chosen_target is the opponent picked by clicking a seat or region (-1 for none).
func refresh(state: MatchState, actor_id: int, uid: int, actions: Array[GameAction], chosen_target: int) -> void:
	for b: Node in _buttons.get_children():
		_buttons.remove_child(b)
		b.queue_free()
	_button_scroll.custom_minimum_size.y = 0.0
	_preview.text = ""
	_flavor.text = ""
	_why.text = ""
	if state == null or actor_id < 0 or state.is_over():
		_text.text = ""
		return
	var player: PlayerState = state.players[actor_id]
	var card: CardInstance = player.find_in_hand(uid) if uid >= 0 else null
	if card == null:
		_text.text = _idle_hint(state)
		return
	var def: CardDefinition = state.catalog.card(card.def_id)
	_text.text = CardText.header_text(def, state.catalog)
	_preview.text = _damage_preview(state, actor_id, def)
	_flavor.text = CardText.flavor_text(def)
	var options: Array[GameAction] = []
	for a: GameAction in actions:
		if _card_uid(a) == uid:
			options.append(a)
	if chosen_target >= 0:
		var narrowed: Array[GameAction] = []
		for a: GameAction in options:
			if a is PlayCardAction and (a as PlayCardAction).target_player_id == chosen_target:
				narrowed.append(a)
		if not narrowed.is_empty():
			options = narrowed
	if options.is_empty():
		_why.text = "Cannot use now: " + ActionEnumerator.explain(state, actor_id, uid)
		return
	for a: GameAction in options:
		_add_action(a, state, player)
	_button_scroll.custom_minimum_size.y = float(mini(options.size(), MAX_VISIBLE_BUTTONS)) * BUTTON_ROW_HEIGHT


func _idle_hint(state: MatchState) -> String:
	match state.phase:
		MatchState.Phase.DRAW:
			return "Draw one card from the Town deck or the Disaster deck to begin your turn."
		MatchState.Phase.REACTION:
			return "Select a Reaction card to see its effect, or choose Do not react."
		_:
			return "Select a card in your hand to see what it does, what it costs, and why it can or cannot be used."


func _card_uid(a: GameAction) -> int:
	if a is PlayCardAction:
		return (a as PlayCardAction).card_uid
	if a is ReserveAction:
		return (a as ReserveAction).card_uid
	if a is ReactAction:
		return (a as ReactAction).card_uid
	return -1


## One line per target: what this disaster would do to them right now.
func _damage_preview(state: MatchState, actor_id: int, def: CardDefinition) -> String:
	if not (def is DisasterCardDef):
		return ""
	var dis: DisasterDefinition = (def as DisasterCardDef).disaster
	var lines: PackedStringArray = PackedStringArray()
	for pid: int in _candidate_targets(state, actor_id, dis):
		lines.append(DamageText.preview_line(state, pid, dis, 0, -1))
	if lines.is_empty():
		return "No eligible targets: this disaster would fizzle (the cost is still paid)."
	var out: String = "Predicted damage per target:\n" + "\n".join(lines)
	if dis.level >= 2:
		out += "\nForecast: targets get a warning turn and can react or build."
		if state.round_number >= state.config.round_cap:
			out += "\nFinal round: this resolves when the match ends."
	return out


func _candidate_targets(state: MatchState, actor_id: int, dis: DisasterDefinition) -> Array[int]:
	var out: Array[int] = []
	if dis.targeting == DisasterDefinition.Targeting.SINGLE_OPPONENT:
		for p: PlayerState in state.players:
			if p.id != actor_id and not p.eliminated:
				out.append(p.id)
		return out
	return DisasterResolver.compute_targets(state, actor_id, dis, -1)


func _add_action(a: GameAction, state: MatchState, player: PlayerState) -> void:
	var btn: Button = Button.new()
	btn.text = describe_action(a, state, player)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(func() -> void: action_chosen.emit(a))
	var row: HBoxContainer = HBoxContainer.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(btn)
	var pay: Array[int] = _payment_of(a)
	if not pay.is_empty():
		var pick: Button = Button.new()
		pick.text = "Choose payment..."
		pick.pressed.connect(func() -> void: payment_requested.emit(a))
		row.add_child(pick)
	_buttons.add_child(row)


func _payment_of(a: GameAction) -> Array[int]:
	if a is PlayCardAction:
		return (a as PlayCardAction).payment_uids
	if a is ReactAction:
		return (a as ReactAction).payment_uids
	return [] as Array[int]


## Button text that names the action, its target and the cards it will spend.
static func describe_action(a: GameAction, state: MatchState, player: PlayerState) -> String:
	if a is ReserveAction:
		return "Bank in Reserve (free, uses no play)"
	var pay_text: String = ""
	var pay_uids: Array[int] = []
	if a is ReactAction:
		pay_uids = (a as ReactAction).payment_uids
	elif a is PlayCardAction:
		pay_uids = (a as PlayCardAction).payment_uids
	if not pay_uids.is_empty():
		pay_text = "  [pays: %s]" % payment_names(state, player, pay_uids)
	if a is ReactAction:
		return "React with this card" + pay_text
	var p: PlayCardAction = a as PlayCardAction
	if p.target_player_id >= 0:
		var t: PlayerState = state.players[p.target_player_id]
		return "Play on %s (%s)%s" % [t.display_name, state.catalog.territory(t.territory_id).display_name, pay_text]
	if p.target_building_uid >= 0:
		var b: BuildingInstance = player.find_building(p.target_building_uid)
		if b != null:
			return "Repair %s (%d/%d)%s" % [state.catalog.card(b.def_id).display_name, b.durability,
				state.catalog.building(b.def_id).durability, pay_text]
	return "Play" + pay_text


static func payment_names(state: MatchState, player: PlayerState, uids: Array[int]) -> String:
	var names: PackedStringArray = PackedStringArray()
	for uid: int in uids:
		var c: CardInstance = player.find_in_hand(uid)
		var where: String = ""
		if c == null:
			c = player.find_in_reserve(uid)
			where = " (Reserve)"
		if c != null:
			names.append(state.catalog.card(c.def_id).display_name + where)
	return ", ".join(names)

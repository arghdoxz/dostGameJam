class_name LastPlayView
extends Control
## "What just happened" in one glance: the last card played (small) and a line of text such as
## "Ana played Seawall" or "DISASTER: Typhoon". It sits in the top-left corner of the table, outside
## the map, so it never covers a town region, its building tokens or a forecast marker (BUG-005).
## Display only; it never changes state.

const CARD_SCALE: float = 0.5

var _card: CardView
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300.0, CardView.CARD_SIZE.y * CARD_SCALE)
	_card = CardView.new()
	_card.pivot_offset = Vector2.ZERO
	_card.scale = Vector2(CARD_SCALE, CARD_SCALE)
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_label = UiTheme.small_label()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(CardView.CARD_SIZE.x * CARD_SCALE + 8.0, 4.0)
	_label.size = Vector2(220.0, 70.0)
	add_child(_label)


## def is null before anything has been played.
func show_play(def: CardDefinition, text: String) -> void:
	if def != null:
		_card.visible = true
		_card.setup(def, -1, true, false)
		_card.hide_badge()
		_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_card.visible = false
	_label.text = text


## The card currently shown (null when none); used by the UI smoke test.
func shown_card() -> CardDefinition:
	return _card.def if _card != null and _card.visible else null

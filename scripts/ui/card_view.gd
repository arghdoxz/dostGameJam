class_name CardView
extends Control
## One card, drawn from layers: card art, optional frame overlay, name, type and cost text.
## Every layer is a replaceable asset via AssetLibrary. A face-down mode shows the card back.
## Positioning and tilt belong to the parent (HandFan, seat fans); this node only draws.

signal card_pressed(uid: int)
signal card_hovered(uid: int, hovering: bool)

const CARD_SIZE: Vector2 = Vector2(126, 176)

var uid: int = 0
var def: CardDefinition
var playable: bool = false
var selected: bool = false

var _panel: Panel
var _art: TextureRect
var _frame: TextureRect
var _name: Label
var _type: Label
var _cost: Label
var _badge: Label


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.position = Vector2(6, 38)
	_art.size = Vector2(CARD_SIZE.x - 12, 66)
	add_child(_art)
	_frame = TextureRect.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	# Two-line name (12 px) and two-line cost (11 px) so "Evacuation Center" and
	# "Cost: 2 funds, 2 materials" are not cut off (BUG-009).
	_name = _make_label(12, Vector2(6, 3), Vector2(CARD_SIZE.x - 12, 34))
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_type = _make_label(11, Vector2(6, 104), Vector2(CARD_SIZE.x - 12, 16))
	_cost = _make_label(11, Vector2(6, 120), Vector2(CARD_SIZE.x - 12, 32))
	_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_badge = _make_label(11, Vector2(6, 154), Vector2(CARD_SIZE.x - 12, 18))
	mouse_entered.connect(func() -> void: card_hovered.emit(uid, true))
	mouse_exited.connect(func() -> void: card_hovered.emit(uid, false))


func _make_label(font_size: int, pos: Vector2, label_size: Vector2) -> Label:
	var l: Label = Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos
	l.size = label_size
	l.clip_text = true
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


## Face-up card. playable and selected are shown with text/border, never color alone.
func setup(p_def: CardDefinition, p_uid: int, p_playable: bool, p_selected: bool) -> void:
	def = p_def
	uid = p_uid
	playable = p_playable
	selected = p_selected
	_art.visible = true
	_art.texture = AssetLibrary.get_texture("cards", def.art_id)
	_frame.visible = true
	_frame.texture = AssetLibrary.get_texture("ui", "card_frame_" + _type_key(def))
	_name.text = def.display_name
	_type.text = CardText.type_name(def)
	_cost.text = "Cost: " + def.cost_text()
	_badge.text = "Can use now" if playable else "Not usable now"
	tooltip_text = "%s [%s]\nCost: %s" % [def.display_name, CardText.type_name(def), def.cost_text()]
	_apply_style()
	modulate = Color(1, 1, 1) if playable else Color(0.72, 0.72, 0.72)


## Face-down card (decks and opponent hands). deck_kind selects the card back art.
func setup_back(deck_kind: CardDefinition.DeckKind) -> void:
	def = null
	uid = -1
	playable = false
	selected = false
	_art.visible = true
	_art.position = Vector2.ZERO
	_art.size = CARD_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.texture = AssetLibrary.get_texture("ui",
		"card_back_town" if deck_kind == CardDefinition.DeckKind.TOWN else "card_back_disaster")
	_frame.visible = false
	for l: Label in [_name, _type, _cost, _badge]:
		l.text = ""
	_apply_style()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## For display-only cards (the last played card on the map) the usability badge is noise.
func hide_badge() -> void:
	_badge.text = ""
	modulate = Color(1, 1, 1)


func _apply_style() -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.89, 0.8) if def != null else Color(0.2, 0.18, 0.25)
	sb.set_corner_radius_all(8)
	var w: int = 4 if selected else 2
	sb.set_border_width_all(w)
	sb.border_color = Color(1.0, 0.85, 0.2) if selected else Color(0.3, 0.24, 0.15)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	_panel.add_theme_stylebox_override("panel", sb)
	var ink: Color = Color(0.1, 0.08, 0.06)
	for l: Label in [_name, _type, _cost, _badge]:
		l.add_theme_color_override("font_color", ink)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_name.text = def.display_name if def != null else ""


func _type_key(d: CardDefinition) -> String:
	return CardText.type_name(d).to_lower()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and uid >= 0:
			card_pressed.emit(uid)
			accept_event()

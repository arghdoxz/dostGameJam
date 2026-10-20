class_name DeckPile
extends Button
## A deck on the table: card back, size and discard count. Clicking draws from it during the
## Draw phase; otherwise it is disabled and the tooltip says why.

signal draw_pressed(kind: CardDefinition.DeckKind)

var kind: CardDefinition.DeckKind = CardDefinition.DeckKind.TOWN


func setup(p_kind: CardDefinition.DeckKind) -> void:
	kind = p_kind
	custom_minimum_size = Vector2(120, 156)
	icon = AssetLibrary.get_texture("ui", "card_back_town" if kind == CardDefinition.DeckKind.TOWN else "card_back_disaster")
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	expand_icon = true
	add_theme_constant_override("icon_max_width", 64)
	pressed.connect(func() -> void: draw_pressed.emit(kind))


func refresh(state: MatchState) -> void:
	var name_text: String = "Town deck" if kind == CardDefinition.DeckKind.TOWN else "Disaster deck"
	text = "%s\n%d cards\ndiscard %d" % [name_text, DeckSystem.deck_of(state, kind).size(), DeckSystem.discard_of(state, kind).size()]
	var drawing: bool = state.phase == MatchState.Phase.DRAW and not state.is_over()
	var both_empty: bool = DeckSystem.both_empty(state)
	disabled = not drawing or (not DeckSystem.can_draw(state, kind) and not both_empty) \
		or (both_empty and kind != CardDefinition.DeckKind.TOWN)
	if both_empty and drawing and kind == CardDefinition.DeckKind.TOWN:
		text = "Both decks empty\nClick to skip\nyour draw"
	if state.is_over():
		tooltip_text = "The game is over."
	elif not drawing:
		tooltip_text = "You can only draw at the start of your turn."
	elif disabled:
		tooltip_text = "This deck and its discard pile are empty."
	else:
		tooltip_text = "Draw one card from the %s." % name_text.to_lower()

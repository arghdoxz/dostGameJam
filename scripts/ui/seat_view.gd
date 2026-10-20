class_name SeatView
extends PanelContainer
## A player mat at the table edge: portrait, name, territory, RP bar with number, status text,
## counts, and a fan of face-down cards for the hidden hand. All state is also written as text.
## Buildings and forecasts live on the map; this mat summarises and offers a click target.

signal seat_pressed(pid: int)

const SEAT_SIZE: Vector2 = Vector2(400, 136)

var player_id: int = 0

var _portrait: TextureRect
var _name: Label
var _territory: Label
var _rp_bar: ProgressBar
var _rp_text: Label
var _counts: Label
var _status: Label
var _hint: Label
var _fan: BackFan


func setup(pid: int) -> void:
	player_id = pid
	custom_minimum_size = SEAT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(64, 64)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.texture = AssetLibrary.get_texture("portraits", "mayor_%d" % (pid + 1))
	row.add_child(_portrait)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_name = Label.new()
	_name.clip_text = true
	col.add_child(_name)
	_territory = UiTheme.small_label()
	_territory.clip_text = true
	col.add_child(_territory)
	var rp_row: HBoxContainer = HBoxContainer.new()
	rp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rp_row)
	_rp_bar = ProgressBar.new()
	_rp_bar.show_percentage = false
	_rp_bar.custom_minimum_size = Vector2(90, 12)
	_rp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rp_row.add_child(_rp_bar)
	_rp_text = UiTheme.small_label()
	rp_row.add_child(_rp_text)
	_counts = UiTheme.small_label()
	_counts.clip_text = true
	col.add_child(_counts)
	_status = Label.new()
	_status.clip_text = true
	col.add_child(_status)
	_hint = UiTheme.small_label()
	_hint.clip_text = true
	col.add_child(_hint)
	_fan = BackFan.new()
	row.add_child(_fan)


## status is the always-visible text line (YOUR TURN, REACTING, ELIMINATED, ...). hint is a
## transient line such as a damage preview. targetable adds a thicker outline and a click prompt.
func refresh(state: MatchState, status: String, hint: String, targetable: bool) -> void:
	var p: PlayerState = state.players[player_id]
	var terr: TerritoryDefinition = state.catalog.territory(p.territory_id)
	_name.text = p.display_name
	_territory.text = terr.display_name
	_rp_bar.max_value = state.config.starting_rp
	_rp_bar.value = p.rp
	_rp_text.text = "RP %d/%d" % [p.rp, state.config.starting_rp]
	_counts.text = "Hand %d | Reserve %d | Prep %d/3" % [p.hand.size(), p.reserve.size(),
		VictoryEvaluator.objectives_completed(state, p)]
	_status.text = status
	# The hint already says "CAN TARGET" / "TARGET CHOSEN"; a longer suffix was clipped (BUG-006).
	_hint.text = hint if hint != "" else ("Click to target" if targetable else "")
	_fan.set_count(0 if p.eliminated else p.hand.size())
	modulate = Color(0.6, 0.6, 0.6) if p.eliminated else Color(1, 1, 1)
	tooltip_text = _details(state, p)
	var sb: StyleBoxFlat = (get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat)
	var heavy: bool = status != "" and not p.eliminated and (status.begins_with("ACTING") or status.begins_with("REACTING"))
	var w: int = 5 if (heavy or targetable) else 2
	sb.set_border_width_all(w)
	if targetable:
		sb.border_color = Color(1.0, 0.45, 0.3)
	elif heavy:
		sb.border_color = Color(1.0, 0.9, 0.35)
	add_theme_stylebox_override("panel", sb)


func _details(state: MatchState, p: PlayerState) -> String:
	var lines: PackedStringArray = PackedStringArray([p.display_name])
	if p.eliminated:
		lines.append("ELIMINATED")
		return "\n".join(lines)
	var terr: TerritoryDefinition = state.catalog.territory(p.territory_id)
	lines.append("%s: resists %s, weak to %s" % [terr.display_name, CardText.tag_name(terr.resist_tag), CardText.tag_list(terr.weak_tags)])
	lines.append("Buildings:")
	if p.buildings.is_empty():
		lines.append("  none")
	for b: BuildingInstance in p.buildings:
		lines.append("  %s %d/%d" % [state.catalog.card(b.def_id).display_name, b.durability,
			state.catalog.building(b.def_id).durability])
	for f: PendingDisaster in state.forecasts:
		if f.targets.has(p.id):
			lines.append("Forecast: %s (L%d) from %s" % [state.catalog.card(f.card_def_id).display_name, f.level,
				state.players[f.caster_id].display_name])
	return "\n".join(lines)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			seat_pressed.emit(player_id)
			accept_event()

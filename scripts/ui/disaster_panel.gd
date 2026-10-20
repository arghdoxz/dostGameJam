class_name DisasterPanel
extends PanelContainer
## Shown during a Reaction window. Names the disaster, its severity and caster, lists every
## affected town in order with its damage breakdown (base, territory, each building, reactions
## so far) and says who may react now. Reaction cards are played from the hand fan; this panel
## carries the "Do not react" button.

signal pass_requested

var _title: Label
var _lines: Label
var _prompt: Label
var _pass: Button


func _ready() -> void:
	custom_minimum_size = Vector2(500, 0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	_title = UiTheme.heading_label("")
	_title.add_theme_font_size_override("font_size", 20)
	box.add_child(_title)
	_lines = UiTheme.small_label()
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lines.custom_minimum_size = Vector2(470, 0)
	box.add_child(_lines)
	_prompt = UiTheme.small_label()
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_prompt)
	_pass = Button.new()
	_pass.text = "Do not react"
	_pass.pressed.connect(_on_pass_pressed)
	box.add_child(_pass)
	hide()


## The same player can face consecutive windows (two forecasts at once), and this button is
## not rebuilt between them. A short lock stops a double-click from also passing the next one.
func _on_pass_pressed() -> void:
	pass_requested.emit()
	_pass.disabled = true
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(_pass):
			_pass.disabled = false)


func refresh(state: MatchState) -> void:
	if state == null or state.phase != MatchState.Phase.REACTION or state.pending == null:
		hide()
		return
	var pd: PendingDisaster = state.pending
	var card: CardDefinition = state.catalog.card(pd.card_def_id)
	var dis: DisasterDefinition = state.catalog.disaster(pd.disaster_id)
	_title.text = "%s disaster: %s%s" % [_severity(pd.level), card.display_name, " (forecast arrives)" if pd.is_forecast else ""]
	var out: PackedStringArray = PackedStringArray()
	out.append("Cast by %s. Base damage %d. %s" % [state.players[pd.caster_id].display_name, pd.base_damage, _modifiers(dis)])
	var reactor: int = pd.current_reactor()
	for i: int in range(pd.targets.size()):
		var pid: int = pd.targets[i]
		var marker: String = "NOW > " if pid == reactor else ("done  " if i < pd.reactor_index else "next  ")
		out.append(marker + DamageText.preview_line(state, pid, dis, int(pd.reductions.get(pid, 0)), pd.base_damage))
	_lines.text = "\n".join(out)
	_prompt.text = "%s: play a Reaction card from your hand to reduce the damage, or pass. Reactions already played are counted above." % \
		state.players[reactor].display_name
	show()


func _severity(level: int) -> String:
	match level:
		1:
			return "Minor"
		2:
			return "Severe"
	return "Catastrophic"


func _modifiers(dis: DisasterDefinition) -> String:
	match dis.secondary_kind:
		DisasterDefinition.SecondaryKind.EXTRA_BUILDING_DAMAGE:
			return "Also damages a random building by %d." % dis.secondary_amount
		DisasterDefinition.SecondaryKind.DISCARD_RESERVE:
			return "Also discards %d Reserve card(s)." % dis.secondary_amount
		DisasterDefinition.SecondaryKind.DISCARD_RANDOM_HAND:
			return "Also discards %d random hand card(s)." % dis.secondary_amount
	return "No secondary effect."

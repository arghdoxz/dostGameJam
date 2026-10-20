class_name ForecastMarker
extends PanelContainer
## A hazard token on a threatened region: which disaster, its level, who cast it, when it
## strikes, and what it would currently do to this town.


func setup(state: MatchState, f: PendingDisaster, target_pid: int) -> void:
	var card: CardDefinition = state.catalog.card(f.card_def_id)
	var dis: DisasterDefinition = state.catalog.disaster(f.disaster_id)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetLibrary.get_texture("hazards", card.art_id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var l: Label = UiTheme.small_label()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pv: Dictionary = DamageCalculator.preview(state, state.players[target_pid], dis,
		int(f.reductions.get(target_pid, 0)), f.base_damage)
	l.text = "FORECAST %s L%d\nfrom %s, hits ~%d dmg" % [card.display_name, f.level,
		state.players[f.caster_id].display_name, int(pv["max"])]
	row.add_child(l)
	tooltip_text = "Forecast: %s (level %d) cast by %s.\nStrikes at the start of %s's next turn%s.\n%s" % [
		card.display_name, f.level, state.players[f.caster_id].display_name, state.players[f.caster_id].display_name,
		" (or at the end of the match)" if state.round_number >= state.config.round_cap else "",
		DamageText.preview_line(state, target_pid, dis, int(f.reductions.get(target_pid, 0)), f.base_damage)]

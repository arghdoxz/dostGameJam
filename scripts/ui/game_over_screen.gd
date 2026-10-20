extends Control
## Match-end screen: who won, why, and a standings table showing each town's final state.

signal rematch_requested
signal setup_requested
signal menu_requested


func show_result(state: MatchState) -> void:
	UiTheme.add_background(self, "menu")
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var names: PackedStringArray = PackedStringArray()
	for w: int in state.winner_ids:
		names.append(state.players[w].display_name)
	var title: Label = UiTheme.heading_label(("Winner: " if names.size() == 1 else "Shared win: ") + ", ".join(names))
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	var reason: Label = Label.new()
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.text = "%s. (Round %d of %d)" % [EventText.end_reason_text(state.end_reason), state.round_number, state.config.round_cap]
	box.add_child(reason)
	var table: RichTextLabel = RichTextLabel.new()
	table.fit_content = true
	table.bbcode_enabled = true
	table.scroll_active = false
	var t: String = "[b]Final standings[/b]\n"
	for p: PlayerState in state.players:
		var status: String = "ELIMINATED" if p.eliminated else "RP %d/%d" % [p.rp, state.config.starting_rp]
		var won: String = "  [WINNER]" if state.winner_ids.has(p.id) else ""
		t += "\n[b]%s[/b] (%s)%s\n  %s | %d building(s) | durability %d\n  Objectives %d/3: %s\n" % [
			p.display_name, state.catalog.territory(p.territory_id).display_name, won, status,
			p.buildings.size(), p.total_durability(), VictoryEvaluator.objectives_completed(state, p),
			_objective_text(state, p)]
	table.text = t
	box.add_child(table)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var again: Button = Button.new()
	again.text = "Rematch (same players, new seed)"
	again.pressed.connect(func() -> void: rematch_requested.emit())
	row.add_child(again)
	var setup: Button = Button.new()
	setup.text = "New setup"
	setup.pressed.connect(func() -> void: setup_requested.emit())
	row.add_child(setup)
	var menu: Button = Button.new()
	menu.text = "Main menu"
	menu.pressed.connect(func() -> void: menu_requested.emit())
	row.add_child(menu)


func _objective_text(state: MatchState, p: PlayerState) -> String:
	if p.eliminated:
		return "none (eliminated)"
	var parts: PackedStringArray = PackedStringArray()
	parts.append("Evacuation Center " + ("yes" if p.has_building(VictoryEvaluator.EVACUATION_CENTER_ID) else "no"))
	parts.append("Early Warning " + ("yes" if p.has_building(VictoryEvaluator.EARLY_WARNING_ID) else "no"))
	parts.append("Reserve Supplies %d/%d" % [VictoryEvaluator.supplies_in_reserve(state, p), state.config.prep_win_supplies])
	return ", ".join(parts)

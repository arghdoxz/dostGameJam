extends Control
## Placeholder match setup: player count, names, distinct territories and an optional seed.

signal start_requested(seats: Array[Dictionary], seed_value: int)
signal back_requested

var _catalog: ContentCatalog
var _count: OptionButton
var _rows: VBoxContainer
var _names: Array[LineEdit] = []
var _territories: Array[OptionButton] = []
var _seed: LineEdit
var _error: Label
var _territory_ids: Array[String] = []


func configure(catalog: ContentCatalog) -> void:
	_catalog = catalog
	_territory_ids = catalog.territory_ids()
	_territory_ids.sort()
	_build()


func _build() -> void:
	UiTheme.add_background(self, "menu")
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title: Label = UiTheme.heading_label("Match Setup")
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	var count_row: HBoxContainer = HBoxContainer.new()
	box.add_child(count_row)
	var cl: Label = Label.new()
	cl.text = "Players:"
	count_row.add_child(cl)
	_count = OptionButton.new()
	for n: int in range(_catalog.config.min_players, _catalog.config.max_players + 1):
		_count.add_item(str(n), n)
	_count.item_selected.connect(func(_i: int) -> void: _refresh_rows())
	count_row.add_child(_count)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	box.add_child(_rows)
	var seed_row: HBoxContainer = HBoxContainer.new()
	box.add_child(seed_row)
	var sl: Label = Label.new()
	sl.text = "Seed (blank = random):"
	seed_row.add_child(sl)
	_seed = LineEdit.new()
	_seed.custom_minimum_size = Vector2(160, 0)
	seed_row.add_child(_seed)
	_error = Label.new()
	_error.modulate = Color(1.0, 0.45, 0.4)
	box.add_child(_error)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var back: Button = Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: back_requested.emit())
	buttons.add_child(back)
	var go: Button = Button.new()
	go.text = "Start Match"
	go.pressed.connect(_on_start)
	buttons.add_child(go)
	_refresh_rows()


func _refresh_rows() -> void:
	_error.text = ""
	var n: int = _count.get_selected_id()
	for c: Node in _rows.get_children():
		c.queue_free()
	_names.clear()
	_territories.clear()
	for i: int in range(n):
		var row: HBoxContainer = HBoxContainer.new()
		_rows.add_child(row)
		var name_edit: LineEdit = LineEdit.new()
		name_edit.text = "Mayor %d" % (i + 1)
		name_edit.custom_minimum_size = Vector2(200, 0)
		row.add_child(name_edit)
		_names.append(name_edit)
		var opt: OptionButton = OptionButton.new()
		for t: String in _territory_ids:
			opt.add_item(_catalog.territory(t).display_name)
		opt.select(i % _territory_ids.size())
		row.add_child(opt)
		_territories.append(opt)
		var trait_label: Label = UiTheme.small_label()
		row.add_child(trait_label)
		var show_trait: Callable = func(_idx: int = 0) -> void:
			_error.text = ""
			var t: TerritoryDefinition = _catalog.territory(_territory_ids[opt.selected])
			trait_label.text = "resists %s, weak to %s" % [CardText.tag_name(t.resist_tag), CardText.tag_list(t.weak_tags)]
		opt.item_selected.connect(show_trait)
		show_trait.call()


func _on_start() -> void:
	var seats: Array[Dictionary] = []
	for i: int in range(_names.size()):
		var nm: String = _names[i].text.strip_edges()
		if nm == "":
			nm = "Mayor %d" % (i + 1)
		seats.append({"name": nm, "territory_id": _territory_ids[_territories[i].selected]})
	var check: ValidationResult = RulesEngine.validate_setup(_catalog.config, _catalog, seats)
	if not check.ok:
		_error.text = check.reason
		return
	var seed_value: int = int(_seed.text) if _seed.text.is_valid_int() else randi()
	start_requested.emit(seats, seed_value)

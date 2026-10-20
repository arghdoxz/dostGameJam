class_name DebugPanel
extends PanelContainer
## F1 debug tools. These bypass the rules on purpose; they never ship to players.

var _controller: MatchController
var _player_opt: OptionButton
var _target_opt: OptionButton
var _card_opt: OptionButton
var _disaster_opt: OptionButton
var _rp_spin: SpinBox
var _out: Label
var _card_ids: Array[String] = []
var _disaster_ids: Array[String] = []


func bind(controller: MatchController) -> void:
	_controller = controller
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(1200, 60)
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	var title: Label = Label.new()
	title.text = "DEBUG (F1)  seed: %d" % controller.state.seed_value
	box.add_child(title)
	_player_opt = OptionButton.new()
	_target_opt = OptionButton.new()
	for p: PlayerState in controller.state.players:
		_player_opt.add_item("Player: " + p.display_name, p.id)
		_target_opt.add_item("Target: " + p.display_name, p.id)
	box.add_child(_player_opt)
	box.add_child(_target_opt)
	_card_opt = OptionButton.new()
	_disaster_opt = OptionButton.new()
	var ids: Array = controller.catalog.cards.keys()
	ids.sort()
	for k: Variant in ids:
		var def: CardDefinition = controller.catalog.card(String(k))
		_card_opt.add_item(def.display_name)
		_card_ids.append(def.id)
		if def is DisasterCardDef:
			_disaster_opt.add_item(def.display_name)
			_disaster_ids.append(def.id)
	box.add_child(_card_opt)
	box.add_child(_button("Give card to player", _on_give))
	_rp_spin = SpinBox.new()
	_rp_spin.min_value = 1
	_rp_spin.max_value = 99
	_rp_spin.value = 20
	box.add_child(_rp_spin)
	box.add_child(_button("Set player RP", _on_set_rp))
	box.add_child(_disaster_opt)
	box.add_child(_button("Force-cast disaster (player casts at target)", _on_force))
	box.add_child(_button("Export action log", _on_export))
	_out = Label.new()
	box.add_child(_out)
	hide()


func _button(text: String, handler: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(handler)
	return b


func _on_give() -> void:
	_controller.debug_give_card(_player_opt.get_selected_id(), _card_ids[_card_opt.selected])


func _on_set_rp() -> void:
	_controller.debug_set_rp(_player_opt.get_selected_id(), int(_rp_spin.value))


func _on_force() -> void:
	_controller.debug_force_disaster(_player_opt.get_selected_id(), _disaster_ids[_disaster_opt.selected], _target_opt.get_selected_id())


func _on_export() -> void:
	var path: String = _controller.export_log()
	_out.text = "Saved: " + path if path != "" else "Export failed"

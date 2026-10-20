class_name PassDeviceScreen
extends ColorRect
## Opaque cover shown between hot-seat actors so the next player's hand stays hidden.

signal ready_pressed

var _title: Label
var _sub: Label
var _ok: Button


func _ready() -> void:
	color = Color(0.07, 0.08, 0.12, 1.0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 36)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_sub)
	_ok = Button.new()
	_ok.text = "I am ready"
	_ok.custom_minimum_size = Vector2(0, 48)
	_ok.pressed.connect(func() -> void:
		hide()
		ready_pressed.emit())
	box.add_child(_ok)
	hide()


func ready_button() -> Button:
	return _ok


func show_for(player_name: String, detail: String) -> void:
	_title.text = "Pass the device to %s" % player_name
	_sub.text = detail
	show()

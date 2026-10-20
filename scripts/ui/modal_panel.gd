class_name ModalPanel
extends Control
## Base for dialogs: dims and blocks everything behind it, centers a themed panel and exposes
## a VBox (content) for subclasses to fill. Hidden until open_modal().

var content: VBoxContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	content = VBoxContainer.new()
	content.custom_minimum_size = Vector2(500, 0)
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	hide()


func open_modal() -> void:
	show()


func close_modal() -> void:
	hide()


func clear_content() -> void:
	for c: Node in content.get_children():
		content.remove_child(c)
		c.queue_free()


func make_label(text: String, wrap: bool = true) -> Label:
	var l: Label = Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

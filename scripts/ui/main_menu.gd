extends Control
## Placeholder main menu.

signal start_pressed
signal tutorial_pressed
signal quit_pressed


func _ready() -> void:
	UiTheme.add_background(self, "menu")
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title: Label = UiTheme.heading_label("SCRATCH NOTES")
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub: Label = Label.new()
	sub.text = "A disaster-preparedness card game"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var tutorial: Button = Button.new()
	tutorial.text = "How to Play (Tutorial)"
	tutorial.custom_minimum_size = Vector2(0, 48)
	tutorial.tooltip_text = "A guided 2-player lesson. New here? Start with this."
	tutorial.pressed.connect(func() -> void: tutorial_pressed.emit())
	box.add_child(tutorial)
	var start: Button = Button.new()
	start.text = "Start Local Match"
	start.custom_minimum_size = Vector2(0, 48)
	start.pressed.connect(func() -> void: start_pressed.emit())
	box.add_child(start)
	var quit: Button = Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(0, 48)
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	box.add_child(quit)

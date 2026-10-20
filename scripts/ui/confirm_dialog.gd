class_name ConfirmDialog
extends ModalPanel
## Yes/No confirmation, used before leaving or restarting a match in progress.

signal accepted
signal declined


func ask(title: String, message: String, yes_text: String, no_text: String = "Keep playing") -> void:
	clear_content()
	content.add_child(UiTheme.heading_label(title))
	content.add_child(make_label(message))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var no: Button = Button.new()
	no.text = no_text
	no.pressed.connect(func() -> void:
		close_modal()
		declined.emit())
	row.add_child(no)
	var yes: Button = Button.new()
	yes.text = yes_text
	yes.pressed.connect(func() -> void:
		close_modal()
		accepted.emit())
	row.add_child(yes)
	open_modal()

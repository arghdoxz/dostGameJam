class_name ResolutionSummary
extends PanelContainer
## After a disaster resolves, lists what changed: damage per town, building wear and
## destruction, secondary effects, eliminations and forecast placements. Stays until dismissed,
## so nothing essential depends on a timer or an animation.

signal dismissed

var _title: Label
var _body: Label


func _ready() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	_title = UiTheme.heading_label("What happened")
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(520, 0)
	box.add_child(_body)
	var ok: Button = Button.new()
	ok.text = "Continue"
	ok.pressed.connect(func() -> void:
		hide()
		dismissed.emit())
	box.add_child(ok)
	hide()


## Returns true if the events contained something worth summarising (and shows the panel).
func show_for(events: Array[GameEvent], state: MatchState) -> bool:
	var lines: PackedStringArray = PackedStringArray()
	for e: GameEvent in events:
		match e.type:
			"damage_dealt", "building_damaged", "building_destroyed", "secondary_effect", "player_eliminated", \
			"disaster_fizzled", "forecast_placed", "final_resolution_started", "game_over":
				var line: String = EventText.describe(e, state)
				if line != "":
					lines.append(line)
	if lines.is_empty():
		return false
	_body.text = "\n".join(lines)
	show()
	return true

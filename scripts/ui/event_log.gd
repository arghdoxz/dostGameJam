class_name EventLog
extends RichTextLabel
## Scrolling public log of what happened.


func _ready() -> void:
	bbcode_enabled = false
	scroll_following = true
	custom_minimum_size = Vector2(320, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func append_events(events: Array[GameEvent], state: MatchState) -> void:
	for e: GameEvent in events:
		var line: String = EventText.describe(e, state)
		if line != "":
			append_text(line + "\n")

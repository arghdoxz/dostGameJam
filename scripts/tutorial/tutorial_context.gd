class_name TutorialContext
extends RefCounted
## What a tutorial step can look at when deciding whether it is complete: the match state,
## the events that happened since the step began, and a few facts about the UI (the selected
## card, the chosen target, whether the hot-seat cover or the "What happened" panel is open).

var state: MatchState
var events: Array[GameEvent] = []
var selected_def: String = ""
var chosen_target: int = -1
var cover_visible: bool = false
var summary_visible: bool = false
## True once the summary panel has been on screen during this step.
var summary_seen: bool = false
## Seconds since the step began.
var age: float = 0.0


func has_event(type: String) -> bool:
	for e: GameEvent in events:
		if e.type == type:
			return true
	return false


## The learner's own town ("You") is always seat 0, the rival is seat 1.
func me() -> PlayerState:
	return state.players[0]


func rival() -> PlayerState:
	return state.players[1]

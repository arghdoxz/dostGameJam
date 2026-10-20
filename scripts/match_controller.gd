class_name MatchController
extends Node
## Bridge between the UI and the rules engine. The UI submits GameActions here and
## re-renders from the signals. All rules live in RulesEngine; this node owns no rules.

signal events_emitted(events: Array[GameEvent])
signal state_changed
signal action_rejected(reason: String)
signal match_abandoned

var _busy: bool = false

var state: MatchState
var catalog: ContentCatalog
## Every accepted action as a dictionary, in order. Together with the seed and seats it
## replays the match exactly.
var action_log: Array[Dictionary] = []
var seats: Array[Dictionary] = []


## Creates and starts a match. Returns an error string, or "" on success.
## prepare (tutorial only) is called with the new MatchState before the first turn begins, so the
## tutorial can arrange hands. Normal matches pass nothing.
func start(p_catalog: ContentCatalog, p_seats: Array[Dictionary], seed_value: int, prepare: Callable = Callable()) -> String:
	catalog = p_catalog
	seats = p_seats
	var check: ValidationResult = RulesEngine.validate_setup(catalog.config, catalog, seats)
	if not check.ok:
		return check.reason
	action_log.clear()
	_busy = false
	state = RulesEngine.new_match(catalog.config, catalog, seats, seed_value)
	if prepare.is_valid():
		prepare.call(state)
	var events: Array[GameEvent] = RulesEngine.start_match(state)
	events_emitted.emit(events)
	state_changed.emit()
	return ""


## Submits a player action. Returns true if the engine accepted it.
## Ignored while another submit is still being handled (a signal handler re-entering submit
## would otherwise apply an action against half-rendered state).
func submit(action: GameAction) -> bool:
	if state == null:
		action_rejected.emit("No match in progress")
		return false
	if _busy:
		action_rejected.emit("Still resolving the previous action")
		return false
	var v: ValidationResult = RulesEngine.validate(state, action)
	if not v.ok:
		action_rejected.emit(v.reason)
		return false
	_busy = true
	action_log.append(action.to_dict())
	var events: Array[GameEvent] = RulesEngine.apply(state, action)
	events_emitted.emit(events)
	state_changed.emit()
	_busy = false
	return true


## Drops the current match (leave or restart). Safe in every phase, including a Reaction window.
func abandon() -> void:
	state = null
	action_log.clear()
	_busy = false
	match_abandoned.emit()


func has_match() -> bool:
	return state != null


func legal_actions() -> Array[GameAction]:
	if state == null:
		return [] as Array[GameAction]
	return ActionEnumerator.legal_actions(state)


## Writes the replay data (seed, seats, actions) as JSON to user://. Returns the real path.
func export_log() -> String:
	var path: String = "user://scratch_notes_log_%d.json" % Time.get_unix_time_from_system()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify({"seed": state.seed_value, "seats": seats, "actions": action_log}, "\t"))
	f.close()
	return ProjectSettings.globalize_path(path)


# ---- DEBUG ONLY: these bypass the rules and are used by the F1 debug panel. ----

func debug_give_card(player_id: int, def_id: String) -> void:
	var c: CardInstance = CardInstance.new(state.new_uid(), def_id)
	state.players[player_id].hand.append(c)
	state_changed.emit()


func debug_set_rp(player_id: int, rp: int) -> void:
	state.players[player_id].rp = maxi(1, rp)
	state_changed.emit()


## Casts a disaster card definition id as if the caster had played it for free.
func debug_force_disaster(caster_id: int, card_def_id: String, target_id: int) -> void:
	if state.phase != MatchState.Phase.PLAY:
		return
	var events: Array[GameEvent] = []
	DisasterResolver.cast(state, caster_id, CardInstance.new(state.new_uid(), card_def_id), target_id, events)
	events_emitted.emit(events)
	state_changed.emit()

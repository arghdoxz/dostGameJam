class_name PendingDisaster
extends RefCounted
## A disaster that has been cast. L2/L3 wait as public Forecasts; L1 resolves at once.

var seq: int = 0
var caster_id: int = 0
var card_def_id: String = ""
var disaster_id: String = ""
var level: int = 1
var base_damage: int = 0
## Target player ids, in turn order starting after the caster.
var targets: Array[int] = []
## Player id -> damage reduction gained from Reaction cards.
var reductions: Dictionary = {}
## Index into targets of the player currently asked for a Reaction.
var reactor_index: int = 0
var is_forecast: bool = false


func current_reactor() -> int:
	if reactor_index < 0 or reactor_index >= targets.size():
		return -1
	return targets[reactor_index]


func to_dict() -> Dictionary:
	var red: Dictionary = {}
	for k: Variant in reductions.keys():
		red[str(k)] = reductions[k]
	return {
		"seq": seq, "caster": caster_id, "card": card_def_id, "disaster": disaster_id,
		"level": level, "base": base_damage, "targets": targets.duplicate(),
		"reductions": red, "reactor_index": reactor_index, "forecast": is_forecast,
	}

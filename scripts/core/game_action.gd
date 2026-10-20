class_name GameAction
extends RefCounted
## Base class for every player input. Actions carry only ids and are serializable.

const DRAW: String = "draw"
const PLAY_CARD: String = "play_card"
const RESERVE: String = "reserve"
const REACT: String = "react"
const PASS_REACTION: String = "pass_reaction"
const END_TURN: String = "end_turn"

var type: String = ""
var player_id: int = 0


func to_dict() -> Dictionary:
	return {"type": type, "player": player_id}


func _read_base(d: Dictionary) -> void:
	player_id = int(d.get("player", 0))


static func ints_from(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for x: Variant in (v as Array):
			out.append(int(x))
	return out

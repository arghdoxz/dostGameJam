class_name EndTurnAction
extends GameAction
## End the turn. discard_uids must remove exactly the cards above the hand limit.

var discard_uids: Array[int] = []


func _init(p_player: int = 0, p_discards: Array[int] = []) -> void:
	type = GameAction.END_TURN
	player_id = p_player
	discard_uids = p_discards


func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["discards"] = discard_uids.duplicate()
	return d


static func from_dict(d: Dictionary) -> EndTurnAction:
	var a: EndTurnAction = EndTurnAction.new()
	a._read_base(d)
	a.discard_uids = GameAction.ints_from(d.get("discards", []))
	return a

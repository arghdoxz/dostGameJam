class_name ReserveAction
extends GameAction
## Move a Supplies card from the hand into the Reserve. Free: uses no play.

var card_uid: int = 0


func _init(p_player: int = 0, p_card: int = 0) -> void:
	type = GameAction.RESERVE
	player_id = p_player
	card_uid = p_card


func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["card"] = card_uid
	return d


static func from_dict(d: Dictionary) -> ReserveAction:
	var a: ReserveAction = ReserveAction.new()
	a._read_base(d)
	a.card_uid = int(d.get("card", 0))
	return a

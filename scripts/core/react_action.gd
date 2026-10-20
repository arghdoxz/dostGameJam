class_name ReactAction
extends GameAction
## Play one Reaction card during a Reaction window.

var card_uid: int = 0
var payment_uids: Array[int] = []


func _init(p_player: int = 0, p_card: int = 0, p_payment: Array[int] = []) -> void:
	type = GameAction.REACT
	player_id = p_player
	card_uid = p_card
	payment_uids = p_payment


func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["card"] = card_uid
	d["payment"] = payment_uids.duplicate()
	return d


static func from_dict(d: Dictionary) -> ReactAction:
	var a: ReactAction = ReactAction.new()
	a._read_base(d)
	a.card_uid = int(d.get("card", 0))
	a.payment_uids = GameAction.ints_from(d.get("payment", []))
	return a

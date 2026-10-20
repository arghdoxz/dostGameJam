class_name PlayCardAction
extends GameAction
## Play a Building, Preparedness or Disaster card. payment_uids are resource cards
## from the hand (or Supplies in the Reserve) that are discarded to pay the cost.

var card_uid: int = 0
var payment_uids: Array[int] = []
## Chosen opponent (SINGLE_OPPONENT disasters).
var target_player_id: int = -1
## Chosen own building (Repair effects).
var target_building_uid: int = -1


func _init(p_player: int = 0, p_card: int = 0, p_payment: Array[int] = []) -> void:
	type = GameAction.PLAY_CARD
	player_id = p_player
	card_uid = p_card
	payment_uids = p_payment


func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["card"] = card_uid
	d["payment"] = payment_uids.duplicate()
	d["target_player"] = target_player_id
	d["target_building"] = target_building_uid
	return d


static func from_dict(d: Dictionary) -> PlayCardAction:
	var a: PlayCardAction = PlayCardAction.new()
	a._read_base(d)
	a.card_uid = int(d.get("card", 0))
	a.payment_uids = GameAction.ints_from(d.get("payment", []))
	a.target_player_id = int(d.get("target_player", -1))
	a.target_building_uid = int(d.get("target_building", -1))
	return a

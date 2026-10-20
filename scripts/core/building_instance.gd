class_name BuildingInstance
extends RefCounted
## A building on a town board. uid equals the uid of the card that created it.

var uid: int
var def_id: String
var durability: int


func _init(p_uid: int = 0, p_def_id: String = "", p_durability: int = 0) -> void:
	uid = p_uid
	def_id = p_def_id
	durability = p_durability


func to_dict() -> Dictionary:
	return {"uid": uid, "def": def_id, "dur": durability}

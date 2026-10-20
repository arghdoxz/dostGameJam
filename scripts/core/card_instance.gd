class_name CardInstance
extends RefCounted
## A physical card in play: a unique id plus the id of its definition.

var uid: int
var def_id: String


func _init(p_uid: int = 0, p_def_id: String = "") -> void:
	uid = p_uid
	def_id = p_def_id


func to_dict() -> Dictionary:
	return {"uid": uid, "def": def_id}

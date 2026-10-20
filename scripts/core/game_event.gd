class_name GameEvent
extends RefCounted
## A fact published by the rules engine for the presentation layer and logs.

var type: String
var data: Dictionary


func _init(p_type: String = "", p_data: Dictionary = {}) -> void:
	type = p_type
	data = p_data


func to_dict() -> Dictionary:
	return {"type": type, "data": data}

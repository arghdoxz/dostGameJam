class_name PlayerState
extends RefCounted
## One mayor and their town. Hand is hidden information; everything else is public.

var id: int = 0
var display_name: String = ""
var territory_id: String = ""
var rp: int = 0
var eliminated: bool = false
var hand: Array[CardInstance] = []
var reserve: Array[CardInstance] = []
var buildings: Array[BuildingInstance] = []


func find_in_hand(uid: int) -> CardInstance:
	for c: CardInstance in hand:
		if c.uid == uid:
			return c
	return null


func find_in_reserve(uid: int) -> CardInstance:
	for c: CardInstance in reserve:
		if c.uid == uid:
			return c
	return null


func find_building(uid: int) -> BuildingInstance:
	for b: BuildingInstance in buildings:
		if b.uid == uid:
			return b
	return null


func has_building(def_id: String) -> bool:
	for b: BuildingInstance in buildings:
		if b.def_id == def_id:
			return true
	return false


func total_durability() -> int:
	var total: int = 0
	for b: BuildingInstance in buildings:
		total += b.durability
	return total


func remove_from_hand(uid: int) -> CardInstance:
	for i: int in range(hand.size()):
		if hand[i].uid == uid:
			return hand.pop_at(i)
	return null


func remove_from_reserve(uid: int) -> CardInstance:
	for i: int in range(reserve.size()):
		if reserve[i].uid == uid:
			return reserve.pop_at(i)
	return null


func to_dict() -> Dictionary:
	var h: Array = []
	for c: CardInstance in hand:
		h.append(c.to_dict())
	var r: Array = []
	for c: CardInstance in reserve:
		r.append(c.to_dict())
	var b: Array = []
	for x: BuildingInstance in buildings:
		b.append(x.to_dict())
	return {
		"id": id, "name": display_name, "territory": territory_id, "rp": rp,
		"eliminated": eliminated, "hand": h, "reserve": r, "buildings": b,
	}

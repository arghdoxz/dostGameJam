class_name TerritoryDefinition
extends Resource
## A town seat with one resistance and one or more weaknesses (decision D8).

@export var id: String = ""
@export var display_name: String = ""
@export var resist_tag: String = ""
@export var weak_tags: PackedStringArray = PackedStringArray()
## Damage change per resistance or weakness.
@export var modifier: int = 1
@export_multiline var description: String = ""
@export var art_id: String = ""


func damage_modifier(disaster_tags: PackedStringArray) -> int:
	var total: int = 0
	if resist_tag != "" and disaster_tags.has(resist_tag):
		total -= modifier
	for w: String in weak_tags:
		if disaster_tags.has(w):
			total += modifier
			break
	return total

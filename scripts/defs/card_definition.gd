class_name CardDefinition
extends Resource
## Static data shared by every card. Subclasses add type-specific fields.
## Cost keys: "materials", "funds", "supplies" (specific resource cards) and
## "any" (any resource cards). Values are numbers of cards to discard.

enum CardType { RESOURCE, BUILDING, PREPAREDNESS, REACTION, DISASTER }
enum DeckKind { TOWN, DISASTER }

@export var id: String = ""
@export var display_name: String = ""
@export var card_type: CardType = CardType.RESOURCE
@export var deck: DeckKind = DeckKind.TOWN
@export var cost: Dictionary = {}
@export var tags: PackedStringArray = PackedStringArray()
@export_multiline var flavor: String = ""
@export_multiline var dr_tip: String = ""
@export var art_id: String = ""


func total_cost() -> int:
	var total: int = 0
	for k: Variant in cost.keys():
		total += int(cost[k])
	return total


func cost_text() -> String:
	if cost.is_empty():
		return "Free"
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in cost.keys():
		parts.append("%d %s" % [int(cost[k]), String(k)])
	return ", ".join(parts)

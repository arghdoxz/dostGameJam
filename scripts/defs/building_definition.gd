class_name BuildingDefinition
extends Resource
## Static data for a building. The key "*" in reductions applies to every disaster tag.

@export var id: String = ""
@export var durability: int = 2
## Maps a disaster tag to a flat damage reduction.
@export var reductions: Dictionary = {}
## Resilience points restored at the start of the owner's turn.
@export var start_turn_heal: int = 0


## Best reduction this building offers against a disaster with the given tags.
## A building never stacks reductions with itself.
func reduction_against(disaster_tags: PackedStringArray) -> int:
	var best: int = 0
	for k: Variant in reductions.keys():
		var key: String = String(k)
		if key == "*" or disaster_tags.has(key):
			best = maxi(best, int(reductions[k]))
	return best

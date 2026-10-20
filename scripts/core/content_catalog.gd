class_name ContentCatalog
extends RefCounted
## Id -> definition lookup built from a ContentRegistry. Core code uses this, not the autoload.

var cards: Dictionary = {}
var territories: Dictionary = {}
var buildings: Dictionary = {}
var disasters: Dictionary = {}
var config: MatchConfig
var errors: PackedStringArray = PackedStringArray()


static func from_registry(registry: ContentRegistry) -> ContentCatalog:
	var cat: ContentCatalog = ContentCatalog.new()
	cat.config = registry.default_config
	for c: CardDefinition in registry.cards:
		if c == null:
			cat.errors.append("Null card in registry")
			continue
		if cat.cards.has(c.id):
			cat.errors.append("Duplicate card id: " + c.id)
		cat.cards[c.id] = c
		if c is BuildingCardDef:
			var bc: BuildingCardDef = c as BuildingCardDef
			if bc.building == null:
				cat.errors.append("Building card without definition: " + c.id)
			else:
				cat.buildings[bc.building.id] = bc.building
		elif c is DisasterCardDef:
			var dc: DisasterCardDef = c as DisasterCardDef
			if dc.disaster == null:
				cat.errors.append("Disaster card without definition: " + c.id)
			else:
				cat.disasters[dc.disaster.id] = dc.disaster
	for t: TerritoryDefinition in registry.territories:
		if cat.territories.has(t.id):
			cat.errors.append("Duplicate territory id: " + t.id)
		cat.territories[t.id] = t
	if cat.config == null:
		cat.errors.append("Registry has no default config")
	return cat


func card(id: String) -> CardDefinition:
	return cards.get(id) as CardDefinition


func territory(id: String) -> TerritoryDefinition:
	return territories.get(id) as TerritoryDefinition


func building(id: String) -> BuildingDefinition:
	return buildings.get(id) as BuildingDefinition


func disaster(id: String) -> DisasterDefinition:
	return disasters.get(id) as DisasterDefinition


func card_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in cards.keys():
		out.append(String(k))
	return out


func territory_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in territories.keys():
		out.append(String(k))
	return out

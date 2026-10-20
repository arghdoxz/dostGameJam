extends SceneTree
## Regenerates every .tres file under res://content from the tables below.
## Run: godot --headless --path . -s res://tools/generate_content.gd
## Rule makers may also edit the generated .tres files directly in the Godot editor.

const CARD_DIR: String = "res://content/cards/"
const DISASTER_DIR: String = "res://content/disasters/"
const BUILDING_DIR: String = "res://content/buildings/"
const TERRITORY_DIR: String = "res://content/territories/"

var _cards: Array[CardDefinition] = []
var _territories: Array[TerritoryDefinition] = []


func _init() -> void:
	_make_resources()
	_make_buildings()
	_make_preparedness()
	_make_disasters()
	_make_territories()
	_make_config_and_registry()
	print("Content generated: %d cards, %d territories" % [_cards.size(), _territories.size()])
	quit(0)


func _save(res: Resource, path: String) -> void:
	res.take_over_path(path)
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [path, err])
		quit(1)


func _fill(c: CardDefinition, id: String, display: String, type: CardDefinition.CardType,
		deck: CardDefinition.DeckKind, cost: Dictionary, flavor: String, tip: String, art: String) -> void:
	c.id = id
	c.display_name = display
	c.card_type = type
	c.deck = deck
	c.cost = cost
	c.flavor = flavor
	c.dr_tip = tip
	c.art_id = art


func _make_resources() -> void:
	var rows: Array = [
		["res_materials", "Materials", ResourceCardDef.KIND_MATERIALS, "Lumber, cement and rebar.",
			"Stockpile building materials before typhoon season, not during it."],
		["res_funds", "Funds", ResourceCardDef.KIND_FUNDS, "The local DRRM fund.",
			"By law, at least 5% of local revenue goes to the DRRM fund."],
		["res_supplies", "Supplies", ResourceCardDef.KIND_SUPPLIES, "Food, water and medicine.",
			"Keep a go-bag stocked with 3 days of food and water."],
	]
	for r: Array in rows:
		var c: ResourceCardDef = ResourceCardDef.new()
		_fill(c, r[0], r[1], CardDefinition.CardType.RESOURCE, CardDefinition.DeckKind.TOWN, {}, r[3], r[4], r[0])
		c.resource_kind = r[2]
		_save(c, CARD_DIR + c.id + ".tres")
		_cards.append(c)


func _make_buildings() -> void:
	# id, name, cost, reductions, durability, heal, flavor, tip
	var rows: Array = [
		["bld_seawall", "Seawall", {"materials": 2}, {"flood": 3, "storm_surge": 3}, 3, 0,
			"Concrete against the sea.", "Seawalls and mangrove belts blunt storm surge."],
		["bld_drainage_system", "Drainage System", {"materials": 1, "funds": 1}, {"flood": 1, "typhoon": 1}, 2, 0,
			"Clear canals drain fast.", "Clear canals and drains before the rainy season."],
		["bld_retrofitted_structures", "Retrofitted Structures", {"materials": 2, "funds": 1}, {"earthquake": 2, "typhoon": 1}, 3, 0,
			"Strong frames, strong roofs.", "Retrofit old buildings to meet the National Building Code."],
		["bld_reforestation", "Reforestation", {"materials": 1, "supplies": 1}, {"landslide": 2, "flood": 1}, 2, 0,
			"Roots hold the hillside.", "Tree cover on slopes reduces landslide risk."],
		["bld_ashfall_shelter", "Ashfall Shelter", {"materials": 1, "funds": 1}, {"volcanic": 2}, 2, 0,
			"A sturdy roof for falling ash.", "Cover vents and wear masks during ashfall."],
		["bld_evacuation_center", "Evacuation Center", {"materials": 2, "funds": 2}, {"*": 1}, 3, 1,
			"Safe ground with a roof.", "Know your nearest evacuation center and the route to it."],
		["bld_early_warning_system", "Early Warning System", {"funds": 2}, {"typhoon": 1, "flood": 1, "storm_surge": 1}, 2, 0,
			"Sirens and rain gauges.", "Heed PAGASA and PHIVOLCS advisories right away."],
	]
	for r: Array in rows:
		var b: BuildingDefinition = BuildingDefinition.new()
		b.id = r[0]
		b.reductions = r[3]
		b.durability = r[4]
		b.start_turn_heal = r[5]
		_save(b, BUILDING_DIR + b.id + ".tres")
		var c: BuildingCardDef = BuildingCardDef.new()
		_fill(c, r[0], r[1], CardDefinition.CardType.BUILDING, CardDefinition.DeckKind.TOWN, r[2], r[6], r[7], r[0])
		c.building = b
		_save(c, CARD_DIR + c.id + ".tres")
		_cards.append(c)


func _effect(kind: EffectDefinition.Kind, amount: int, tag: String = "") -> EffectDefinition:
	var e: EffectDefinition = EffectDefinition.new()
	e.kind = kind
	e.amount = amount
	e.tag = tag
	return e


func _make_preparedness() -> void:
	var K: Variant = EffectDefinition.Kind
	var P: CardDefinition.CardType = CardDefinition.CardType.PREPAREDNESS
	var R: CardDefinition.CardType = CardDefinition.CardType.REACTION
	var rows: Array = [
		["prep_preemptive_evacuation", "Pre-emptive Evacuation", R, {"any": 1}, [_effect(K.DAMAGE_REDUCTION, 2)],
			"Move before the water does.", "Evacuate early, not when the water is at the door."],
		["prep_go_bag", "Go Bag", R, {}, [_effect(K.DAMAGE_REDUCTION, 1)],
			"Packed and by the door.", "Pack documents, water, a flashlight and first aid."],
		["prep_barangay_drill", "Barangay Drill", R, {"any": 2}, [_effect(K.DAMAGE_REDUCTION, 3)],
			"Everyone knows their role.", "Practice drills so everyone knows what to do."],
		["prep_relief_operations", "Relief Operations", P, {"supplies": 1}, [_effect(K.HEAL, 3)],
			"Relief goods reach every household.", "Relief teams need organized goods and trained volunteers."],
		["prep_bayanihan", "Bayanihan", P, {"supplies": 1}, [_effect(K.REPAIR, 2)],
			"Many hands, light work.", "Communities recover faster when neighbors help each other."],
		["prep_hazard_mapping", "Hazard Mapping", P, {"funds": 1}, [_effect(K.EXTRA_PLAY, 1)],
			"Know where the risks are.", "Hazard maps show which areas flood or slide."],
		["prep_early_warning_broadcast", "Early Warning Broadcast", P, {"funds": 1}, [_effect(K.DRAW, 2)],
			"The radio carries the alert.", "Share official warnings and avoid unverified rumors."],
		["prep_community_pantry", "Community Pantry", P, {"any": 1}, [_effect(K.HEAL, 2), _effect(K.DRAW, 1)],
			"Take what you need, give what you can.", "Share supplies and look after vulnerable neighbors."],
	]
	for r: Array in rows:
		var c: PreparednessCardDef = PreparednessCardDef.new()
		_fill(c, r[0], r[1], r[2], CardDefinition.DeckKind.TOWN, r[3], r[5], r[6], r[0])
		var fx: Array[EffectDefinition] = []
		for e: Variant in r[4]:
			fx.append(e as EffectDefinition)
		c.effects = fx
		_save(c, CARD_DIR + c.id + ".tres")
		_cards.append(c)


func _make_disasters() -> void:
	var T: Variant = DisasterDefinition.Targeting
	var S: Variant = DisasterDefinition.SecondaryKind
	# id, name, level, min, max, tags, targeting, condition building, secondary, amount, flavor, tip
	var rows: Array = [
		["landslide", "Landslide", 1, 2, 3, ["landslide"], T.SINGLE_OPPONENT, "", S.NONE, 0,
			"The hillside lets go.", "Avoid steep slopes after heavy rain."],
		["el_nino_drought", "El Nino Drought", 1, 2, 3, ["drought"], T.ALL_OPPONENTS, "", S.DISCARD_RESERVE, 1,
			"No rain for months.", "Store water and conserve it during dry spells."],
		["typhoon", "Typhoon", 2, 4, 5, ["typhoon", "wind"], T.ALL_OPPONENTS, "", S.DISCARD_RANDOM_HAND, 1,
			"Signal No. 4 over the coast.", "Secure roofs and loose objects before a typhoon."],
		["flood", "Flood", 2, 4, 5, ["flood"], T.OPPONENTS_WITHOUT_BUILDING, "bld_drainage_system", S.NONE, 0,
			"Brown water in the streets.", "Never walk or drive through floodwater."],
		["volcanic_eruption", "Volcanic Eruption", 2, 4, 5, ["volcanic"], T.OPPONENTS_WITHOUT_BUILDING, "bld_ashfall_shelter", S.NONE, 0,
			"Ash darkens the afternoon.", "Follow the PHIVOLCS alert level and stay out of danger zones."],
		["earthquake", "Earthquake", 3, 6, 6, ["earthquake"], T.ALL_OPPONENTS, "", S.EXTRA_BUILDING_DAMAGE, 1,
			"The ground rolls.", "Drop, cover and hold on."],
		["storm_surge", "Storm Surge", 3, 6, 6, ["storm_surge", "flood"], T.SINGLE_OPPONENT, "", S.EXTRA_BUILDING_DAMAGE, 1,
			"The sea climbs the streets.", "Move to higher ground when surge warnings are issued."],
	]
	for r: Array in rows:
		var d: DisasterDefinition = DisasterDefinition.new()
		d.id = "disaster_" + String(r[0])
		d.level = r[2]
		d.damage_min = r[3]
		d.damage_max = r[4]
		d.tags = PackedStringArray(r[5])
		d.targeting = r[6]
		d.condition_building_id = r[7]
		d.secondary_kind = r[8]
		d.secondary_amount = r[9]
		_save(d, DISASTER_DIR + d.id + ".tres")
		var c: DisasterCardDef = DisasterCardDef.new()
		var cost: Dictionary = {}
		if d.level > 1:
			cost = {"any": d.level - 1}
		_fill(c, "dis_" + String(r[0]), r[1], CardDefinition.CardType.DISASTER, CardDefinition.DeckKind.DISASTER,
			cost, r[10], r[11], d.id)
		c.disaster = d
		_save(c, CARD_DIR + c.id + ".tres")
		_cards.append(c)


func _make_territories() -> void:
	# id, name, resists, weak, description
	var rows: Array = [
		["terr_coastal", "Coastal", "drought", ["storm_surge", "typhoon"], "Fishing town on an open bay."],
		["terr_riverside", "Riverside", "volcanic", ["flood"], "Town built along a wide river."],
		["terr_upland", "Upland", "flood", ["landslide"], "Terraced town on the hills."],
		["terr_volcanic_foothills", "Volcanic Foothills", "landslide", ["volcanic"], "Fertile farms below the crater."],
		["terr_urban_lowland", "Urban Lowland", "earthquake", ["flood"], "Dense city on low ground."],
	]
	for r: Array in rows:
		var t: TerritoryDefinition = TerritoryDefinition.new()
		t.id = r[0]
		t.display_name = r[1]
		t.resist_tag = r[2]
		t.weak_tags = PackedStringArray(r[3])
		t.description = r[4]
		t.art_id = r[0]
		_save(t, TERRITORY_DIR + t.id + ".tres")
		_territories.append(t)


func _make_config_and_registry() -> void:
	var cfg: MatchConfig = MatchConfig.new()
	cfg.town_deck = {
		"res_materials": 12, "res_funds": 10, "res_supplies": 10,
		"bld_seawall": 2, "bld_drainage_system": 2, "bld_retrofitted_structures": 2,
		"bld_reforestation": 2, "bld_ashfall_shelter": 2, "bld_evacuation_center": 2,
		"bld_early_warning_system": 2,
		"prep_preemptive_evacuation": 2, "prep_go_bag": 2, "prep_barangay_drill": 2,
		"prep_relief_operations": 2, "prep_bayanihan": 2, "prep_hazard_mapping": 2,
		"prep_early_warning_broadcast": 2, "prep_community_pantry": 2,
	}
	cfg.disaster_deck = {
		"dis_landslide": 3, "dis_el_nino_drought": 3, "dis_typhoon": 2, "dis_flood": 3,
		"dis_volcanic_eruption": 2, "dis_earthquake": 2, "dis_storm_surge": 2,
	}
	_save(cfg, "res://content/config/default_match_config.tres")
	var reg: ContentRegistry = ContentRegistry.new()
	reg.cards = _cards
	reg.territories = _territories
	reg.default_config = cfg
	_save(reg, "res://content/content_registry.tres")

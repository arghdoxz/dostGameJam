class_name CardText
extends RefCounted
## Plain-text descriptions of cards for placeholder UI.


static func type_name(def: CardDefinition) -> String:
	match def.card_type:
		CardDefinition.CardType.RESOURCE:
			return "Resource"
		CardDefinition.CardType.BUILDING:
			return "Building"
		CardDefinition.CardType.PREPAREDNESS:
			return "Preparedness"
		CardDefinition.CardType.REACTION:
			return "Reaction"
		CardDefinition.CardType.DISASTER:
			return "Disaster"
	return "Card"


## A hazard tag as a player should read it ("storm_surge" -> "storm surge").
static func tag_name(tag: String) -> String:
	return "all" if tag == "*" else tag.replace("_", " ")


static func tag_list(tags: PackedStringArray) -> String:
	var out: PackedStringArray = PackedStringArray()
	for t: String in tags:
		out.append(tag_name(t))
	return ", ".join(out)


static func effect_text(e: EffectDefinition) -> String:
	match e.kind:
		EffectDefinition.Kind.DAMAGE_REDUCTION:
			var scope: String = "damage" if e.tag == "" else "%s damage" % tag_name(e.tag)
			return "Reduce %s by %d" % [scope, e.amount]
		EffectDefinition.Kind.HEAL:
			return "Heal %d RP" % e.amount
		EffectDefinition.Kind.REPAIR:
			return "Repair a building by %d" % e.amount
		EffectDefinition.Kind.DRAW:
			return "Draw %d" % e.amount
		EffectDefinition.Kind.EXTRA_PLAY:
			return "+%d Play" % e.amount
	return ""


## One-paragraph rules text for a card.
static func rules_text(def: CardDefinition, catalog: ContentCatalog) -> String:
	if def is ResourceCardDef:
		return "Discard to pay costs. Supplies can be banked in the Reserve."
	if def is BuildingCardDef:
		var b: BuildingDefinition = (def as BuildingCardDef).building
		var parts: PackedStringArray = PackedStringArray()
		for k: Variant in b.reductions.keys():
			parts.append("%s -%d" % [tag_name(String(k)), int(b.reductions[k])])
		var s: String = "Durability %d. Reduces: %s." % [b.durability, ", ".join(parts)]
		if b.start_turn_heal > 0:
			s += " Heals %d RP each turn." % b.start_turn_heal
		return s
	if def is PreparednessCardDef:
		var fx: PackedStringArray = PackedStringArray()
		for e: EffectDefinition in (def as PreparednessCardDef).effects:
			fx.append(effect_text(e))
		return ". ".join(fx) + "."
	if def is DisasterCardDef:
		var d: DisasterDefinition = (def as DisasterCardDef).disaster
		var dmg: String = str(d.damage_min) if d.damage_min == d.damage_max else "%d-%d" % [d.damage_min, d.damage_max]
		var who: String = "All opponents"
		if d.targeting == DisasterDefinition.Targeting.SINGLE_OPPONENT:
			who = "One opponent"
		elif d.targeting == DisasterDefinition.Targeting.OPPONENTS_WITHOUT_BUILDING:
			var cond: CardDefinition = catalog.card(d.condition_building_id)
			who = "Opponents without %s" % (cond.display_name if cond != null else d.condition_building_id)
		var s2: String = "Level %d. %s damage. %s." % [d.level, dmg, who]
		match d.secondary_kind:
			DisasterDefinition.SecondaryKind.EXTRA_BUILDING_DAMAGE:
				s2 += " Also damages a building by %d." % d.secondary_amount
			DisasterDefinition.SecondaryKind.DISCARD_RESERVE:
				s2 += " Targets discard %d from Reserve." % d.secondary_amount
			DisasterDefinition.SecondaryKind.DISCARD_RANDOM_HAND:
				s2 += " Targets discard %d random card(s)." % d.secondary_amount
		if d.level >= 2:
			s2 += " Forecast: strikes at the start of your next turn (or when the match ends, if cast in the final round)."
		return s2
	return ""


static func full_text(def: CardDefinition, catalog: ContentCatalog) -> String:
	return "%s\n%s" % [header_text(def, catalog), flavor_text(def)]


## Name, type, cost and rules: what a player needs to decide.
static func header_text(def: CardDefinition, catalog: ContentCatalog) -> String:
	return "%s  [%s]\nCost: %s\n%s" % [def.display_name, type_name(def), def.cost_text(), rules_text(def, catalog)]


## Flavor line and the real-world DRR tip.
static func flavor_text(def: CardDefinition) -> String:
	return "\"%s\"\nDRR tip: %s" % [def.flavor, def.dr_tip]

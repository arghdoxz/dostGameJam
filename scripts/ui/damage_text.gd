class_name DamageText
extends RefCounted
## Plain-text damage breakdowns for the UI. Numbers come from DamageCalculator so the text can
## never disagree with what resolution will do.


## "Mayor 2 (Coastal): 3-4 damage (base 4-5, territory -1, buildings -1 Seawall)".
## fixed_base >= 0 uses the rolled base of a live disaster instead of the card's range.
static func preview_line(state: MatchState, pid: int, dis: DisasterDefinition, reaction: int, fixed_base: int) -> String:
	var p: PlayerState = state.players[pid]
	var terr: TerritoryDefinition = state.catalog.territory(p.territory_id)
	var pv: Dictionary = DamageCalculator.preview(state, p, dis, reaction, fixed_base)
	return "%s (%s): %s damage %s" % [p.display_name, terr.display_name, _range(int(pv["min"]), int(pv["max"])),
		breakdown_text(state, pv)]


static func breakdown_text(state: MatchState, pv: Dictionary) -> String:
	var base_text: String = _range(int(pv["base_min"]), int(pv["base_max"]))
	var parts: PackedStringArray = PackedStringArray(["base " + base_text])
	if int(pv["territory"]) != 0:
		parts.append("territory %+d" % int(pv["territory"]))
	for b: Dictionary in (pv["buildings"] as Array):
		parts.append("%s -%d" % [_building_name(state, int(b["uid"]), pv), int(b["amount"])])
	if int(pv["reaction"]) > 0:
		parts.append("reaction -%d" % int(pv["reaction"]))
	return "(" + ", ".join(parts) + ")"


static func _building_name(state: MatchState, uid: int, _pv: Dictionary) -> String:
	for p: PlayerState in state.players:
		var b: BuildingInstance = p.find_building(uid)
		if b != null:
			return state.catalog.card(b.def_id).display_name
	return "building"


static func _range(lo: int, hi: int) -> String:
	return str(lo) if lo == hi else "%d-%d" % [lo, hi]

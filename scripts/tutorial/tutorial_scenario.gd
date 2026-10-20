class_name TutorialScenario
extends RefCounted
## The fixed two-mayor hot-seat match used by the tutorial. The learner plays both seats:
## Ana (seat 0, Coastal, goes first) and Ben (seat 1, Upland). Starting hands and the top of each deck are
## arranged so every step can be done. Cards are moved between hands and decks, never created, so
## the deck totals stay what the match config says. Only the tutorial uses this.

const SEED: int = 4242
const YOU_HAND: Array[String] = [
	"res_materials", "res_materials", "res_supplies", "bld_seawall",
	"prep_go_bag", "prep_barangay_drill", "prep_relief_operations", "dis_typhoon",
]
const RIVAL_HAND: Array[String] = [
	"dis_landslide", "res_supplies", "res_materials", "prep_preemptive_evacuation", "bld_drainage_system",
]
## Next cards drawn from each deck, first listed is drawn first.
const TOWN_TOP: Array[String] = ["res_materials", "res_funds", "res_supplies", "res_materials"]
const DISASTER_TOP: Array[String] = ["dis_flood", "dis_earthquake", "dis_flood"]


static func seats() -> Array[Dictionary]:
	return [
		{"name": "Ana", "territory_id": "terr_coastal"},
		{"name": "Ben", "territory_id": "terr_upland"},
	]


## Called by MatchController.start between new_match and start_match.
static func arrange(state: MatchState) -> void:
	state.first_player = 0
	state.current_player = 0
	for p: PlayerState in state.players:
		for c: CardInstance in p.hand:
			DeckSystem.deck_of(state, state.catalog.card(c.def_id).deck).append(c)
		p.hand.clear()
	for id: String in YOU_HAND:
		_deal(state, 0, id)
	for id: String in RIVAL_HAND:
		_deal(state, 1, id)
	_stack(state, CardDefinition.DeckKind.TOWN, TOWN_TOP)
	_stack(state, CardDefinition.DeckKind.DISASTER, DISASTER_TOP)


static func _take(state: MatchState, def_id: String) -> CardInstance:
	var deck: Array[CardInstance] = DeckSystem.deck_of(state, state.catalog.card(def_id).deck)
	for i: int in range(deck.size() - 1, -1, -1):
		if deck[i].def_id == def_id:
			return deck.pop_at(i)
	push_error("TutorialScenario: no %s left in the deck" % def_id)
	return null


static func _deal(state: MatchState, pid: int, def_id: String) -> void:
	var c: CardInstance = _take(state, def_id)
	if c != null:
		state.players[pid].hand.append(c)


## Puts the listed cards on top of the deck (drawn in the listed order).
static func _stack(state: MatchState, kind: CardDefinition.DeckKind, def_ids: Array[String]) -> void:
	var taken: Array[CardInstance] = []
	for id: String in def_ids:
		var c: CardInstance = _take(state, id)
		if c != null:
			taken.append(c)
	var deck: Array[CardInstance] = DeckSystem.deck_of(state, kind)
	for i: int in range(taken.size() - 1, -1, -1):
		deck.append(taken[i])

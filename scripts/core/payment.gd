class_name Payment
extends RefCounted
## Cost payment. A cost is paid by discarding resource cards from the hand.
## Supplies cards in the Reserve may also pay Supplies or "any" costs.


## Resource kind of a card instance ("" if it is not a resource card).
static func kind_of(catalog: ContentCatalog, card: CardInstance) -> String:
	var def: CardDefinition = catalog.card(card.def_id)
	if def is ResourceCardDef:
		return (def as ResourceCardDef).resource_kind
	return ""


## Checks that payment_uids exactly cover the cost. Returns "" if valid, else a reason.
static func check(state: MatchState, player: PlayerState, cost: Dictionary, payment_uids: Array[int]) -> String:
	var seen: Dictionary = {}
	var have: Dictionary = {}
	for uid: int in payment_uids:
		if seen.has(uid):
			return "Payment lists a card twice"
		seen[uid] = true
		var c: CardInstance = player.find_in_hand(uid)
		var from_reserve: bool = false
		if c == null:
			c = player.find_in_reserve(uid)
			from_reserve = true
		if c == null:
			return "Payment card is not in hand or Reserve"
		var kind: String = kind_of(state.catalog, c)
		if kind == "":
			return "Only resource cards can pay costs"
		if from_reserve and kind != ResourceCardDef.KIND_SUPPLIES:
			return "Reserve holds only Supplies"
		have[kind] = int(have.get(kind, 0)) + 1
	var total_have: int = payment_uids.size()
	var specific_need: int = 0
	for k: Variant in cost.keys():
		var key: String = String(k)
		if key == "any":
			continue
		var need: int = int(cost[k])
		specific_need += need
		if int(have.get(key, 0)) < need:
			return "Cost not paid: need %d %s" % [need, key]
	var any_need: int = int(cost.get("any", 0))
	if total_have != specific_need + any_need:
		return "Payment must match the cost exactly"
	return ""


## Picks cards to pay a cost. Prefers hand cards over Reserve cards and, for "any",
## spends the resource kind the player holds the most copies of.
## Returns {"ok": bool, "uids": Array[int]}.
static func auto_pay(state: MatchState, player: PlayerState, cost: Dictionary) -> Dictionary:
	var chosen: Array[int] = []
	var pool: Array[CardInstance] = []
	pool.append_array(player.hand)
	var reserve_pool: Array[CardInstance] = []
	reserve_pool.append_array(player.reserve)
	for k: Variant in cost.keys():
		var key: String = String(k)
		if key == "any":
			continue
		for i: int in range(int(cost[k])):
			var pick: CardInstance = _take_kind(state.catalog, pool, key)
			if pick == null:
				pick = _take_kind(state.catalog, reserve_pool, key)
			if pick == null:
				return {"ok": false, "uids": [] as Array[int]}
			chosen.append(pick.uid)
	for i: int in range(int(cost.get("any", 0))):
		var pick: CardInstance = _take_most_common(state.catalog, pool)
		if pick == null:
			pick = _take_kind(state.catalog, reserve_pool, ResourceCardDef.KIND_SUPPLIES)
		if pick == null:
			return {"ok": false, "uids": [] as Array[int]}
		chosen.append(pick.uid)
	return {"ok": true, "uids": chosen}


static func _take_kind(catalog: ContentCatalog, pool: Array[CardInstance], kind: String) -> CardInstance:
	for i: int in range(pool.size()):
		if kind_of(catalog, pool[i]) == kind:
			return pool.pop_at(i)
	return null


static func _take_most_common(catalog: ContentCatalog, pool: Array[CardInstance]) -> CardInstance:
	var counts: Dictionary = {}
	for c: CardInstance in pool:
		var k: String = kind_of(catalog, c)
		if k != "":
			counts[k] = int(counts.get(k, 0)) + 1
	var best: String = ""
	var best_n: int = 0
	var keys: Array = counts.keys()
	keys.sort()
	for k: Variant in keys:
		if int(counts[k]) > best_n:
			best_n = int(counts[k])
			best = String(k)
	if best == "":
		return null
	return _take_kind(catalog, pool, best)


## Removes paid cards from hand/Reserve and discards them.
static func spend(state: MatchState, player: PlayerState, payment_uids: Array[int], events: Array[GameEvent]) -> void:
	for uid: int in payment_uids:
		var c: CardInstance = player.remove_from_hand(uid)
		if c == null:
			c = player.remove_from_reserve(uid)
		if c != null:
			DeckSystem.discard(state, c)
	if not payment_uids.is_empty():
		events.append(GameEvent.new("cost_paid", {"player": player.id, "cards": payment_uids.duplicate()}))

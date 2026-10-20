class_name DisasterResolver
extends RefCounted
## Casting, Forecasts, the Reaction window and the resolution sequence
## (GAME_DESIGN section 6). L1 disasters resolve now; L2/L3 become public Forecasts
## that resolve at the start of the caster's next turn.


## Living opponents in turn order starting after the caster, filtered by targeting mode.
static func compute_targets(state: MatchState, caster_id: int, disaster: DisasterDefinition,
		chosen_player_id: int) -> Array[int]:
	var out: Array[int] = []
	var n: int = state.players.size()
	for offset: int in range(1, n):
		var pid: int = (caster_id + offset) % n
		var p: PlayerState = state.players[pid]
		if p.eliminated:
			continue
		match disaster.targeting:
			DisasterDefinition.Targeting.SINGLE_OPPONENT:
				if pid != chosen_player_id:
					continue
			DisasterDefinition.Targeting.OPPONENTS_WITHOUT_BUILDING:
				if p.has_building(disaster.condition_building_id):
					continue
		out.append(pid)
	return out


## Casts a disaster card that has already been paid for and discarded.
static func cast(state: MatchState, caster_id: int, card: CardInstance, chosen_player_id: int,
		events: Array[GameEvent]) -> void:
	var card_def: DisasterCardDef = state.catalog.card(card.def_id) as DisasterCardDef
	var dis: DisasterDefinition = card_def.disaster
	var pd: PendingDisaster = PendingDisaster.new()
	pd.seq = state.next_seq
	state.next_seq += 1
	pd.caster_id = caster_id
	pd.card_def_id = card_def.id
	pd.disaster_id = dis.id
	pd.level = dis.level
	pd.base_damage = state.rng.randi_range(dis.damage_min, dis.damage_max)
	pd.targets = compute_targets(state, caster_id, dis, chosen_player_id)
	events.append(GameEvent.new("disaster_cast", {
		"caster": caster_id, "card": card_def.id, "disaster": dis.id, "level": dis.level,
		"targets": pd.targets.duplicate()}))
	if pd.targets.is_empty():
		events.append(GameEvent.new("disaster_fizzled", {"caster": caster_id, "disaster": dis.id}))
		return
	if dis.level <= 1:
		begin_resolution(state, pd, MatchState.Resume.PLAY, events)
	else:
		pd.is_forecast = true
		state.forecasts.append(pd)
		events.append(GameEvent.new("forecast_placed", {
			"caster": caster_id, "disaster": dis.id, "level": dis.level,
			"targets": pd.targets.duplicate(), "seq": pd.seq}))


## Re-checks targets and opens the Reaction window. If nobody is affected the disaster fizzles.
## Returns true if a Reaction window opened (play must wait), false if it fizzled.
static func begin_resolution(state: MatchState, pd: PendingDisaster, resume: MatchState.Resume,
		events: Array[GameEvent]) -> bool:
	var dis: DisasterDefinition = state.catalog.disaster(pd.disaster_id)
	var live: Array[int] = []
	for pid: int in pd.targets:
		var p: PlayerState = state.players[pid]
		if p.eliminated:
			continue
		if dis.targeting == DisasterDefinition.Targeting.OPPONENTS_WITHOUT_BUILDING \
				and p.has_building(dis.condition_building_id):
			continue
		live.append(pid)
	pd.targets = live
	state.resume = resume
	if live.is_empty():
		events.append(GameEvent.new("disaster_fizzled", {"caster": pd.caster_id, "disaster": pd.disaster_id}))
		return false
	pd.reactor_index = 0
	state.pending = pd
	state.phase = MatchState.Phase.REACTION
	events.append(GameEvent.new("disaster_revealed", {
		"caster": pd.caster_id, "disaster": pd.disaster_id, "level": pd.level,
		"base": pd.base_damage, "targets": live.duplicate(), "forecast": pd.is_forecast}))
	events.append(GameEvent.new("reaction_window_opened", {"player": pd.current_reactor()}))
	return true


static func react(state: MatchState, player: PlayerState, card: CardInstance,
		payment_uids: Array[int], events: Array[GameEvent]) -> void:
	var pd: PendingDisaster = state.pending
	var dis: DisasterDefinition = state.catalog.disaster(pd.disaster_id)
	var def: PreparednessCardDef = state.catalog.card(card.def_id) as PreparednessCardDef
	Payment.spend(state, player, payment_uids, events)
	player.remove_from_hand(card.uid)
	DeckSystem.discard(state, card)
	var reduced: int = 0
	for e: EffectDefinition in def.effects:
		if e.kind == EffectDefinition.Kind.DAMAGE_REDUCTION and (e.tag == "" or dis.tags.has(e.tag)):
			reduced += e.amount
	pd.reductions[player.id] = int(pd.reductions.get(player.id, 0)) + reduced
	events.append(GameEvent.new("reaction_played", {
		"player": player.id, "card": card.def_id, "reduction": reduced}))
	_advance_reactor(state, events)


static func pass_reaction(state: MatchState, player: PlayerState, events: Array[GameEvent]) -> void:
	events.append(GameEvent.new("reaction_passed", {"player": player.id}))
	_advance_reactor(state, events)


static func _advance_reactor(state: MatchState, events: Array[GameEvent]) -> void:
	var pd: PendingDisaster = state.pending
	pd.reactor_index += 1
	if pd.reactor_index >= pd.targets.size():
		_resolve(state, events)
	else:
		events.append(GameEvent.new("reaction_window_opened", {"player": pd.current_reactor()}))


static func _resolve(state: MatchState, events: Array[GameEvent]) -> void:
	var pd: PendingDisaster = state.pending
	var dis: DisasterDefinition = state.catalog.disaster(pd.disaster_id)
	var loss: int = DamageCalculator.durability_loss(dis.level)
	# Approved 2026-10-20: the simultaneous-elimination tiebreak uses durability before the blow.
	var pre_durability: Dictionary = {}
	for pid: int in pd.targets:
		pre_durability[pid] = state.players[pid].total_durability()
	for pid: int in pd.targets:
		var p: PlayerState = state.players[pid]
		var bd: Dictionary = DamageCalculator.breakdown(state, p, dis, pd.base_damage, int(pd.reductions.get(pid, 0)))
		var final_damage: int = int(bd["final"])
		p.rp = maxi(0, p.rp - final_damage)
		events.append(GameEvent.new("damage_dealt", {
			"player": pid, "amount": final_damage, "base": pd.base_damage,
			"territory": bd["territory"], "reaction": bd["reaction"], "buildings": bd["buildings"],
			"rp": p.rp, "disaster": dis.id}))
		for used: Dictionary in (bd["buildings"] as Array):
			_damage_building(state, p, int(used["uid"]), loss, events)
		if p.rp > 0:
			_apply_secondary(state, p, dis, final_damage, events)
	_eliminate_and_check(state, pd, pre_durability, events)
	_after_resolution(state, events)


static func _damage_building(state: MatchState, p: PlayerState, uid: int, amount: int,
		events: Array[GameEvent]) -> void:
	var b: BuildingInstance = p.find_building(uid)
	if b == null:
		return
	var destroyed: bool = DamageCalculator.damage_building(b, amount)
	events.append(GameEvent.new("building_damaged", {
		"player": p.id, "building": uid, "def": b.def_id, "durability": b.durability}))
	if destroyed:
		p.buildings.erase(b)
		DeckSystem.discard(state, CardInstance.new(b.uid, b.def_id))
		events.append(GameEvent.new("building_destroyed", {"player": p.id, "building": uid, "def": b.def_id}))


static func _apply_secondary(state: MatchState, p: PlayerState, dis: DisasterDefinition,
		final_damage: int, events: Array[GameEvent]) -> void:
	match dis.secondary_kind:
		DisasterDefinition.SecondaryKind.EXTRA_BUILDING_DAMAGE:
			if final_damage > 0 and not p.buildings.is_empty():
				var idx: int = state.rng.randi_range(0, p.buildings.size() - 1)
				var target: BuildingInstance = p.buildings[idx]
				events.append(GameEvent.new("secondary_effect", {
					"player": p.id, "kind": "building_damage", "building": target.uid}))
				_damage_building(state, p, target.uid, dis.secondary_amount, events)
		DisasterDefinition.SecondaryKind.DISCARD_RESERVE:
			var n: int = mini(dis.secondary_amount, p.reserve.size())
			for i: int in range(n):
				var c: CardInstance = p.reserve.pop_back()
				DeckSystem.discard(state, c)
			if n > 0:
				events.append(GameEvent.new("secondary_effect", {
					"player": p.id, "kind": "discard_reserve", "count": n}))
		DisasterDefinition.SecondaryKind.DISCARD_RANDOM_HAND:
			var m: int = mini(dis.secondary_amount, p.hand.size())
			for i: int in range(m):
				var idx2: int = state.rng.randi_range(0, p.hand.size() - 1)
				DeckSystem.discard(state, p.hand.pop_at(idx2))
			if m > 0:
				events.append(GameEvent.new("secondary_effect", {
					"player": p.id, "kind": "discard_hand", "count": m}))


static func _eliminate_and_check(state: MatchState, pd: PendingDisaster, pre_durability: Dictionary,
		events: Array[GameEvent]) -> void:
	var dying: Array[PlayerState] = []
	for pid: int in pd.targets:
		var p: PlayerState = state.players[pid]
		if p.rp <= 0 and not p.eliminated:
			dying.append(p)
	if dying.is_empty():
		return
	var living_count: int = state.living_players().size()
	if dying.size() == living_count:
		var winners: Array[int] = VictoryEvaluator.simultaneous_winners(dying, pre_durability)
		for p: PlayerState in dying:
			eliminate(state, p, events)
		VictoryEvaluator.finish(state, winners, VictoryEvaluator.REASON_SIMULTANEOUS, events)
		return
	for p: PlayerState in dying:
		eliminate(state, p, events)
	var last: Array[int] = VictoryEvaluator.last_standing(state)
	if not last.is_empty():
		VictoryEvaluator.finish(state, last, VictoryEvaluator.REASON_LAST_STANDING, events)


## Removes a town from play: its cards go to the discards and Forecasts against it are dropped.
static func eliminate(state: MatchState, p: PlayerState, events: Array[GameEvent]) -> void:
	p.eliminated = true
	p.rp = 0
	for c: CardInstance in p.hand:
		DeckSystem.discard(state, c)
	for c: CardInstance in p.reserve:
		DeckSystem.discard(state, c)
	for b: BuildingInstance in p.buildings:
		DeckSystem.discard(state, CardInstance.new(b.uid, b.def_id))
	p.hand.clear()
	p.reserve.clear()
	p.buildings.clear()
	for f: PendingDisaster in state.forecasts.duplicate():
		f.targets.erase(p.id)
		if f.targets.is_empty():
			state.forecasts.erase(f)
	events.append(GameEvent.new("player_eliminated", {"player": p.id}))


static func _after_resolution(state: MatchState, events: Array[GameEvent]) -> void:
	state.pending = null
	if state.is_over():
		return
	state.phase = MatchState.Phase.PLAY
	match state.resume:
		MatchState.Resume.RECOVERY:
			TurnSystem.run_recovery(state, events)
		MatchState.Resume.FINAL:
			TurnSystem.run_final_resolution(state, events)

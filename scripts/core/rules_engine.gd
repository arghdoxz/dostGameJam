class_name RulesEngine
extends RefCounted
## The only entry point that changes match state.
##   new_match()/start_match()  create a match
##   validate(state, action)    is this action legal right now? (no state change)
##   apply(state, action)       change state, return the events that happened
## No Node or UI references: usable headless and, later, behind a network server.


## Checks seat setup. Each seat is {"name": String, "territory_id": String}.
static func validate_setup(config: MatchConfig, catalog: ContentCatalog, seats: Array[Dictionary]) -> ValidationResult:
	if seats.size() < config.min_players or seats.size() > config.max_players:
		return ValidationResult.reject("Need %d to %d players" % [config.min_players, config.max_players])
	var used: Dictionary = {}
	for s: Dictionary in seats:
		var t: String = String(s.get("territory_id", ""))
		if catalog.territory(t) == null:
			return ValidationResult.reject("Unknown territory: " + t)
		if used.has(t):
			return ValidationResult.reject("Territories must be distinct")
		used[t] = true
	return ValidationResult.accept()


## Builds a match: decks, towns, starting hands, random first player. Does not begin turn 1.
static func new_match(config: MatchConfig, catalog: ContentCatalog, seats: Array[Dictionary], seed_value: int) -> MatchState:
	var state: MatchState = MatchState.new()
	state.config = config
	state.catalog = catalog
	state.seed_value = seed_value
	state.rng.seed = seed_value
	DeckSystem.build_decks(state)
	for i: int in range(seats.size()):
		var p: PlayerState = PlayerState.new()
		p.id = i
		p.display_name = String(seats[i].get("name", "Mayor %d" % (i + 1)))
		p.territory_id = String(seats[i]["territory_id"])
		p.rp = config.starting_rp
		state.players.append(p)
	var scratch: Array[GameEvent] = []
	for p: PlayerState in state.players:
		for n: int in range(config.starting_hand):
			DeckSystem.draw_to_hand(state, p, CardDefinition.DeckKind.TOWN, scratch)
	state.first_player = state.rng.randi_range(0, state.players.size() - 1)
	state.current_player = state.first_player
	state.round_number = 1
	return state


## Begins the first player's turn.
static func start_match(state: MatchState) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	events.append(GameEvent.new("match_started", {"first_player": state.first_player, "seed": state.seed_value}))
	TurnSystem.begin_turn(state, events)
	return events


# ---------------------------------------------------------------- validation

static func validate(state: MatchState, action: GameAction) -> ValidationResult:
	if action == null:
		return ValidationResult.reject("Unknown action")
	if state.is_over():
		return ValidationResult.reject("The game is over")
	if action.player_id < 0 or action.player_id >= state.players.size():
		return ValidationResult.reject("Unknown player")
	var actor: int = state.actor_id()
	if action.player_id != actor:
		if state.phase == MatchState.Phase.REACTION:
			return ValidationResult.reject("It is not your Reaction window")
		return ValidationResult.reject("It is not your turn")
	var player: PlayerState = state.players[action.player_id]
	match action.type:
		GameAction.DRAW:
			return _validate_draw(state, action as DrawAction)
		GameAction.RESERVE:
			return _validate_reserve(state, player, action as ReserveAction)
		GameAction.PLAY_CARD:
			return _validate_play(state, player, action as PlayCardAction)
		GameAction.REACT:
			return _validate_react(state, player, action as ReactAction)
		GameAction.PASS_REACTION:
			if state.phase != MatchState.Phase.REACTION:
				return ValidationResult.reject("No Reaction window is open")
			return ValidationResult.accept()
		GameAction.END_TURN:
			return _validate_end_turn(state, player, action as EndTurnAction)
	return ValidationResult.reject("Unknown action type")


static func _validate_draw(state: MatchState, a: DrawAction) -> ValidationResult:
	if state.phase != MatchState.Phase.DRAW:
		return ValidationResult.reject("You can only draw at the start of your turn")
	if DeckSystem.both_empty(state):
		return ValidationResult.accept()
	if not DeckSystem.can_draw(state, a.deck):
		return ValidationResult.reject("That deck is empty")
	return ValidationResult.accept()


static func _validate_reserve(state: MatchState, player: PlayerState, a: ReserveAction) -> ValidationResult:
	if state.phase != MatchState.Phase.PLAY:
		return ValidationResult.reject("You can only do that during the Play phase")
	var c: CardInstance = player.find_in_hand(a.card_uid)
	if c == null:
		return ValidationResult.reject("Card is not in your hand")
	if Payment.kind_of(state.catalog, c) != ResourceCardDef.KIND_SUPPLIES:
		return ValidationResult.reject("Only Supplies can go in the Reserve")
	return ValidationResult.accept()


static func _validate_play(state: MatchState, player: PlayerState, a: PlayCardAction) -> ValidationResult:
	if state.phase != MatchState.Phase.PLAY:
		return ValidationResult.reject("You can only play cards during the Play phase")
	if state.plays_remaining <= 0:
		return ValidationResult.reject("No plays left this turn")
	var card: CardInstance = player.find_in_hand(a.card_uid)
	if card == null:
		return ValidationResult.reject("Card is not in your hand")
	var def: CardDefinition = state.catalog.card(card.def_id)
	if def.card_type == CardDefinition.CardType.RESOURCE:
		return ValidationResult.reject("Resource cards are spent as payment, not played")
	if def.card_type == CardDefinition.CardType.REACTION:
		return ValidationResult.reject("Reactions can only be played in a Reaction window")
	if a.payment_uids.has(a.card_uid):
		return ValidationResult.reject("A card cannot pay for itself")
	var pay: String = Payment.check(state, player, def.cost, a.payment_uids)
	if pay != "":
		return ValidationResult.reject(pay)
	if def is PreparednessCardDef:
		for e: EffectDefinition in (def as PreparednessCardDef).effects:
			if e.kind == EffectDefinition.Kind.REPAIR:
				var b: BuildingInstance = player.find_building(a.target_building_uid)
				if b == null:
					return ValidationResult.reject("Choose one of your buildings to repair")
				if b.durability >= state.catalog.building(b.def_id).durability:
					return ValidationResult.reject("That building is undamaged")
	elif def is DisasterCardDef:
		var dis: DisasterDefinition = (def as DisasterCardDef).disaster
		if dis.targeting == DisasterDefinition.Targeting.SINGLE_OPPONENT:
			if a.target_player_id == player.id:
				return ValidationResult.reject("You cannot target yourself")
			if a.target_player_id < 0 or a.target_player_id >= state.players.size():
				return ValidationResult.reject("Choose a target town")
			if state.players[a.target_player_id].eliminated:
				return ValidationResult.reject("That town is eliminated")
	return ValidationResult.accept()


static func _validate_react(state: MatchState, player: PlayerState, a: ReactAction) -> ValidationResult:
	if state.phase != MatchState.Phase.REACTION:
		return ValidationResult.reject("No Reaction window is open")
	var card: CardInstance = player.find_in_hand(a.card_uid)
	if card == null:
		return ValidationResult.reject("Card is not in your hand")
	var def: CardDefinition = state.catalog.card(card.def_id)
	if def.card_type != CardDefinition.CardType.REACTION:
		return ValidationResult.reject("That is not a Reaction card")
	var pay: String = Payment.check(state, player, def.cost, a.payment_uids)
	if pay != "":
		return ValidationResult.reject(pay)
	return ValidationResult.accept()


static func _validate_end_turn(state: MatchState, player: PlayerState, a: EndTurnAction) -> ValidationResult:
	if state.phase == MatchState.Phase.DRAW:
		return ValidationResult.reject("Draw a card before ending your turn")
	if state.phase != MatchState.Phase.PLAY:
		return ValidationResult.reject("You cannot end your turn now")
	var excess: int = maxi(0, player.hand.size() - state.config.hand_limit)
	if a.discard_uids.size() != excess:
		return ValidationResult.reject("Discard exactly %d card(s) to reach the hand limit" % excess)
	var seen: Dictionary = {}
	for uid: int in a.discard_uids:
		if seen.has(uid) or player.find_in_hand(uid) == null:
			return ValidationResult.reject("Invalid discard choice")
		seen[uid] = true
	return ValidationResult.accept()


# ---------------------------------------------------------------- application

## Applies a validated action. An illegal action changes nothing and yields one
## "action_rejected" event.
static func apply(state: MatchState, action: GameAction) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	var v: ValidationResult = validate(state, action)
	if not v.ok:
		events.append(GameEvent.new("action_rejected", {"reason": v.reason}))
		return events
	var player: PlayerState = state.players[action.player_id]
	match action.type:
		GameAction.DRAW:
			_apply_draw(state, player, action as DrawAction, events)
		GameAction.RESERVE:
			var ra: ReserveAction = action as ReserveAction
			var c: CardInstance = player.remove_from_hand(ra.card_uid)
			player.reserve.append(c)
			events.append(GameEvent.new("card_reserved", {"player": player.id, "card": c.uid}))
		GameAction.PLAY_CARD:
			_apply_play(state, player, action as PlayCardAction, events)
		GameAction.REACT:
			var rc: ReactAction = action as ReactAction
			DisasterResolver.react(state, player, player.find_in_hand(rc.card_uid), rc.payment_uids, events)
		GameAction.PASS_REACTION:
			DisasterResolver.pass_reaction(state, player, events)
		GameAction.END_TURN:
			var ea: EndTurnAction = action as EndTurnAction
			for uid: int in ea.discard_uids:
				DeckSystem.discard(state, player.remove_from_hand(uid))
			if not ea.discard_uids.is_empty():
				events.append(GameEvent.new("cards_discarded", {"player": player.id, "cards": ea.discard_uids.duplicate()}))
			TurnSystem.end_turn(state, events)
	return events


static func _apply_draw(state: MatchState, player: PlayerState, a: DrawAction, events: Array[GameEvent]) -> void:
	if DeckSystem.both_empty(state):
		events.append(GameEvent.new("draw_skipped", {"player": player.id}))
	else:
		DeckSystem.draw_to_hand(state, player, a.deck, events)
	state.phase = MatchState.Phase.PLAY


static func _apply_play(state: MatchState, player: PlayerState, a: PlayCardAction, events: Array[GameEvent]) -> void:
	var card: CardInstance = player.find_in_hand(a.card_uid)
	var def: CardDefinition = state.catalog.card(card.def_id)
	Payment.spend(state, player, a.payment_uids, events)
	player.remove_from_hand(card.uid)
	state.plays_remaining -= 1
	events.append(GameEvent.new("card_played", {"player": player.id, "card": card.uid, "def": def.id}))
	if def is BuildingCardDef:
		var bdef: BuildingDefinition = (def as BuildingCardDef).building
		player.buildings.append(BuildingInstance.new(card.uid, def.id, bdef.durability))
		events.append(GameEvent.new("building_built", {
			"player": player.id, "building": card.uid, "def": def.id, "durability": bdef.durability}))
	elif def is PreparednessCardDef:
		DeckSystem.discard(state, card)
		for e: EffectDefinition in (def as PreparednessCardDef).effects:
			_apply_effect(state, player, e, a, events)
	elif def is DisasterCardDef:
		DeckSystem.discard(state, card)
		DisasterResolver.cast(state, player.id, card, a.target_player_id, events)


static func _apply_effect(state: MatchState, player: PlayerState, e: EffectDefinition,
		a: PlayCardAction, events: Array[GameEvent]) -> void:
	match e.kind:
		EffectDefinition.Kind.HEAL:
			var healed: int = mini(e.amount, state.config.starting_rp - player.rp)
			healed = maxi(0, healed)
			player.rp += healed
			events.append(GameEvent.new("healed", {"player": player.id, "amount": healed, "rp": player.rp}))
		EffectDefinition.Kind.REPAIR:
			var b: BuildingInstance = player.find_building(a.target_building_uid)
			if b != null:
				var max_dur: int = state.catalog.building(b.def_id).durability
				b.durability = mini(max_dur, b.durability + e.amount)
				events.append(GameEvent.new("building_repaired", {
					"player": player.id, "building": b.uid, "durability": b.durability}))
		EffectDefinition.Kind.DRAW:
			for i: int in range(e.amount):
				if DeckSystem.draw_to_hand(state, player, CardDefinition.DeckKind.TOWN, events) == null:
					events.append(GameEvent.new("draw_skipped", {"player": player.id, "deck": int(CardDefinition.DeckKind.TOWN)}))
					break
		EffectDefinition.Kind.EXTRA_PLAY:
			state.plays_remaining += e.amount
			events.append(GameEvent.new("extra_play", {"player": player.id, "amount": e.amount}))

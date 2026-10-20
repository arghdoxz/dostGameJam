class_name ActionEnumerator
extends RefCounted
## Lists legal actions for the current actor with payment chosen automatically.
## Used by the UI to enable controls and by test bots. Rules stay in RulesEngine:
## every action returned here is still checked by RulesEngine.validate.


static func legal_actions(state: MatchState) -> Array[GameAction]:
	var out: Array[GameAction] = []
	if state.is_over():
		return out
	var player: PlayerState = state.players[state.actor_id()]
	match state.phase:
		MatchState.Phase.DRAW:
			for kind: CardDefinition.DeckKind in [CardDefinition.DeckKind.TOWN, CardDefinition.DeckKind.DISASTER]:
				if DeckSystem.can_draw(state, kind):
					out.append(DrawAction.new(player.id, kind))
			if out.is_empty():
				out.append(DrawAction.new(player.id, CardDefinition.DeckKind.TOWN))
		MatchState.Phase.PLAY:
			_play_actions(state, player, out)
			out.append(EndTurnAction.new(player.id, default_discards(state, player)))
		MatchState.Phase.REACTION:
			for c: CardInstance in player.hand:
				var def: CardDefinition = state.catalog.card(c.def_id)
				if def.card_type != CardDefinition.CardType.REACTION:
					continue
				var pay: Dictionary = Payment.auto_pay(state, player, def.cost)
				if bool(pay["ok"]):
					out.append(ReactAction.new(player.id, c.uid, pay["uids"] as Array[int]))
			out.append(PassReactionAction.new(player.id))
	return out


static func _play_actions(state: MatchState, player: PlayerState, out: Array[GameAction]) -> void:
	for c: CardInstance in player.hand:
		var def: CardDefinition = state.catalog.card(c.def_id)
		if def.card_type == CardDefinition.CardType.RESOURCE:
			if Payment.kind_of(state.catalog, c) == ResourceCardDef.KIND_SUPPLIES:
				out.append(ReserveAction.new(player.id, c.uid))
			continue
		if def.card_type == CardDefinition.CardType.REACTION or state.plays_remaining <= 0:
			continue
		var pay: Dictionary = Payment.auto_pay(state, player, def.cost)
		if not bool(pay["ok"]):
			continue
		var uids: Array[int] = pay["uids"] as Array[int]
		if def is DisasterCardDef:
			var dis: DisasterDefinition = (def as DisasterCardDef).disaster
			if dis.targeting == DisasterDefinition.Targeting.SINGLE_OPPONENT:
				for opp: PlayerState in state.players:
					if opp.id != player.id and not opp.eliminated:
						var a: PlayCardAction = PlayCardAction.new(player.id, c.uid, uids)
						a.target_player_id = opp.id
						out.append(a)
			else:
				out.append(PlayCardAction.new(player.id, c.uid, uids))
		elif def is PreparednessCardDef and _needs_repair_target(def as PreparednessCardDef):
			for b: BuildingInstance in player.buildings:
				if b.durability < state.catalog.building(b.def_id).durability:
					var r: PlayCardAction = PlayCardAction.new(player.id, c.uid, uids)
					r.target_building_uid = b.uid
					out.append(r)
		else:
			out.append(PlayCardAction.new(player.id, c.uid, uids))


static func _needs_repair_target(def: PreparednessCardDef) -> bool:
	for e: EffectDefinition in def.effects:
		if e.kind == EffectDefinition.Kind.REPAIR:
			return true
	return false


## Why a hand card cannot be used by this player right now, or "" if some legal action
## uses it. Built from the same enumeration the UI uses, so the explanation never disagrees
## with what the buttons offer.
static func explain(state: MatchState, player_id: int, card_uid: int) -> String:
	if state.is_over():
		return "The game is over."
	var player: PlayerState = state.players[player_id]
	var card: CardInstance = player.find_in_hand(card_uid)
	if card == null:
		return "That card is not in your hand."
	if state.actor_id() != player_id:
		return "Not your turn."
	for a: GameAction in legal_actions(state):
		if _card_uid(a) == card_uid:
			return ""
	var def: CardDefinition = state.catalog.card(card.def_id)
	if def.card_type == CardDefinition.CardType.RESOURCE:
		if Payment.kind_of(state.catalog, card) == ResourceCardDef.KIND_SUPPLIES:
			return "Supplies can be banked in the Reserve during your Play phase."
		return "Resources are spent automatically to pay costs."
	if state.phase == MatchState.Phase.DRAW:
		return "Draw a card first."
	if state.phase == MatchState.Phase.REACTION:
		if def.card_type != CardDefinition.CardType.REACTION:
			return "Only Reaction cards can be played during a Reaction window."
		return "You cannot pay for this Reaction. Need: %s." % def.cost_text()
	if def.card_type == CardDefinition.CardType.REACTION:
		return "Reactions are played when a disaster strikes you."
	if state.plays_remaining <= 0:
		return "No plays left this turn."
	if not bool(Payment.auto_pay(state, player, def.cost)["ok"]):
		return "Cannot afford it. Need: %s." % def.cost_text()
	if def is PreparednessCardDef and _needs_repair_target(def as PreparednessCardDef):
		return "You have no damaged building to repair."
	if def is DisasterCardDef:
		return "There is no town you can target."
	return "This card cannot be played now."


static func _card_uid(a: GameAction) -> int:
	if a is PlayCardAction:
		return (a as PlayCardAction).card_uid
	if a is ReserveAction:
		return (a as ReserveAction).card_uid
	if a is ReactAction:
		return (a as ReactAction).card_uid
	return -1


## Cards to discard to reach the hand limit: resources first, then the rest, oldest first.
static func default_discards(state: MatchState, player: PlayerState) -> Array[int]:
	var excess: int = maxi(0, player.hand.size() - state.config.hand_limit)
	var out: Array[int] = []
	for pass_resources: bool in [true, false]:
		for c: CardInstance in player.hand:
			if out.size() >= excess:
				return out
			var is_res: bool = state.catalog.card(c.def_id).card_type == CardDefinition.CardType.RESOURCE
			if is_res == pass_resources and not out.has(c.uid):
				out.append(c.uid)
	return out

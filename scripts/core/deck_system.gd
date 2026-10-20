class_name DeckSystem
extends RefCounted
## Deck creation, drawing, discarding and reshuffling. Uses the match's seeded rng.


static func build_decks(state: MatchState) -> void:
	state.town_deck = _build(state, state.config.town_deck)
	state.disaster_deck = _build(state, state.config.disaster_deck)
	shuffle(state, state.town_deck)
	shuffle(state, state.disaster_deck)


static func _build(state: MatchState, counts: Dictionary) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	var ids: Array = counts.keys()
	ids.sort()
	for k: Variant in ids:
		for i: int in range(int(counts[k])):
			out.append(CardInstance.new(state.new_uid(), String(k)))
	return out


## Fisher-Yates using the match rng so shuffles are deterministic per seed.
static func shuffle(state: MatchState, cards: Array[CardInstance]) -> void:
	for i: int in range(cards.size() - 1, 0, -1):
		var j: int = state.rng.randi_range(0, i)
		var tmp: CardInstance = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


static func deck_of(state: MatchState, kind: CardDefinition.DeckKind) -> Array[CardInstance]:
	return state.town_deck if kind == CardDefinition.DeckKind.TOWN else state.disaster_deck


static func discard_of(state: MatchState, kind: CardDefinition.DeckKind) -> Array[CardInstance]:
	return state.town_discard if kind == CardDefinition.DeckKind.TOWN else state.disaster_discard


## True if a draw from this deck could produce a card (deck or its discard has cards).
static func can_draw(state: MatchState, kind: CardDefinition.DeckKind) -> bool:
	return not deck_of(state, kind).is_empty() or not discard_of(state, kind).is_empty()


static func both_empty(state: MatchState) -> bool:
	return not can_draw(state, CardDefinition.DeckKind.TOWN) and not can_draw(state, CardDefinition.DeckKind.DISASTER)


## Pops the top card, reshuffling the discard pile in first if the deck is empty.
## Returns null if nothing is left.
static func draw_card(state: MatchState, kind: CardDefinition.DeckKind, events: Array[GameEvent]) -> CardInstance:
	var deck: Array[CardInstance] = deck_of(state, kind)
	if deck.is_empty():
		var disc: Array[CardInstance] = discard_of(state, kind)
		if disc.is_empty():
			return null
		deck.append_array(disc)
		disc.clear()
		shuffle(state, deck)
		events.append(GameEvent.new("deck_reshuffled", {"deck": int(kind)}))
	return deck.pop_back()


## Puts a card on the discard pile that matches its definition's deck.
static func discard(state: MatchState, card: CardInstance) -> void:
	var def: CardDefinition = state.catalog.card(card.def_id)
	discard_of(state, def.deck).append(card)


static func draw_to_hand(state: MatchState, player: PlayerState, kind: CardDefinition.DeckKind,
		events: Array[GameEvent]) -> CardInstance:
	var c: CardInstance = draw_card(state, kind, events)
	if c == null:
		return null
	player.hand.append(c)
	events.append(GameEvent.new("card_drawn", {"player": player.id, "deck": int(kind), "card": c.uid, "def": c.def_id}))
	return c

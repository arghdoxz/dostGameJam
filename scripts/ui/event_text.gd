class_name EventText
extends RefCounted
## Turns GameEvents into readable log lines. Hidden information (drawn cards) is never named.


static func _name(state: MatchState, id: int) -> String:
	if id >= 0 and id < state.players.size():
		return state.players[id].display_name
	return "?"


static func _card(state: MatchState, def_id: String) -> String:
	var d: CardDefinition = state.catalog.card(def_id)
	return d.display_name if d != null else def_id


static func _names(state: MatchState, ids: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for i: Variant in ids:
		out.append(_name(state, int(i)))
	return ", ".join(out)


static func _secondary(d: Dictionary) -> String:
	match String(d["kind"]):
		"building_damage":
			return "a building takes extra damage"
		"discard_reserve":
			return "%d Reserve card(s) lost" % int(d.get("count", 0))
		"discard_hand":
			return "%d random hand card(s) discarded" % int(d.get("count", 0))
	return String(d["kind"])


## Plain-language reason a match ended (shared by the log and the results screen).
static func end_reason_text(reason: String) -> String:
	match reason:
		VictoryEvaluator.REASON_LAST_STANDING:
			return "Last town standing"
		VictoryEvaluator.REASON_PREPAREDNESS:
			return "Preparedness objectives completed: Evacuation Center, Early Warning System and the Reserve Supplies target"
		VictoryEvaluator.REASON_ROUND_CAP:
			return "The round cap was reached: highest RP wins (ties: objectives, then intact buildings)"
		VictoryEvaluator.REASON_SIMULTANEOUS:
			return "Every remaining town fell at the same moment: the town with the most building durability before the blow wins"
	return reason


## Returns the log line for an event, or "" if the event is not worth showing.
static func describe(e: GameEvent, state: MatchState) -> String:
	var d: Dictionary = e.data
	match e.type:
		"match_started":
			return "Match started. %s goes first." % _name(state, int(d["first_player"]))
		"turn_started":
			return "--- Round %d: %s's turn ---" % [int(d["round"]), _name(state, int(d["player"]))]
		"round_started":
			return "== Round %d begins ==" % int(d["round"])
		"card_drawn":
			var deck: String = "Town" if int(d["deck"]) == CardDefinition.DeckKind.TOWN else "Disaster"
			return "%s drew from the %s deck." % [_name(state, int(d["player"])), deck]
		"draw_skipped":
			if d.has("deck"):
				return "%s found no card to draw: the Town deck and its discard are empty." % _name(state, int(d["player"]))
			return "%s could not draw: both decks are empty." % _name(state, int(d["player"]))
		"final_resolution_started":
			return "== Round cap reached: %d forecast(s) resolve before the final scoring ==" % int(d["forecasts"])
		"deck_reshuffled":
			return "A discard pile was reshuffled into its deck."
		"card_reserved":
			return "%s banked Supplies in the Reserve." % _name(state, int(d["player"]))
		"cost_paid":
			return "%s paid %d card(s)." % [_name(state, int(d["player"])), (d["cards"] as Array).size()]
		"card_played":
			return "%s played %s." % [_name(state, int(d["player"])), _card(state, String(d["def"]))]
		"building_built":
			return "%s built %s (durability %d)." % [_name(state, int(d["player"])), _card(state, String(d["def"])), int(d["durability"])]
		"healed":
			return "%s healed %d RP (now %d)." % [_name(state, int(d["player"])), int(d["amount"]), int(d["rp"])]
		"building_repaired":
			return "%s repaired a building (durability %d)." % [_name(state, int(d["player"])), int(d["durability"])]
		"extra_play":
			return "%s gains +%d Play." % [_name(state, int(d["player"])), int(d["amount"])]
		"building_effect":
			return "%s's building restored %d RP (now %d)." % [_name(state, int(d["player"])), int(d["healed"]), int(d["rp"])]
		"disaster_cast":
			return "%s cast %s (level %d)." % [_name(state, int(d["caster"])), _card(state, String(d["card"])), int(d["level"])]
		"forecast_placed":
			return "!! WARNING: %s forecast on %s. It strikes at the start of %s's next turn, or at the round cap if that comes first." % [
				_card(state, "dis_" + String(d["disaster"]).trim_prefix("disaster_")),
				_names(state, d["targets"] as Array), _name(state, int(d["caster"]))]
		"disaster_fizzled":
			return "The disaster affects nobody and fizzles."
		"disaster_revealed":
			return "!! DISASTER: %s (base damage %d) strikes %s." % [
				_card(state, "dis_" + String(d["disaster"]).trim_prefix("disaster_")),
				int(d["base"]), _names(state, d["targets"] as Array)]
		"reaction_played":
			return "%s reacted with %s (-%d damage)." % [_name(state, int(d["player"])), _card(state, String(d["card"])), int(d["reduction"])]
		"reaction_passed":
			return "%s did not react." % _name(state, int(d["player"]))
		"damage_dealt":
			var bsum: int = 0
			for b: Dictionary in (d["buildings"] as Array):
				bsum += int(b["amount"])
			return "%s takes %d damage (base %d, territory %+d, buildings -%d, reaction -%d). RP: %d." % [
				_name(state, int(d["player"])), int(d["amount"]), int(d["base"]), int(d["territory"]),
				bsum, int(d["reaction"]), int(d["rp"])]
		"building_damaged":
			return "%s's %s drops to durability %d." % [_name(state, int(d["player"])), _card(state, String(d["def"])), int(d["durability"])]
		"building_destroyed":
			return "%s's %s was destroyed!" % [_name(state, int(d["player"])), _card(state, String(d["def"]))]
		"secondary_effect":
			return "%s suffers a secondary effect: %s." % [_name(state, int(d["player"])), _secondary(d)]
		"player_eliminated":
			return "XX %s's town is eliminated!" % _name(state, int(d["player"]))
		"cards_discarded":
			return "%s discarded down to the hand limit." % _name(state, int(d["player"]))
		"turn_ended":
			return ""
		"game_over":
			return "GAME OVER: %s. Winner(s): %s." % [end_reason_text(String(d["reason"])), _names(state, d["winners"] as Array)]
		"action_rejected":
			return "Rejected: %s" % String(d["reason"])
	return ""

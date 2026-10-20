class_name MatchState
extends RefCounted
## The complete, serializable state of one match. Mutated only by the rules engine.

enum Phase { DRAW, PLAY, REACTION, GAME_OVER }
## What happens when a Reaction window closes: continue the owner's recovery, return to
## the Play phase, or continue resolving outstanding Forecasts at the round cap.
enum Resume { RECOVERY, PLAY, FINAL }

var config: MatchConfig
## Definition lookup. Runtime reference only, not part of to_dict().
var catalog: ContentCatalog
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 0
var next_uid: int = 1
var next_seq: int = 1

var players: Array[PlayerState] = []
var town_deck: Array[CardInstance] = []
var town_discard: Array[CardInstance] = []
var disaster_deck: Array[CardInstance] = []
var disaster_discard: Array[CardInstance] = []

var phase: Phase = Phase.DRAW
var current_player: int = 0
var first_player: int = 0
var round_number: int = 1
var plays_remaining: int = 0
## Forecasts in the order they were cast.
var forecasts: Array[PendingDisaster] = []
## The disaster currently in its Reaction window, if any.
var pending: PendingDisaster = null
var resume: Resume = Resume.PLAY

var winner_ids: Array[int] = []
var end_reason: String = ""


func player(id: int) -> PlayerState:
	return players[id]


func current() -> PlayerState:
	return players[current_player]


func living_players() -> Array[PlayerState]:
	var out: Array[PlayerState] = []
	for p: PlayerState in players:
		if not p.eliminated:
			out.append(p)
	return out


func is_over() -> bool:
	return phase == Phase.GAME_OVER


func new_uid() -> int:
	var u: int = next_uid
	next_uid += 1
	return u


## Id of the player who may act right now, or -1 when the game is over.
func actor_id() -> int:
	if phase == Phase.GAME_OVER:
		return -1
	if phase == Phase.REACTION and pending != null:
		return pending.current_reactor()
	return current_player


func to_dict() -> Dictionary:
	var ps: Array = []
	for p: PlayerState in players:
		ps.append(p.to_dict())
	var fc: Array = []
	for f: PendingDisaster in forecasts:
		fc.append(f.to_dict())
	return {
		"seed": seed_value, "rng_state": str(rng.state), "next_uid": next_uid, "players": ps,
		"town_deck": _cards_to_array(town_deck), "town_discard": _cards_to_array(town_discard),
		"disaster_deck": _cards_to_array(disaster_deck),
		"disaster_discard": _cards_to_array(disaster_discard),
		"phase": int(phase), "current": current_player, "first": first_player,
		"round": round_number, "plays": plays_remaining, "forecasts": fc,
		"pending": pending.to_dict() if pending != null else {},
		"resume": int(resume), "winners": winner_ids.duplicate(), "end_reason": end_reason,
	}


func _cards_to_array(cards: Array[CardInstance]) -> Array:
	var out: Array = []
	for c: CardInstance in cards:
		out.append(c.to_dict())
	return out

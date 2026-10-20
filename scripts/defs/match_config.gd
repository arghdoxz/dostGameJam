class_name MatchConfig
extends Resource
## Tunable match numbers. The rule makers own these values.

@export var starting_rp: int = 20
@export var starting_hand: int = 6
@export var hand_limit: int = 7
@export var plays_per_turn: int = 1
@export var round_cap: int = 10
@export var prep_win_supplies: int = 3
@export var min_players: int = 2
@export var max_players: int = 4
## Card definition id -> copies in the Town deck.
@export var town_deck: Dictionary = {}
## Card definition id -> copies in the Disaster deck.
@export var disaster_deck: Dictionary = {}

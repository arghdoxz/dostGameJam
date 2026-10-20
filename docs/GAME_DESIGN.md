# Scratch Notes: Game Design and Rules

Status legend: **[Approved]** confirmed by the user. Rules tagged **[Proposed]** below (R1 to R5 and the open-question defaults) were **approved on 2026-10-20**; the tag is kept only to show which numbers are first-pass. Implementation assumptions are listed in [DECISIONS.md](DECISIONS.md). *tunable* means the rule makers own the number.

## 1. Premise [Approved]
2–4 players are mayors. Each protects a town from natural disasters. They build defenses, hold supplies and play disaster cards to hurt rivals. The theme is DRRMC (disaster risk reduction and management), so cards carry real DRR tips and the mechanics reward preparing early. There are no votes and no political office.

## 2. Components
- **Town deck:** resource cards, building cards, preparedness/reaction cards.
- **Disaster deck:** disaster cards. Each references a `DisasterDefinition` that holds level, damage, targeting and effects.
- **Town board per player:** RP, Town Hall, buildings with durability, Reserve, incoming Forecasts.
- **Discard piles:** one per deck, public. They reshuffle into the deck when it runs out.

## 3. Setup
1. Choose 2–4 players. Each picks a distinct territory [Approved: seat plus small trait].
2. Each town starts with 20 RP *(tunable)*, a Town Hall (no reduction) and an empty Reserve.
3. Shuffle both decks. Deal each player 6 cards from the Town deck *(tunable)*. This is the "random starting resources" [Proposed: from Town deck only].
4. A random player goes first.

### Territories [Proposed, rule makers to finalize]
Each gives -1 damage against one disaster tag and +1 damage against another.
| Territory | Resists | Weak to |
|---|---|---|
| Coastal | Drought | Storm surge, Typhoon |
| Riverside | Volcanic | Flood |
| Upland | Flood | Landslide |
| Volcanic Foothills | Landslide | Volcanic |
| Urban Lowland | Earthquake | Flood |

## 4. Turn structure [Approved: Dungeon Mayhem style; details Proposed R1, R2]
1. **Recovery:** Forecasts you cast resolve (section 6). Then start-of-turn building effects trigger. Then victory conditions are checked (section 8).
2. **Draw 1** card from either the Town deck or the Disaster deck (R1).
3. **Play:** play **1** non-resource card *(tunable)*, paying its cost by discarding resource cards from your hand. Some cards grant +1 Play. Moving a Supplies card into your Reserve is free and does not use a play.
4. **End:** discard down to the hand limit of 7 *(tunable)*. Play passes to the next living player.

A **round** is one full table rotation (R5). The game ends after round 10 *(tunable)*.

## 5. Cards [Approved: types; details Proposed]
| Type | Behavior | Lifecycle |
|---|---|---|
| Resource (Materials, Funds, Supplies) | Discarded to pay costs. Supplies may be placed in Reserve (free). Reserve Supplies can still be spent on Supplies or "any" costs [Approved 2026-10-20]. | Hand -> discard (or Reserve). |
| Building | Pay cost, placed on your board with durability and a damage reduction. | Hand -> board -> discard when destroyed. |
| Preparedness | One-shot effect: heal, repair, draw, extra play. | Hand -> discard. |
| Reaction | Played during a reaction window to reduce damage. | Hand -> discard. |
| Disaster | Pay cost, choose targets, trigger the referenced disaster. | Hand -> resolves -> discard. |

A card's static data lives in definitions. In play, it is a card instance with a unique id.

## 6. Disasters
### Severity [Approved]
| Level | Name | Base damage | Cost *(tunable)* |
|---|---|---|---|
| 1 | Minor | 2–3 | 0 |
| 2 | Severe | 4–5 | 1 |
| 3 | Catastrophic | 6 | 2 |

### Targeting [Approved]
Everyone, a specific player, or players meeting a condition (e.g. no Drainage System). A caster may not target themselves [Proposed].

### Forecast (the DRRMC warning mechanic) [Proposed R2]
- L1 resolves immediately.
- L2 and L3 become face-up **Forecasts** on each target. They resolve at the start of the caster's next turn. Targets get a full turn to build, stockpile or hold a Reaction. A forecast is public.

### Resolution sequence [Approved]
1. Reveal the disaster.
2. Identify affected players.
3. Warnings and preparation (the Forecast gap, or none for L1).
4. Reaction window: each affected player, in turn order, may play one Reaction card.
5. Calculate each town's final damage.
6. Apply damage, reduce building durability, resolve secondary effects.
7. Move on (Recovery for the next player).

### Damage formula [Proposed]
`final = max(0, base + territory_modifier - sum(applicable building reductions) - reaction reductions)`

Example [Approved]: Flood base 5, Seawall -3, Drainage System -1, final 1.

Each building that reduced damage loses 1 durability, or 2 against an L3 [Proposed R3]. At 0 durability it is destroyed and discarded. Repair (e.g. Bayanihan) restores durability, costing Supplies.

## 7. Elimination [Approved]
A town at 0 RP is eliminated. Its hand and buildings are discarded. Forecasts targeting it are removed. Forecasts it cast still resolve against surviving targets. Eliminated players cannot be targeted.

## 8. Victory [Approved: three wins; details Proposed]
1. **Last town standing.**
2. **Preparedness:** at the start of your turn you own an Evacuation Center and an Early Warning System and have 3+ Supplies in Reserve (R4).
3. **Round cap:** after round 10, highest RP wins. Ties break on number of completed objectives, then number of intact buildings, then a shared win.

If several conditions are met at once, the order above decides. If all remaining towns reach 0 RP at the same moment, the one with the highest total durability *before the killing blow* wins, else shared [Approved 2026-10-20].

**Round cap and forecasts [Approved 2026-10-20]:** when the round cap is reached, any Forecasts still outstanding resolve first (in cast order, each with its Reaction window), and the round-cap scoring above happens afterward.

## 9. Information
- **Hidden:** hands.
- **Public:** RP, buildings and durability, Reserve, Forecasts, deck sizes, discard piles, territory.
- Hot-seat play uses a "pass the device" cover screen between turns.

## 10. Legal and illegal actions
- Illegal: playing out of turn (except Reactions in a reaction window), playing without paying cost, targeting yourself or an eliminated player, a second play without a +1 Play, a Reaction outside a window, exceeding hand limit at turn end.
- The engine rejects an illegal action with a reason and leaves state unchanged.

## 11. Edge cases
- Deck empty: shuffle its discard pile in. If both are empty, the draw is skipped.
- Cannot afford a card: it cannot be played.
- Multiple Forecasts resolve in the order they were cast.
- Healing cannot exceed starting RP.
- Last player eliminated on an opponent's resolving Forecast: that decides the game immediately.
- A disaster targeting a condition that nobody meets resolves with no effect.

## 12. MVP starter content (about 60 cards) [Proposed, numbers *tunable*]
- **Disasters (7):** Typhoon, Flood, Storm Surge, Earthquake, Landslide, Volcanic Eruption, El Nino Drought.
- **Buildings (7):** Seawall, Drainage System, Retrofitted Structures, Reforestation, Ashfall Shelter, Evacuation Center, Early Warning System.
- **Preparedness / Reaction (about 8):** Pre-emptive Evacuation, Go Bag, Barangay Drill, Relief Operations (heal), Bayanihan (repair), Hazard Mapping (extra play), and others.
- **Resources:** Materials, Funds, Supplies in quantity.
- Every card has a short real-world DRR tip line.

## 13. Out of scope for the MVP
Votes and political office, board movement, networking, accounts, AI opponents, more than five territories.

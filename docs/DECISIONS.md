# Decision Log

## Approved (confirmed by the user during discovery)
| ID | Decision |
|---|---|
| D1 | Premise A: players are mayors who fortify towns and sabotage rivals with disasters. **No votes or political office.** |
| D2 | Dungeon Mayhem-style turns: short, sequential, resolve immediately. |
| D3 | Players hold and play disaster cards. A disaster card is a trigger referencing a separate `DisasterDefinition` resource. |
| D4 | DRRMC is a preparedness mechanic (warnings, preparation windows, reactions) and the theme (real-world DRR flavor and tips on cards). |
| D5 | Cards are the resource. Costs are paid by discarding resource cards. There are no resource counters. |
| D6 | HP and Resilience Points are one value (RP). Buildings give flat damage reduction and have durability. |
| D7 | Target match length 20–30 minutes. MVP includes all three wins: last town standing, highest RP at round cap, preparedness objectives. |
| D8 | Territory = seat plus one small trait (one resistance, one weakness). No board movement. |
| D9 | **Godot 4.7.2 stable** (changed from 4.5.x on 2026-10-20; it is what is installed), typed GDScript, Windows target. Tests use a small custom headless runner (`tests/run_tests.gd`), **not GUT** (changed on 2026-10-20). |
| D10 | Dungeon Mayhem, FPS Storm, Rainbow Six Extraction, Monopoly and Armello are loose inspiration only. Nothing is copied. |
| D11 | Local hot-seat MVP only. No networking, accounts, lobbies or servers in this pipeline. |
| D12 | Team: 2 devs, 2 rule makers, 1 artist. Jam length is 5 days. A separate developer owns networking later. |

## Approved on 2026-10-20 (Prompt 2 session)
The user approved R1 to R5 below and the answers to the open questions. Rule makers may still tune numbers.

## Rules R1 to R5 (approved)
| ID | Proposal | Impact if changed |
|---|---|---|
| R1 | Two shared decks (Town, Disaster). Draw 1 from either deck at turn start. | Changes the build-versus-sabotage tension and deck code. |
| R2 | L1 disasters resolve immediately. L2/L3 become face-up Forecasts that resolve at the start of the caster's next turn. | Core DRR mechanic. Changes turn flow and reaction timing. |
| R3 | A building that reduced damage loses 1 durability (2 vs. L3). It is destroyed at 0. Repair costs Supplies. | Balance of building longevity. |
| R4 | Preparedness win: at the start of your turn you own an Evacuation Center and an Early Warning System and have 3+ Supplies in Reserve. | Could end games too early or never. Needs playtesting. |
| R5 | One round = a full table rotation. Cap is 10 rounds. | Match length. |

## Approved on 2026-10-20 (Prompt 3 session)
| ID | Decision | Implemented in |
|---|---|---|
| R6 | **Final-round forecasts resolve at the round cap.** When the cap is reached, every outstanding Forecast resolves in cast order, each with its normal Reaction window, and only then does round-cap scoring run. A forecast can still eliminate towns and end the match as last standing. | `TurnSystem.run_final_resolution`, `Resume.FINAL`, `test_final_round.gd` |
| R7 | **Condition targeting stays a snapshot.** Targets are fixed at cast and re-checked at resolution only to remove towns (for example one that built the exempting building). A town is never added at resolution. | unchanged |
| R8 | **Simultaneous-elimination tiebreak uses durability before the killing blow.** | `DisasterResolver._resolve` snapshot, `test_victory.gd` |
| R9 | **Wear is unchanged:** every building with a matching reduction above 0 loses durability, even if damage was already floored to 0. | unchanged |
| UI1 | **Presentation direction:** a tabletop-RPG style table. The **map is the center**, each player's territory is a region on it, buildings are tokens, forecasts are hazard tokens, opponents sit around the table with face-down card fans, the acting player's hand fans along the bottom. The acting player is always the near seat. 2D with pseudo-3D (perspective map plane, shadows, tilt). | `scripts/ui/` |

### Resolved open questions (approved 2026-10-20)
- A disaster cannot target its own caster. **Yes, forbidden.**
- Players can react to an L1 disaster (same Reaction window). **Yes.**
- Moving a Supplies card to the Reserve is free (no play used). **Yes.**
- Territory traits: as in the GAME_DESIGN table.
- **Reserve Supplies are spendable** to pay Supplies or "any" costs (user choice 2026-10-20). They still count toward the preparedness win only while they remain in the Reserve.

### Assumptions made during implementation (not yet approved, flagged for rule makers)
- A forecast's "condition" targeting (e.g. no Drainage System) is re-checked when it resolves, so building the exempting building during the warning gap spares the town.
- A Reaction window opens for every affected player even if they hold no Reaction card (no auto-skip, so hand contents stay hidden).
- Buildings with several matching reductions use the best single value (no self-stacking). Different buildings stack.
- A building that contributed a reduction > 0 loses durability even if damage was already clamped to 0.
- Secondary "extra building damage" only happens if final damage > 0.
- Several copies of the same building may be owned.
- Forecasts cast by a player who is later eliminated still resolve, on a recovery-only turn at that player's seat (or at the round cap, R6).
- A draw effect (Early Warning Broadcast, Community Pantry) on an empty Town deck reshuffles the discard pile, which already holds the played card and its payment, so such draws normally succeed. If nothing is left the draw is skipped and a `draw_skipped` event is logged.
- Town Hall is implicit (no board object, no reduction).

## Decisions made on 2026-10-20 (Prompt 4 session)
| ID | Decision |
|---|---|
| T1 | **The tutorial is a fixed-seed hot-seat match where the learner plays both seats with stacked hands** (seed 4242, no AI, no scripted rival). It adds no rules; its text only describes implemented rules. A step can always be skipped. |
| T2 | **QA evidence comes from synthesized input through the real UI** (`tools/qa_driver.gd`). Any run using `debug_*` commands is labelled debug-assisted. |
| T3 | **The demo video is recorded with Godot Movie Maker and converted with ffmpeg**, and its one rules-bypassing shortcut is captioned. |
| T4 | No rule changed in this session. Observations that look like design questions are listed under Open questions. |

## Tunable numbers (rule makers own these)
Starting RP 20. Starting hand 6. Hand limit 7. Plays per turn 1. Disaster costs by level 0/1/2. Round cap 10. All card numbers.

## Open questions
- Final DRR tips text for each card (rule makers). Current tips are placeholders.
- All card numbers and the starter deck composition are first-pass and unbalanced.
- **Payment choice in Reactions:** the payment picker exists for plays and reactions, but the rule makers have not said whether a player may choose to spend Reserve Supplies in preference to hand cards (the picker allows it).
- **Eliminated casters' final-round forecasts:** a forecast cast by a player who was later eliminated still resolves at the cap (consistent with the existing rule that it resolves on a recovery-only turn). Confirm this is intended.
- **Match length** is unmeasured (target 20 to 30 minutes).
- **Reaction windows with no Reaction card:** a window opens (and a hand-off cover is shown) even if the reactor cannot react, to keep hands hidden. In hot-seat this costs two covers per strike. Keep, or auto-pass in 2-player games?
- **Pacing:** 1 play per turn plus a free Reserve bank. Many cards read "Not usable now" on a given turn. Needs human playtests.
- **Forecast warning gap:** a forecast resolves at the start of the caster's next turn, so the target has exactly one turn to prepare. Confirm this is the intended DRR message, or whether it should depend on the level.
- **Card art window:** the hand shows card art through a 114x66 landscape window cropped from portrait art. Decide with the artist whether to add a large card preview or change the layout.
- **Elimination wording:** the log uses ASCII placeholders ("XX", "!!"). Decide icons or words.

*Resolved on 2026-10-20: final-round forecasts (R6), condition targeting (R7), tiebreak timing (R8), over-protection wear (R9).*

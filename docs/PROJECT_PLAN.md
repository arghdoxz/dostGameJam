# Project Plan

Jam length: 5 days. Team: 2 devs, 2 rule makers, 1 artist. Networking is a separate later developer.

## Milestones
| # | Milestone | Timing | Depends on | Acceptance criteria |
|---|---|---|---|---|
| M1 | Foundation and gameplay skeleton | Day 1 | Docs | `project.godot` opens; definitions and `ContentDB` load; rules core compiles; the custom test runner (`tests/run_tests.gd`) runs headless and passes damage, deck and validation tests. |
| M2 | End-to-end local MVP | Days 2–3 | M1 | 2–4 players complete a hot-seat match from setup to game over with placeholder visuals; draw, play, pay, build, disaster, elimination, last-standing win work. |
| M3 | Complete mechanics and edge cases | Day 3 | M2 | Forecasts, reactions, durability, repair, round-cap win, preparedness win, tiebreaks and the edge cases in GAME_DESIGN section 11 all have passing tests. |
| M4 | UI/UX and artist integration | Day 4 | M2, artist files | Pass-device screen, readable hand/board, event log, art swapped in via same-named files, missing-asset fallback verified. |
| M5 | Testing, balance, release | Day 5 | M3, M4 | Seeded scripted match passes; rule makers have tuned numbers; Windows export runs on a clean machine; a playtest finishes in 20–30 minutes. |
| M6 | Online PvP | Post-jam | M5 | Owned by the networking developer. Uses the action/event boundary. Out of scope here. |
| M7 | Content and expansion | Post-jam | M5 | More territories, disasters, AI opponents, votes (only if approved). |

## Status (2026-10-20)
M1 to M4: done, with placeholder art; the artist's final assets are not in. M5: tests, a tutorial and simulated-player QA are done; **balance, human playtests, match-length measurement and the Windows export are not**. M6 and M7: not started.

Added in Prompt 4 (not in the original table): an interactive tutorial, a real-UI QA driver, a demo video and an artist handoff. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md).

## Mandatory MVP
Hot-seat 2–4 players, two decks, 5 territories, 7 disasters, 7 buildings, about 8 preparedness/reaction cards, forecasts, all three win conditions, pass-device screen, placeholders, headless tests, Windows export.

## Post-MVP ideas
Networking, AI, votes/office, sound, animations, more content, board movement.

## Work split (suggested)
- Dev A: rules core, tests, content registry.
- Dev B: scenes, UI, asset integration.
- Rule makers: card numbers, DRR tips, territory traits, playtest feedback.
- Artist: assets per [ART_PIPELINE.md](ART_PIPELINE.md).

## Risks
Five-day scope, rule churn (keep numbers in data, not code), Godot not on PATH, art arriving late (placeholders cover this).

## Future multiplayer requirements (M6, documented only; no networking exists)
The networking developer can rely on these properties of the current code; they are requirements any change must keep.
1. **Authority.** One authoritative `RulesEngine` runs on the host or server. Clients send `GameAction`s only (ids, never state) and never run `apply` on their own copy as truth. The engine is `RefCounted`, headless and seeded, so it can run in a dedicated process.
2. **Action and event contract.** All input is a serializable `GameAction` (`to_dict` / `from_dict`); all outcomes are `GameEvent`s. `RulesEngine.validate` returns a reason string the client can show. Rejections must leave state unchanged (tested).
3. **Determinism and replay.** The same seed and action list must reproduce the match (`test_full_match`). Clients may replay events to animate.
4. **Hidden information.** Opponents' hands, Reserve contents and deck order must not be sent to other players. Needed: a per-player view of `MatchState` (hand sizes only for others) and per-player event filtering (for example `card_drawn` shows the card only to the drawer). Today's UI reads full state because hot-seat shares one screen.
5. **Hot-seat versus online turn flow.** The pass-device cover disappears online. Reaction windows target a specific player: only that client may answer, and a timeout or auto-pass policy is needed (not specified yet).
6. **Disconnect and reconnect.** Needs: a snapshot of the per-player view plus the event log since a sequence number; an abandon or forfeit rule for a player who does not return (open question for the rule makers).
7. **Versioning.** Content definitions are data in `content/`; both sides must agree on a content version (hash the registry) before a match starts.
8. **UI.** `MatchController` is the boundary: a networked controller with the same signals (`events_emitted`, `state_changed`, `action_rejected`, `match_abandoned`) should drop in without changing the screens. The tutorial and QA driver use the local controller only.

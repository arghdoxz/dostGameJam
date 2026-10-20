# Scratch Notes

A competitive disaster-preparedness card game for 2–4 players, made for the DOST Game Jam.
Players are mayors who fortify their towns and sabotage rivals with disaster cards. The theme is DRRMC (disaster risk reduction and management).

- Engine: Godot 4.7.2, typed GDScript
- Target: Windows PC
- Scope: local hot-seat MVP. Online PvP is planned later and is owned by another developer.

> **Status:** playable local MVP with an in-game tutorial. A 2 to 4 player hot-seat match runs from menu to game over on a tabletop-style board with placeholder art. Played through the real UI by a simulated first-time player (Claude, synthesized input; see [docs/qa/PLAYTEST_REPORT.md](docs/qa/PLAYTEST_REPORT.md)); **not yet played by humans**, not balanced, not final. See [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md). Artists: start at [docs/artist/ARTIST_HANDOFF.md](docs/artist/ARTIST_HANDOFF.md).

## Setup
1. Install Godot 4.7.2 stable and put `godot` on your PATH.
2. Open the folder in Godot, or run `godot --path .`. The first open imports the project.

## Learn to play
Press **How to Play (Tutorial)** on the main menu: a guided hot-seat match where you play both seats (Ana and Ben) with stacked hands. Skip step, Restart and Exit tutorial are always available.

## Demo
[docs/demo/scratch-notes-development-demo.mp4](docs/demo/scratch-notes-development-demo.mp4) is a 3-minute recording of the real game (tutorial, then a normal match with one captioned debug-assisted shortcut). See [docs/demo/DEMO_NOTES.md](docs/demo/DEMO_NOTES.md).

## Tests
```
godot --headless --path . --import                       # after adding class_name scripts
godot --headless --path . -s res://tests/run_tests.gd    # 121 unit and integration tests
godot --headless --path . -s res://tests/smoke_ui.gd     # UI smoke test (169 checks)
godot --path . -s res://tools/qa_driver.gd -- --script docs/qa/scripts/tutorial_full_run.txt --shots <folder>   # real-click replay (needs a window)
```
Details: [docs/TESTING.md](docs/TESTING.md).

## Documentation
| Doc | Purpose |
|---|---|
| [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) | Rules, cards, starter content |
| [docs/TECHNICAL_ARCHITECTURE.md](docs/TECHNICAL_ARCHITECTURE.md) | Code structure, repo layout, naming |
| [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md) | Milestones and acceptance criteria |
| [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) | What is built |
| [docs/TESTING.md](docs/TESTING.md) | Test strategy |
| [docs/ART_PIPELINE.md](docs/ART_PIPELINE.md) | Asset naming and replacement rules |
| [docs/artist/ARTIST_HANDOFF.md](docs/artist/ARTIST_HANDOFF.md) | What the artist needs: slots, on-screen sizes, screenshots |
| [docs/qa/PLAYTEST_REPORT.md](docs/qa/PLAYTEST_REPORT.md) | Simulated-player QA: method, scenarios, limits |
| [docs/qa/BUGS_AND_FIXES.md](docs/qa/BUGS_AND_FIXES.md), [docs/qa/SCREENSHOT_INDEX.md](docs/qa/SCREENSHOT_INDEX.md) | Bugs found and fixed; every screenshot explained |
| [docs/demo/](docs/demo/) | Demo video, script and notes |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Approved and proposed decisions |
| [docs/AGENT_HANDOFF.md](docs/AGENT_HANDOFF.md) | Start here for the next Claude Code session |

## Team
2 developers, 2 rule makers, 1 artist. A separate developer handles networking later.

## License
See [LICENSE](LICENSE).

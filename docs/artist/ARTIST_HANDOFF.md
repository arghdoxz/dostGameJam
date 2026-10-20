# Artist Handoff

For the artist. Everything on screen today is placeholder: flat colours, generated shapes and the engine's default font. This page says what the game shows, where each asset appears, how big it is on screen, and what is missing. File rules (names, formats, how to replace art) live in [../ART_PIPELINE.md](../ART_PIPELINE.md) and the complete slot list is [../../assets/ASSET_MANIFEST.md](../../assets/ASSET_MANIFEST.md) (72 slots, all `placeholder`). This page does not repeat them.

Screenshots are real captures of the current build in `docs/qa/screenshots/regression-final/` (1600x900) and `docs/qa/screenshots/small-windows/`.

## The game in one paragraph
Mayors of small towns build defences and send disasters at each other with cards. A table view: a map in the middle with one region per player, each player's seat card around it, two decks in the bottom corners, and your hand fanned along the bottom. You must be able to read, at a glance: whose turn it is, each town's health (RP), what is built where, which disaster is coming, and what a card does.

## Screens and where art appears
| Screen | Screenshot | Art that shows |
|---|---|---|
| Main menu, setup, results | `regression-final/01-main-menu.png`, `../qa/screenshots/06-setup-default.png`, `../qa/screenshots/24-normal-results-screen.png` | `background_menu` (full screen, behind everything) |
| Match table | `regression-final/02-tutorial-02-board.png` | `background_table`, `background_map_board`, five `territory_*` tiles, building tokens, hazard tokens, seat portraits, deck backs, hand cards |
| Reaction window | `regression-final/02-tutorial-16b-reaction-window.png` | the same, plus the disaster panel (text only) and red outline on the struck region |
| Forecast on the map | `regression-final/02-tutorial-22-summary-forecast.png` | `hazard_*` token inside a dark label on the target's region |
| Big hand | `small-windows/1280-06-big-hand.png` | card faces at their smallest |
| 4 players | `../qa/screenshots/31-four-player-initial-board.png` | seats on left, top, right; regions placed toward each seat |

## Slots by priority, with the size they are drawn at
"On screen" is the size in a 1600x900 window; the window scales everything, so keep art legible at roughly two thirds of this (1280x720 and 1024x768 are supported).

| Priority | Slot(s) | Manifest size | On screen | Notes |
|---|---|---|---|---|
| 1 | `cards/card_<id>.png` (25 cards) | 750x1050 | **a 114x66 window**, centre-cropped | See "Card art caveat" below. This is the largest piece of work. |
| 1 | `ui/ui_card_frame_<type>.png` (5 types) | 750x1050, transparent | 126x176 (the whole card) | Drawn over the card, stretched to fit. The name sits at the top, the type and cost at the bottom; keep those areas readable. |
| 1 | `territories/territory_<id>.png` (5) | 512x512, transparent | about 230x130, perspective-squashed | Tile for each town's region on the map. Text (town name, notes) is drawn on top. |
| 1 | `backgrounds/background_map_board.png` | 1600x1000 | about 750x325, perspective trapezoid | The plane the regions sit on. |
| 2 | `buildings/building_<id>.png` (7 + `town_hall`) | 512x512, transparent | **48x48** | Standing token with a durability number under it. Needs a strong silhouette at this size. |
| 2 | `hazards/hazard_<id>.png` (7) | 256x256, transparent | **34x34** | Beside the text "FORECAST Typhoon L2". |
| 2 | `ui/ui_card_back_town.png`, `..._disaster.png` | 750x1050, transparent | 64 px wide on the decks; 34x48 in opponents' fans | The two decks must be told apart even when tiny and dim. |
| 2 | `portraits/portrait_mayor_1..4.png` | 256x256 | 64x64, cropped to fill | Seat cards. |
| 3 | `backgrounds/background_menu.png`, `background_table.png` | 1920x1080 | full screen | The table background is partly covered; keep it quiet so cards read. |
| 3 | Fonts `font_body`, `font_heading` | TTF/OTF | body about 12 to 14 px, hand card names 12 px | Must stay legible at 12 px. The game has small text everywhere. |
| not wired yet | `icons/icon_*.png` (12), `ui/ui_seat_mat.png` | 128x128 / 600x200 | not drawn | **No screen uses these slots yet.** Art placed there will not appear until a developer wires it in (RP, durability, reserve, resources, forecast, level, eliminated, turn marker, seat background). Tell the developer which you want first. |

## Card art caveat
A card in your hand shows its illustration in a 114x66 landscape window (`STRETCH_KEEP_ASPECT_COVERED`), cropped from the centre of the portrait 750x1050 file. About the middle 750x434 strip of the illustration is what players see. There is no zoomed card view yet, so the rest is hidden. Either compose the art so the key subject sits in the central band, or ask a developer to change the card layout (`scripts/ui/card_view.gd`) and add a large card preview. This is an open decision, not a bug.

## Readability constraints observed in play
- Card text (name, cost) is 11 to 12 px. Long costs wrap, such as "Cost: 2 funds, 2 materials". Avoid busy art behind the lower third of the card.
- Town regions carry text on top (name, "STRIKE: 3 damage expected", building tokens). Keep territory tiles low-contrast in the middle.
- A red outline marks the targeted region and a yellow outline marks the acting player's seat. Do not use red or yellow as the dominant colour of regions or seats.
- Disabled cards are dimmed and say "Not usable now"; art must still be recognisable when dimmed.
- Elimination currently shows the region greyed with the word ELIMINATED. A final design may replace it with `icon_eliminated` once wired.

## Interaction states to design for
Cards: normal, hover (lifted), selected (lifted more, outlined), unusable (dimmed). Seats: normal, acting (yellow), can be targeted (red label), target chosen, reacting, eliminated. Buildings: durability shown as "2/3"; a building that was just hit pulses. Buttons and panels come from the theme (`ui/theme/main_theme.tres`); see ART_PIPELINE.

## Other screens an artist may want to restyle
The tutorial coach (a dark blue panel at the top right with a yellow border and pulsing yellow outlines on the thing being explained) is built in code in `scripts/tutorial/tutorial_coach.gd`. Colours are constants at the top. Captures: `regression-final/02-tutorial-*.png`.

## Layout numbers an artist can change
`MapView.REGION_SLOTS` and `FAR_WIDTH_RATIO` (where each region sits on the map plane) are documented in ART_PIPELINE. Card layout is in `scripts/ui/card_view.gd` (`CARD_SIZE` 126x176, art rectangle, label positions).

## What to ask the developers for
1. A large card preview on hover or select (so full 750x1050 art is seen).
2. Wiring for icons (RP, durability, reserve, resources) and the seat mat.
3. Any layout change the final art needs; keep screenshots with the request.

# Art Pipeline

See also [artist/ARTIST_HANDOFF.md](artist/ARTIST_HANDOFF.md) (what is on screen, at what size, with screenshots).

The artist supplies final illustrations, tokens, map art, icons, backgrounds, UI designs and typography. Developers build the functional layout with replaceable placeholders and never produce final art. **Dropping a correctly named file into the right folder replaces its placeholder with no code change.**

The full list of slots (72 today) with path, size, transparency, status and purpose is [assets/ASSET_MANIFEST.md](../assets/ASSET_MANIFEST.md). It is generated; do not edit it by hand:
```
godot --headless --path . -s res://tools/generate_asset_manifest.gd
```
A row flips from `placeholder` to `final` once its file exists.

## Presentation direction
A 2D tabletop that reads like a tabletop RPG session, with 3D-looking elements. The **map is the center of the table**; every player's territory is a region on it, buildings stand on regions as tokens, forecasts appear as hazard tokens, opponents sit around the table with face-down card fans, and the acting player's hand fans along the bottom. The pseudo-3D comes from a perspective-squashed map plane, standing tokens with drop shadows, tilted fanned cards and shadows. There are no 3D nodes.

## Hard technical requirements
These are what the game needs. Everything else is the artist's choice.

| Rule | Detail |
|---|---|
| Location and name | Exactly `assets/art/<category>/<prefix>_<id>.png`, `snake_case`, no spaces. The manifest gives each full path. |
| Format | PNG for all art. Fonts: TTF or OTF. |
| Aspect ratio | Must match the manifest size's aspect ratio. Any pixel size with that ratio works (layouts scale art to fit). |
| Transparency | Required for rows marked `Alpha: yes` (tokens, region tiles, hazards, icons, card frames). |
| Fonts | `assets/fonts/font_body.ttf` (or `.otf`) and `assets/fonts/font_heading.ttf` (or `.otf`). Both optional; each falls back to the engine default. |

| Category (folder) | Prefix | Manifest size | Purpose |
|---|---|---|---|
| `cards` | `card_` | 750x1050 | Card illustration (ids like `bld_seawall`, `disaster_flood`, `res_funds`) |
| `buildings` | `building_` | 512x512 | Standing building token on the map, plus `town_hall` |
| `territories` | `territory_` | 512x512 | Region tile on the map (`terr_coastal`, ...) |
| `hazards` | `hazard_` | 256x256 | Forecast token (`disaster_flood`, ...) |
| `portraits` | `portrait_` | 256x256 | Mayor portraits (`mayor_1` to `mayor_4`) |
| `icons` | `icon_` | 128x128 | RP, durability, reserve, resources, forecast, levels, eliminated, turn marker |
| `backgrounds` | `background_` | 1920x1080 | `menu`, `table`, and `map_board` (1600x1000, the map plane) |
| `ui` | `ui_` | 750x1050 unless listed | Card backs, per-type card frames (transparent overlays), `seat_mat` (600x200) |

## Artist's choice (recommendations only)
Style, palette, frame design, typography choice, icon style, how the perspective is drawn. Recommendations: sRGB; art that survives being scaled down to about 126x176 px (a card in hand) and 48x48 px (a building token); leave the lower third of card art calmer because the name and cost text sit on the card.

## Layout data the artist may adjust
- **Map regions:** `MapView.REGION_SLOTS` in `scripts/ui/map_view.gd` gives each seat's region as normalized plane coordinates `[center_u, center_v, half_width, half_height]`, and `FAR_WIDTH_RATIO` sets how much narrower the far edge is. A final map only needs these numbers moved to match its landmarks.
- **Card layout:** `CardView` (`scripts/ui/card_view.gd`) positions art, name, type, cost and the frame overlay. A frame at `ui/ui_card_frame_<type>.png` is drawn over the card; the placeholder is a thin outline.
- **Theme:** `ui/theme/main_theme.tres` holds the panel, button, focus and progress styles. Replace its StyleBoxes (or add textures to them) to restyle every screen. `UiTheme` (`scripts/ui/ui_theme.gd`) loads the fonts and defines the `HeadingLabel` and `SmallLabel` variants.

## Placeholders and fallbacks
- `AssetLibrary` (`scripts/ui/asset_library.gd`) is the only place that builds asset paths; `test_game_scripts_do_not_hardcode_asset_paths` fails if another script contains an `res://assets/` path.
- A missing file never crashes: a generated placeholder with the **correct aspect ratio** is used (circle for tokens, diamond for hazards, ellipse for regions, parchment grid for the map, outline for card frames). One summary warning is logged on the first miss instead of one per file. `AssetLibrary.missing_paths()` lists what is still missing.
- Placeholders are tiny and generated in memory; `assets/placeholders/` is unused.

## Import settings
Godot's default PNG import is fine. For UI art: disable mipmaps; keep filter on linear; compress as Lossless (or VRAM compressed if file size matters). Leave "Fix Alpha Border" on for transparent tokens so edges do not show halos. Fonts: import as dynamic fonts with antialiasing on.

## Replacement steps
1. Export the file with the exact name and an aspect-correct size.
2. Drop it into the matching `assets/art/<category>/` folder (or `assets/fonts/` for fonts).
3. Let Godot reimport (focus the editor), run the game, confirm the placeholder is gone.
4. Run `godot --headless --path . -s res://tools/generate_asset_manifest.gd` and commit the updated manifest.

## Checking the layout
`godot --path . -s res://tools/capture_screens.gd -- <folder>` opens a real window and saves PNGs of the menu, setup, the 2 and 4 player boards, a selected card, a disaster reaction, the resolution summary, the payment picker and the results. Needs a display (not `--headless`).

# Conquest

A turn-based world-conquest strategy game built with Godot 4.6 and GDScript. Command armies across land, sea, and air to capture cities and defeat your AI opponent.

- **Android first** with touch-friendly UI
- **Web export** compatible (gl_compatibility renderer)
- **Deterministic** core simulation with seeded RNG
- **Data-driven** units and rules via JSON

## Quick Start

1. Open the project folder in **Godot 4.6** Editor
2. Press **F5** to run (Main.tscn is the main scene)
3. Click **New Game**, choose map type, AI difficulty, and seed
4. Play: tap tiles to select units, use the action bar to move/attack/build

## How to Play

- **Start** with 1 home city and 1 infantry unit
- **Explore** the map under fog-of-war
- **Capture** neutral and enemy cities by moving Infantry onto them
- **Build** units in your cities (cities adjacent to sea are Ports that can build ships)
- **Win** when you control 60% of all cities or capture all enemy cities
- **Lose** when you have 0 cities and 0 units

### Units

| Unit         | Domain | MP | HP | ATK | DEF | Special            |
|--------------|--------|----|----|-----|-----|--------------------|
| Infantry     | LAND   |  1 | 10 |   4 |   3 | Captures cities    |
| Airborne     | AIR    |  6 |  8 |   3 |   2 | Drop to Infantry   |
| Interceptor  | AIR    | 10 |  6 |   5 |   3 | Air superiority +2 |
| Bomber       | AIR    |  6 |  6 |   6 |   1 | AoE radius 2       |
| LandingCraft | SEA    |  4 | 14 |   2 |   2 | Transport (cap 4)  |
| Frigate      | SEA    |  6 | 16 |   5 |   3 | Naval combat       |

### Controls

- **Tap** a tile to select (unit, city, or terrain info)
- **Drag** to pan the map
- **Pinch** (touch) or **scroll wheel** (mouse) to zoom
- Action bar buttons: **Move**, **Attack**, **Drop**, **Load/Unload**, **Sleep**, **End Turn**, **Save**

## Exporting

### Android APK

Prerequisites: Godot 4.6 with Android export templates, Android SDK configured, keystore set up.

```bash
./scripts/export_android_apk.sh
# Or: GODOT_BIN=/path/to/godot ./scripts/export_android_apk.sh
```

Output: `build/android/conquest.apk`

### Web

Prerequisites: Godot 4.6 with Web export templates.

```bash
./scripts/export_web.sh
cd build/web && python3 -m http.server 8080
```

Output: `build/web/conquest.html`

## Changing the RNG Seed

In the **New Game** screen, enter any text or number in the **Seed** field. The same seed always produces the same procedural map. Leave blank for a random seed each game.

The seed is saved with game state, so loading a save preserves determinism.

## Architecture

```
project.godot                    Godot project config (gl_compatibility renderer)
scenes/
  Main.tscn                      Entry point, scene switcher
  screens/
    MenuScreen.tscn              Main menu
    NewGameScreen.tscn           New game options
    GameScreen.tscn              Main gameplay screen
    LoadScreen.tscn              Load saved games
scripts/
  core/
    GameState.gd                 Authoritative state (map, cities, units, RNG)
    TurnSystem.gd                Start/end turn, production ticks, repair
    FogSystem.gd                 Per-player fog-of-war (UNSEEN/SEEN/VISIBLE)
    CombatSystem.gd              Deterministic combat + bomber AoE
    MapGenerator.gd              Procedural map gen + JSON map loading
    Pathfinding.gd               A* pathfinding + reachability
    SaveSystem.gd                Save/load with schema versioning
  ui/
    Main.gd                      Scene switcher logic
    GameScreen.gd                Game orchestrator (connects all systems)
    MenuScreen.gd                Main menu UI
    NewGameScreen.gd             New game setup UI
    LoadScreen.gd                Save slot browser
    ActionBar.gd                 Contextual action buttons
    InspectPanel.gd              Tile/unit/city info display
    CityPanel.gd                 City production chooser
    InputController.gd           Touch/mouse input -> simulation intents
  render/
    GridRenderer.gd              Tile drawing, fog overlay, unit sprites
  ai/
    AIController.gd              Non-cheating AI (Easy/Normal difficulty)
data/
  units.json                     Unit stats and abilities
  rules.json                     Victory %, repair, terrain bonuses
  maps/
    sample_map.json              Hand-crafted 30x30 two-continent map
export_presets.cfg               Android APK + Web export presets
scripts/
  export_android_apk.sh          Headless APK export
  export_web.sh                  Headless web export
```

### Design Principles

- **Simulation separate from rendering**: Core scripts (GameState, TurnSystem, etc.) are `RefCounted` classes with no Godot node dependencies
- **Deterministic**: Seeded RNG, no randomness outside the seed
- **Data-driven**: Unit stats and rules loaded from JSON at runtime
- **Touch-first**: Large buttons, tap-to-select, drag-to-pan, pinch-to-zoom

## What's Next

- Add more unit types: Submarine, Aircraft Carrier, Artillery
- Smarter AI with strategic planning and multi-turn lookahead
- Better procedural map generation (Perlin noise, island chains)
- Pass-and-play local multiplayer
- Sound effects and minimal music
- Map editor
- Campaign mode with linked scenarios

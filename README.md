# Lab

## Overview
Lab is a top-down, grid-based puzzle platformer built in Godot Engine 4.4. Players guide a character through a series of levels by strategically moving, jumping, and interacting with switches to overcome obstacles.

## Gameplay Mechanics
- **Limited Moves & Jumps**: Each level sets a maximum number of moves and jumps. The UI displays remaining counts.
- **Jumping Holes**: Hold the **Space** key and press a direction to jump over holes.
- **Switches & Connections**: Activate switches that toggle tiles or objects elsewhere in the level via switch connections.
- **Trail Markers**: Visual indicators show the player's path through the grid.
- **Rewind**: If you run out of moves on Level 1, hold **R** and press **Left** to rewind and retry.

## Project Structure
```
├── project.godot             # Godot project settings (Godot 4.4)
├── menu.tscn / menu.gd       # Main menu scene and logic
├── play_game.tscn / play_game.gd # Gameplay entry point scene and logic
├── player.tscn / player.gd   # Player node & movement script
├── game_manager.gd          # Global singleton for move/jump UI and game state
├── level_manager.gd         # Global singleton for loading level JSON data
├── grid_manager.gd          # Manages grid, tile instantiation, and trail markers
├── switch.gd & switch_connection.gd # Switch logic and connection behaviors
├── trail_marker.gd          # Marks player's movement path on the grid
├── game_camera.gd           # Follows the player during gameplay
├── level_designer.tscn / level_designer.gd # Editor for building custom levels
├── tileset.tres             # Tile set resource for grid graphics
├── data/                    # JSON files defining level layouts and parameters
│   ├── level1.json
│   ├── level2.json
│   └── level3.json
└── sprites/                 # Imported assets and icons
```

## Controls
- Move: **W/A/S/D** or **Arrow Keys**
- Jump: **Space**
- Rewind (Level 1 only): **R** + **Left**
- Escape: Return to Main Menu / Pause

## Dependencies & Requirements
- Godot Engine **4.4**
- No external plugins required

## Getting Started
1. Clone or open this repository in Godot 4.4.
2. Ensure `project.godot` points to `menu.tscn` as the main scene.
3. Run the project. Navigate the menu to start playing.

## For AI Agents & Developers
- **Singletons**: `GameManager` and `LevelManager` are autoloaded and accessible via `GameManager` / `LevelManager`.
- **Level Data**: Located in `data/levelX.json`; use `LevelManager.load_level(level_number)` to fetch a dictionary of tile data, switches, and parameters.
- **Extending Levels**: Use `level_designer.tscn` to create and export new levels as JSON.
- **Tile Types**: See `grid_manager.gd` for tile-type mapping (e.g., floor, wall, hole).

Happy puzzling!

## Refactor Overview (Post-Plan)

The codebase has been refactored according to the plan laid out in `plan.md`:

*   **HUD Scene**: UI elements (move/jump counts, tooltips) previously created in `game_manager.gd` are now in a dedicated `res://ui/HUD.tscn` scene, instanced by `GameManager`.
*   **SwitchConnection Scene**: The visual line connecting switches to targets is now its own scene (`res://scenes/SwitchConnection.tscn`) and script (`SwitchConnection.gd`), replacing the nested class in `switch.gd`.
*   **Resource-Based Levels**: Level data is now defined in `LevelData` resource files (`.tres`) under `res://data/`, loaded by `LevelManager` using `ResourceLoader`. (JSON files are no longer used; corresponding `.tres` files must be created).
*   **Command Pattern**: Player movement (`move`, `jump`) is handled by `MoveCommand` and `JumpCommand` objects (`res://scripts/commands/`). `Player.gd` executes these commands and uses them for undo/redo history.
*   **InputHandler**: Input detection (`W/A/S/D`, Space, R) is centralized in `res://ui/InputHandler.gd`. This script emits signals (`move_requested`, `jump_requested`, etc.) which are connected to handler methods in `Player.gd`.
*   **Code Quality**: Static typing has been added throughout the codebase, debug `print` statements removed, and duplicated level-loading logic in `GridManager` deduplicated into `_setup_level`.

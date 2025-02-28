# CLAUDE.md - Guidelines for Lab Project

## Project Information
- Godot 4.3 game project
- Grid-based puzzle game with player movement, switches, and targets
- Main scene: `menu.tscn`

## Commands
- Run project: Open in Godot Editor and press F5 or click "Play" button
- Export: Use Godot's export system for specific platforms
- Test: No automated tests; manual playtesting required

## Code Style
- Use snake_case for functions, variables, and file names
- Use PascalCase for class names (class_name)
- Use UPPER_CASE for constants
- Place signals at the top of scripts after class declaration
- Use type hints for variables and function parameters/returns
- Use tabs for indentation
- Group related functions together
- Keep function names descriptive using verb_noun pattern
- Organize scripts with clear sections: variables, signals, lifecycle methods, public methods, private methods

## Project Structure
- .gd files for scripts, .tscn for scenes
- Store level data in JSON format in data/ directory
- Store sprites in sprites/ directory
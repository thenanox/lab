extends Node
class_name LevelManager

class Switch:
	var position: Vector2i  # Switch position
	var target_pos: Vector2i  # Position of tile to toggle
	var is_pressed := false
	var persistent := true  # If true, state remains after rewind
	
	func _init(pos: Vector2i, target: Vector2i):
		position = pos
		target_pos = target

const LEVELS = {
	1: {  # Tutorial level
		"tile_data": [
			# Walls
			[0, 0, 0, 0],  # Wall
			[1, 0, 0, 0],  # Wall
			[2, 0, 0, 0],  # Wall
			[3, 0, 0, 0],  # Wall
			[4, 0, 0, 0],  # Wall
			[5, 0, 0, 0],  # Wall
			[0, 1, 0, 0],  # Wall
			[0, 2, 0, 0],  # Wall
			[0, 3, 0, 0],  # Wall
			[5, 1, 0, 0],  # Wall
			[5, 2, 0, 0],  # Wall
			[5, 3, 0, 0],  # Wall
			[1, 3, 0, 0],  # Wall
			[2, 3, 0, 0],  # Wall
			[3, 3, 0, 0],  # Wall
			[4, 3, 0, 0],  # Wall
			[5, 3, 0, 0],  # Wall
			
			# Floor
			[1, 1, 1, 0],  # Floor
			[2, 1, 1, 0],  # Floor
			[3, 1, 1, 0],  # Floor
			[4, 1, 1, 0],  # Floor
			[1, 2, 1, 0],  # Floor
			[2, 2, 1, 0],  # Floor
			[3, 2, 1, 0],  # Floor
			[4, 2, 1, 0],  # Floor
			
			# Hole and Ladder
			[2, 1, 2, 0],  # Hole
			[4, 1, 3, 0],  # Ladder (unreachable without jump)
		],
		"player_start": Vector2i(1, 1),  # Start at the left side
		"max_moves": 3,
		"max_jumps": 1
	},
	2: {  # Switch and rewind puzzle level
		"tile_data": [
			# Walls
			[0, 0, 0, 0],  # Wall
			[1, 0, 0, 0],  # Wall
			[2, 0, 0, 0],  # Wall
			[3, 0, 0, 0],  # Wall
			[4, 0, 0, 0],  # Wall
			[5, 0, 0, 0],  # Wall
			[6, 0, 0, 0],  # Wall
			[7, 0, 0, 0],  # Wall
			[0, 1, 0, 0],  # Wall
			[0, 2, 0, 0],  # Wall
			[0, 3, 0, 0],  # Wall
			[7, 1, 0, 0],  # Wall
			[7, 2, 0, 0],  # Wall
			[7, 3, 0, 0],  # Wall
			[1, 3, 0, 0],  # Wall
			[2, 3, 0, 0],  # Wall
			[3, 3, 0, 0],  # Wall
			[4, 3, 0, 0],  # Wall
			[5, 3, 0, 0],  # Wall
			[6, 3, 0, 0],  # Wall
			[7, 3, 0, 0],  # Wall
			
			# Floor
			[1, 1, 1, 0],  # Floor
			[2, 1, 1, 0],  # Floor
			[3, 1, 1, 0],  # Floor
			[4, 1, 1, 0],  # Floor
			[5, 1, 1, 0],  # Floor
			[6, 1, 1, 0],  # Floor
			[1, 2, 1, 0],  # Floor
			[2, 2, 1, 0],  # Floor
			[3, 2, 1, 0],  # Floor
			[4, 2, 1, 0],  # Floor
			[5, 2, 1, 0],  # Floor
			[6, 2, 1, 0],  # Floor
			
			# Switches and walls to toggle
			[2, 1, 4, 0],  # Switch 1
			[4, 1, 0, 0],  # Wall 1
			[5, 1, 4, 0],  # Switch 2
			[6, 1, 0, 0],  # Wall 2
			[6, 2, 3, 0],  # Ladder
		],
		"switches": [
			{"pos": Vector2i(2, 1), "target": Vector2i(4, 1)},  # Switch 1 -> Wall 1
			{"pos": Vector2i(5, 1), "target": Vector2i(3, 1)}   # Switch 2 -> Wall 2
		],
		"player_start": Vector2i(1, 1),
		"max_moves": 5,
		"max_jumps": 0
	},
		3: {  # Jump tutorial level
		"tile_data": [
			# Walls
			[0, 0, 0, 0],  # Wall
			[1, 0, 0, 0],  # Wall
			[2, 0, 0, 0],  # Wall
			[3, 0, 0, 0],  # Wall
			[4, 0, 0, 0],  # Wall
			[5, 0, 0, 0],  # Wall
			[0, 1, 0, 0],  # Wall
			[0, 2, 0, 0],  # Wall
			[0, 3, 0, 0],  # Wall
			[0, 4, 0, 0],  # Wall
			[0, 5, 0, 0],  # Wall
			[5, 1, 0, 0],  # Wall
			[5, 2, 0, 0],  # Wall
			[5, 3, 0, 0],  # Wall
			[5, 4, 0, 0],  # Wall
			[5, 5, 0, 0],  # Wall
			[1, 5, 0, 0],  # Wall
			[2, 5, 0, 0],  # Wall
			[3, 5, 0, 0],  # Wall
			[4, 5, 0, 0],  # Wall
			
			# Floors
			[1, 1, 1, 0],  # Floor
			[2, 1, 1, 0],  # Floor
			[3, 1, 1, 0],  # Floor
			[4, 1, 1, 0],  # Floor
			[1, 2, 1, 0],  # Floor
			[2, 2, 1, 0],  # Floor
			[3, 2, 1, 0],  # Floor
			[4, 2, 1, 0],  # Floor
			[1, 3, 1, 0],  # Floor
			[2, 3, 1, 0],  # Floor
			[3, 3, 1, 0],  # Floor
			[4, 3, 1, 0],  # Floor
			[1, 4, 1, 0],  # Floor
			[2, 4, 1, 0],  # Floor
			[3, 4, 1, 0],  # Floor
			[4, 4, 1, 0],  # Floor

			# Hole and Ladder
			[2, 2, 2, 0],  # Hole
			[2, 3, 2, 0],  # Hole
			[4, 1, 3, 0],  # Ladder (unreachable without jump)
		],
		"player_start": Vector2i(1, 3),
		"max_moves": 3,
		"max_jumps": 2
	},
}

var current_level := 1

func load_level(level_num: int) -> Dictionary:
	if !LEVELS.has(level_num):
		return {}
		
	return LEVELS[level_num]

func next_level() -> Dictionary:
	current_level += 1
	return load_level(current_level) 

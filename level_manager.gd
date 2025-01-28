extends Node
class_name LevelManager

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
	# Add more levels as needed
}

var current_level := 1

func load_level(level_num: int) -> Dictionary:
	if !LEVELS.has(level_num):
		push_error("Level %d does not exist!" % level_num)
		return {}
		
	return LEVELS[level_num]

func next_level() -> Dictionary:
	current_level += 1
	return load_level(current_level) 

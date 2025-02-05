extends Node

var current_level := 1
var levels: Dictionary = {}
const LEVELS_DIRECTORY = "res://data/"

class LevelData:
	var id: int = 0
	var tile_data: Array[Array] = []
	var player_start: Vector2i = Vector2i.ZERO
	var max_moves: int = 0
	var max_jumps: int = 0
	var switches: Array[Dictionary] = []
	
	static func from_json(json_data: Dictionary) -> LevelData:
		var level = LevelData.new()
		
		# Ensure integer conversion
		level.id = int(json_data.get("id", 0))
		level.max_moves = int(json_data.get("max_moves", 0))
		level.max_jumps = int(json_data.get("max_jumps", 0))
		
		# Convert tile_data to ensure integer values
		level.tile_data.clear()
		for tile in json_data.get("tile_data", []):
			var converted_tile: Array = [
				int(tile[0]),   # x
				int(tile[1]),   # y
				int(tile[2])    # type
			]
			level.tile_data.append(converted_tile)
		
		# Convert player_start
		var start = json_data.get("player_start", [0, 0])
		level.player_start = Vector2i(int(start[0]), int(start[1]))
		
		# Convert switches
		level.switches.clear()
		for switch in json_data.get("switches", []):
			var converted_switch: Dictionary = {
				"pos": [int(switch["pos"][0]), int(switch["pos"][1])],
				"targets": [],
				"types": []
			}
			
			# Convert targets
			for target in switch.get("targets", []):
				converted_switch["targets"].append([int(target[0]), int(target[1])])
			
			# Convert types
			for type in switch.get("types", []):
				converted_switch["types"].append(int(type))
			
			level.switches.append(converted_switch)
		
		return level

func get_available_levels() -> Array[String]:
	var levels_list: Array[String] = []
	var dir = DirAccess.open(LEVELS_DIRECTORY)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				levels_list.append(file_name)
			file_name = dir.get_next()
	return levels_list

func load_level(level_num: int) -> Dictionary:
	# Construct the file path
	var file_path = LEVELS_DIRECTORY + "level" + str(level_num) + ".json"
	
	# Check if file exists
	if not FileAccess.file_exists(file_path):
		push_error("Level file not found: " + file_path)
		return {}
	
	# Open and read the file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open level file: " + file_path)
		return {}
	
	# Parse JSON
	var json_string = file.get_as_text()
	var json_data = JSON.parse_string(json_string)
	
	if not json_data:
		push_error("Failed to parse JSON in level file: " + file_path)
		return {}
	
	# Convert to LevelData
	var processed_level = LevelData.from_json(json_data)
	
	# Convert LevelData back to a dictionary for compatibility
	return {
		"id": processed_level.id,
		"tile_data": processed_level.tile_data,
		"player_start": [processed_level.player_start.x, processed_level.player_start.y],
		"max_moves": processed_level.max_moves,
		"max_jumps": processed_level.max_jumps,
		"switches": processed_level.switches
	}

func next_level() -> Dictionary:
	current_level += 1
	return load_level(current_level) 

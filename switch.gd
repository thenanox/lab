class_name Switch
extends Resource

var position: Vector2i  # Switch position
var target_positions: Array[Vector2i]  # Multiple target positions
var is_pressed := false
var persistent := true  # If true, state remains after rewind
var toggle_types: Array[int]  # Types of tiles to toggle (WALL, FLOOR, etc.)

func _init(pos: Vector2i, targets: Array, types: Array = []):
	position = pos
	
	# Convert input targets to typed Array[Vector2i]
	target_positions = []
	for target in targets:
		target_positions.append(Vector2i(target[0], target[1]) if target is Array else target)
	
	# Convert input types to typed Array[int]
	toggle_types = []
	for type in types:
		toggle_types.append(int(type))
	
	# If no types specified, default to alternating wall/floor
	if toggle_types.is_empty():
		toggle_types = [GridManager.WALL_TYPE, GridManager.FLOOR_TYPE]

# Method to get the next tile type in the toggle sequence
func get_next_tile_type(current_type: int) -> int:
	var type_index = toggle_types.find(current_type)
	if type_index == -1:
		return toggle_types[0]  # Default to first type if not found
	
	# Cycle to the next type, wrapping around
	return toggle_types[(type_index + 1) % toggle_types.size()]

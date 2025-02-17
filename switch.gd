class_name Switch
extends Resource

const LINE_WIDTH = 2.0
const PULSE_DURATION = 1.0
const PULSE_INTENSITY = 0.3

var position: Vector2i  # Switch position
var target_positions: Array[Vector2i]  # Multiple target positions
var is_pressed := false
var persistent := true  # If true, state remains after rewind
var toggle_types: Array[int]  # Types of tiles to toggle (WALL, FLOOR, etc.)
var color: Color = Color(1, 1, 0)  # Default yellow, but can be changed
var current_sequence_index: int = -1  # Track position in sequence, -1 means not started

class Connection extends Node2D:
	var start_pos: Vector2
	var end_pos: Vector2
	var is_active: bool = false
	var color: Color
	const LINE_WIDTH = 4.0  # Thicker line
	const PULSE_DURATION = 1.5  # Slower pulse
	const PULSE_INTENSITY = 0.5  # More intense pulse
	const GLOW_WIDTH = 8.0  # Width of the glow effect
	
	func _init(from_pos: Vector2, to_pos: Vector2, connection_color: Color):
		start_pos = from_pos
		end_pos = to_pos
		color = connection_color
		z_index = -1  # Draw behind tiles
	
	func _draw():
		var current_color = color
		if is_active:
			current_color = current_color.lightened(PULSE_INTENSITY)
		
		# Draw glow effect
		var glow_color = current_color
		glow_color.a = 0.2  # More transparent for glow
		draw_line(start_pos, end_pos, glow_color, GLOW_WIDTH)
		
		# Draw main line
		current_color.a = 0.4  # Semi-transparent main line
		draw_line(start_pos, end_pos, current_color, LINE_WIDTH)
	
	func set_active(active: bool):
		is_active = active
		queue_redraw()
	
	func pulse():
		var tween = create_tween()
		# Fade in
		tween.tween_method(func(v: float): 
			is_active = true
			color.a = v
			queue_redraw()
		, 0.2, 0.6, PULSE_DURATION/2)
		# Fade out
		tween.tween_method(func(v: float):
			is_active = v > 0.3
			color.a = v
			queue_redraw()
		, 0.6, 0.2, PULSE_DURATION/2)

func _init(pos: Vector2i, targets: Array, types: Array = [], switch_color: Variant = Color(1, 1, 0)):
	print("[Switch] Initializing switch at pos: ", pos, " with color: ", switch_color)
	position = pos
	if switch_color is String:
		print("[Switch] Converting color from string: ", switch_color)
		color = Color(switch_color)
	else:
		color = switch_color
	print("[Switch] Final color value: ", color)
	
	# Convert input targets to typed Array[Vector2i]
	target_positions = []
	for target in targets:
		target_positions.append(Vector2i(target[0], target[1]) if target is Array else target)
	
	# Convert input types to typed Array[int]
	toggle_types = []
	for type in types:
		toggle_types.append(int(type))
	print("[Switch] Sequence loaded with types: ", toggle_types)
	
	# If no types specified, default to alternating wall/floor
	if toggle_types.is_empty():
		toggle_types = [GridManager.WALL_TYPE, GridManager.FLOOR_TYPE]

# Method to get the next tile type in the toggle sequence
func get_next_tile_type(_current_type: int) -> int:
	# If sequence hasn't started or we reached the end, start from beginning
	if current_sequence_index == -1 or current_sequence_index >= toggle_types.size() - 1:
		current_sequence_index = 0
		print("[Switch] Starting sequence from beginning, returning type: ", toggle_types[0])
	else:
		current_sequence_index += 1
		print("[Switch] Moving to next type in sequence: ", toggle_types[current_sequence_index])
	
	return toggle_types[current_sequence_index]

# Create a new connection node
func create_connection(from_pos: Vector2, to_pos: Vector2) -> Connection:
	return Connection.new(from_pos, to_pos, color)

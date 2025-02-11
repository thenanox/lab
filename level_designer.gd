extends Node2D

enum TileType {
	WALL = 0,
	FLOOR = 1,
	HOLE = 2,
	LADDER = 3,
	SWITCH = 4,
	PLAYER_START = 5  # New type for the player start (character should not be painted as a tile)
}

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var type_label: Label = $UILayer/TypeLabel
@onready var player_start_button: Button = $UILayer/PlayerStartButton
@onready var export_button: Button = $UILayer/ExportButton
@onready var switch_button: Button = $UILayer/SwitchButton
@onready var load_button: Button = $UILayer/LoadButton

var current_tile_type: int = TileType.WALL
var player_start: Vector2i = Vector2i.ZERO
var switches: Array = []
var current_switch_targets: Array = []
var is_placing_switch: bool = false
var switch_toggle_types: Array[int] = [TileType.WALL, TileType.FLOOR]

# NEW: A dedicated marker for the player start
var player_marker: Sprite2D

# Add these variables near the top of the file, with the other variable declarations
var max_moves_input: SpinBox
var max_jumps_input: SpinBox

# Add these variables at the top
var active_switch: Dictionary = {}  # Stores current switch being configured
var switch_tiles_markers: Array[Node] = []  # Visual markers for switch-connected tiles

# Add these constants at the top of the file
const GRID_START_X = 0  # Left edge of red square
const GRID_START_Y = 0  # Just below UI buttons
const GRID_WIDTH = 56  # Width in tiles (adjust as needed)
const GRID_HEIGHT = 28  # Height in tiles (adjust as needed)
const TILE_SIZE = 16  # Size of each tile in pixels
const GRID_COLOR := Color(0.2, 0.2, 0.2, 0.3)  # Semi-transparent gray
const BORDER_COLOR := Color(1, 0, 0, 0.5)  # Semi-transparent red
const BORDER_WIDTH := 2.0

# Add at class level
var current_switch_dialog: Window = null
var is_adding_targets: bool = false
var current_editing_switch: Dictionary = {}
var is_switch_dialog_open := false

func _ready():
	# Setup UI connections
	export_button.pressed.connect(_on_export_button_pressed)
	switch_button.pressed.connect(_on_switch_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	
	$UILayer/WallButton.pressed.connect(func(): set_tile_type(TileType.WALL))
	$UILayer/FloorButton.pressed.connect(func(): set_tile_type(TileType.FLOOR))
	$UILayer/HoleButton.pressed.connect(func(): set_tile_type(TileType.HOLE))
	$UILayer/LadderButton.pressed.connect(func(): set_tile_type(TileType.LADDER))
	$UILayer/SwitchButton.pressed.connect(func(): set_tile_type(TileType.SWITCH))
	$UILayer/PlayerStartButton.pressed.connect(func(): set_tile_type(TileType.PLAYER_START))
	
	# Create a separate player marker (not painted as a tile)
	player_marker = Sprite2D.new()
	player_marker.texture = preload("res://sprites/player.png")
	# Use a semi-transparent color to indicate it's just a marker
	player_marker.modulate = Color(1, 1, 1, 0.5)
	player_marker.position = tile_map_layer.map_to_local(player_start)
	add_child(player_marker)
	
	# Create max moves input
	var moves_label = Label.new()
	moves_label.text = "Max Moves:"
	ui_layer.add_child(moves_label)
	moves_label.position = Vector2(800, 10)

	max_moves_input = SpinBox.new()
	max_moves_input.min_value = 0
	max_moves_input.max_value = 100
	max_moves_input.value = 5  # Default value
	ui_layer.add_child(max_moves_input)
	max_moves_input.position = Vector2(900, 10)

	# Create max jumps input
	var jumps_label = Label.new()
	jumps_label.text = "Max Jumps:"
	ui_layer.add_child(jumps_label)
	jumps_label.position = Vector2(800, 50)

	max_jumps_input = SpinBox.new()
	max_jumps_input.min_value = 0
	max_jumps_input.max_value = 100
	max_jumps_input.value = 2  # Default value
	ui_layer.add_child(max_jumps_input)
	max_jumps_input.position = Vector2(900, 50)

	# Position camera to center on the grid
	var camera = $Camera2D
	if camera:
		var grid_center_x = (GRID_START_X + GRID_WIDTH/2) * TILE_SIZE
		var grid_center_y = (GRID_START_Y/TILE_SIZE + GRID_HEIGHT/2) * TILE_SIZE
		camera.position = Vector2(grid_center_x, grid_center_y)

	# Make sure the grid is redrawn when needed
	queue_redraw()

func _input(event):
	if event is InputEventMouseButton:
		# Check if mouse is over any UI button
		for child in ui_layer.get_children():
			if child is Button and child.get_global_rect().has_point(event.global_position):
				return

		var global_mouse_pos = get_global_mouse_position()
		var grid_pos = tile_map_layer.local_to_map(global_mouse_pos)
		
		if not is_within_grid(grid_pos):
			return
			
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_adding_targets and current_editing_switch != null:
				# Just add the position to targets, don't modify the tile
				current_editing_switch.targets.append([grid_pos.x, grid_pos.y])
				add_switch_tile_marker(grid_pos)
				update_targets_list(current_switch_dialog)
			elif not is_switch_dialog_open:
				# Check if clicking on a switch
				var switch = get_switch_at_position(grid_pos)
				if not switch.is_empty():
					current_editing_switch = switch
					show_switch_dialog()
				else:
					place_tile(grid_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_switch_dialog_open:
			remove_tile(grid_pos)

func set_tile_type(type: int):
	current_tile_type = type
	type_label.text = "Current Type: " + get_type_name(type)
	is_placing_switch = false

func get_type_name(type: int) -> String:
	match type:
		TileType.WALL: return "Wall"
		TileType.FLOOR: return "Floor"
		TileType.HOLE: return "Hole"
		TileType.LADDER: return "Ladder"
		TileType.SWITCH: return "Switch"
		TileType.PLAYER_START: return "Player Start"
	return "Unknown"

func place_tile(grid_pos: Vector2i):
	if current_tile_type == TileType.PLAYER_START:
		# Player can be placed on top of any tile
		player_start = grid_pos
		player_marker.position = tile_map_layer.map_to_local(grid_pos)
		return
		
	# For all other tiles, check if there's already a tile here
	if tile_map_layer.get_cell_atlas_coords(grid_pos) != Vector2i(-1, -1):
		return  # Don't replace existing tiles
		
	if current_tile_type == TileType.SWITCH:
		# Place the switch tile
		var atlas_coords = get_atlas_coords(TileType.SWITCH)
		tile_map_layer.set_cell(grid_pos, 0, atlas_coords)
		
		# Create new switch with empty targets and types
		var new_switch = {
			"pos": [grid_pos.x, grid_pos.y],
			"targets": [],
			"types": []
		}
		switches.append(new_switch)
		return
	else:
		var atlas_coords = get_atlas_coords(current_tile_type)
		tile_map_layer.set_cell(grid_pos, 0, atlas_coords)

func remove_tile(grid_pos: Vector2i):
	# Check if tile is part of any switch
	for switch in switches:
		if switch.pos[0] == grid_pos.x and switch.pos[1] == grid_pos.y:
			# Remove switch and all its markers
			switches.erase(switch)
			clear_switch_markers()
			tile_map_layer.erase_cell(grid_pos)
			return
		
		for target in switch.targets:
			if target[0] == grid_pos.x and target[1] == grid_pos.y:
				return  # Can't remove switch target tiles directly
	
	# Normal tile removal...
	if grid_pos == player_start:
		player_start = Vector2i.ZERO
		player_marker.position = Vector2.ZERO
		return
	tile_map_layer.erase_cell(grid_pos)

func get_atlas_coords(tile_type: int) -> Vector2i:
	match tile_type:
		TileType.WALL: return Vector2i(0, 3)
		TileType.FLOOR: return Vector2i(0, 4)
		TileType.HOLE: return Vector2i(9, 0)
		TileType.LADDER: return Vector2i(8, 5)
		TileType.SWITCH: return Vector2i(7, 2)
		TileType.PLAYER_START: return Vector2i(1, 1)  # Not used since we don't paint a tile for player start
	return Vector2i.ZERO

# Helper: place the switch tile (the switch itself)
func place_switch_tile(grid_pos: Vector2i):
	var atlas_coords = get_atlas_coords(TileType.SWITCH)
	tile_map_layer.set_cell(grid_pos, 0, atlas_coords)

func handle_switch_placement(grid_pos: Vector2i):
	# Called while placing a switch target. Simply record the target and provide visual feedback.
	current_switch_targets.append(grid_pos)
	# Optionally, paint a default target tile (e.g. using the Floor tile appearance)
	var atlas_coords = get_atlas_coords(TileType.FLOOR)
	tile_map_layer.set_cell(grid_pos, 0, atlas_coords)

func _on_switch_button_pressed():
	# Just set the tile type to switch
	set_tile_type(TileType.SWITCH)

# Helper function to convert index to tile type
func get_type_from_index(index: int) -> int:
	match index:
		0: return TileType.WALL
		1: return TileType.FLOOR
		2: return TileType.HOLE
		3: return TileType.LADDER
	return TileType.FLOOR  # Default

# Helper function to create readable order string
func get_order_string(types: Array[int]) -> String:
	if types.is_empty():
		return "No types selected"
	
	var names = []
	for type in types:
		names.append(get_type_name(type))
	return " -> ".join(names) + " -> " + names[0]

# Helper: creates a visual marker for a switch target tile (with the specified rotation)
func create_target_marker(target: Dictionary):
	var marker = Sprite2D.new()
	# For visual feedback, we use the texture from the tile set source.
	# (You can adjust this to use a specific target marker texture if desired.)
	marker.texture = tile_map_layer.tile_set.get_source(GridManager.TILE_SOURCE_ID).texture
	marker.region_enabled = true
	# Calculate region_rect based on the toggle type's atlas coordinates (using the first toggle type if available)
	var toggle_type = switch_toggle_types[0] if switch_toggle_types.size() > 0 else TileType.FLOOR
	marker.region_rect = Rect2(Vector2(get_atlas_coords(toggle_type)) * Vector2(17, 17), Vector2(16, 16))
	marker.position = tile_map_layer.map_to_local(target["pos"])
	marker.rotation_degrees = target["rotation"]
	add_child(marker)

func _on_export_button_pressed():
	var level_data = export_level_data()
	var json_string = JSON.stringify(level_data, "  ")

	# Create a file dialog to select level
	var file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	
	# Use an absolute path to the project's data directory
	var data_dir = ProjectSettings.globalize_path("res://data/")
	file_dialog.current_dir = data_dir
	file_dialog.add_filter("*.json", "Level Files")
	
	# Set a larger initial size for the dialog
	file_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	file_dialog.size = Vector2i(800, 600)

	file_dialog.file_selected.connect(func(path): 
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(json_string)
		file.close()
		print("Level exported to: ", path)
	)

	add_child(file_dialog)
	file_dialog.popup_centered()

func export_level_data() -> Dictionary:
	var tile_data: Array = []
	var used_cells = tile_map_layer.get_used_cells()
	for cell in used_cells:
		var tile_type = get_tile_type_at_pos(cell)
		tile_data.append([cell.x, cell.y, tile_type])
	return {
		"id": OS.get_unique_id(),
		"name": "Level 1",
		"tile_data": tile_data,
		"player_start": [player_start.x, player_start.y],
		"max_moves": int(max_moves_input.value),
		"max_jumps": int(max_jumps_input.value),
		"switches": switches
	}

func get_tile_type_at_pos(pos: Vector2i) -> int:
	var atlas_coords = tile_map_layer.get_cell_atlas_coords(pos)
	if atlas_coords == Vector2i(0, 3): return TileType.WALL
	if atlas_coords == Vector2i(0, 4): return TileType.FLOOR
	if atlas_coords == Vector2i(9, 0): return TileType.HOLE
	if atlas_coords == Vector2i(8, 5): return TileType.LADDER
	if atlas_coords == Vector2i(7, 2): return TileType.SWITCH
	if atlas_coords == Vector2i(1, 1): return TileType.PLAYER_START
	return TileType.WALL  # Default

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		GameManager.hide_ui()  # Hide GameManager UI
		queue_free()
		get_tree().change_scene_to_file("res://menu.tscn")

func _on_load_button_pressed():
	var file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	
	var data_dir = ProjectSettings.globalize_path("res://data/")
	file_dialog.current_dir = data_dir
	file_dialog.add_filter("*.json", "Level Files")
	
	file_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	file_dialog.size = Vector2i(800, 600)
	file_dialog.title = "Load Level to Edit"
	
	file_dialog.file_selected.connect(func(path):
		load_level_from_file(path)
	)
	
	add_child(file_dialog)
	file_dialog.popup_centered()

func load_level_from_file(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
		
	var json_string = file.get_as_text()
	var json_data = JSON.parse_string(json_string)
	
	if not json_data:
		return
		
	# Clear existing level data
	tile_map_layer.clear()
	switches.clear()
	player_start = Vector2i.ZERO
	player_marker.position = Vector2.ZERO
	
	# Load tile data
	for cell_data in json_data.tile_data:
		var pos = Vector2i(cell_data[0], cell_data[1])
		var tile_type = cell_data[2]
		var atlas_coords = get_atlas_coords(tile_type)
		tile_map_layer.set_cell(pos, 0, atlas_coords)
	
	# Load player start with centered position
	if json_data.has("player_start"):
		player_start = Vector2i(json_data.player_start[0], json_data.player_start[1])
		player_marker.position = tile_map_layer.map_to_local(player_start)
	
	# Load moves and jumps
	if json_data.has("max_moves"):
		max_moves_input.value = json_data.max_moves
	if json_data.has("max_jumps"):
		max_jumps_input.value = json_data.max_jumps
	
	# Load switches
	if json_data.has("switches"):
		switches = json_data.switches

# Add this helper function to check if a position is within the valid grid
func is_within_grid(pos: Vector2i) -> bool:
	return (pos.x >= GRID_START_X and pos.x < GRID_START_X + GRID_WIDTH and 
			pos.y >= GRID_START_Y/TILE_SIZE and pos.y < GRID_START_Y/TILE_SIZE + GRID_HEIGHT)

# Add this function to draw the grid
func _draw():
	# Draw the border around valid area
	var rect = Rect2(
		Vector2(GRID_START_X * TILE_SIZE, GRID_START_Y), 
		Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)
	)
	draw_rect(rect, BORDER_COLOR, false, BORDER_WIDTH)  # Draw border
	
	# Draw vertical grid lines
	for x in range(GRID_WIDTH + 1):
		var from = Vector2(x * TILE_SIZE, GRID_START_Y)
		var to = Vector2(x * TILE_SIZE, GRID_START_Y + GRID_HEIGHT * TILE_SIZE)
		draw_line(from, to, GRID_COLOR)
	
	# Draw horizontal grid lines
	for y in range(GRID_HEIGHT + 1):
		var from = Vector2(0, GRID_START_Y + y * TILE_SIZE)
		var to = Vector2(GRID_WIDTH * TILE_SIZE, GRID_START_Y + y * TILE_SIZE)
		draw_line(from, to, GRID_COLOR)

# Add new function to show "Add Target" button
func show_add_target_button():
	var add_button = Button.new()
	add_button.text = "Add Target"
	add_button.position = Vector2(900, 100)
	ui_layer.add_child(add_button)
	
	add_button.pressed.connect(func():
		current_tile_type = -1  # Special mode for adding targets
		add_button.queue_free()
	)

# Add function to create visual marker for switch-connected tiles
func add_switch_tile_marker(pos: Vector2i):
	var marker = Sprite2D.new()
	marker.modulate = Color(1, 1, 0, 0.3)  # Semi-transparent yellow
	marker.position = tile_map_layer.map_to_local(pos)
	add_child(marker)
	switch_tiles_markers.append(marker)

func clear_switch_markers():
	for marker in switch_tiles_markers:
		marker.queue_free()
	switch_tiles_markers.clear()

# Add as a class method
func update_targets_container(targets: Array, container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for target in targets:
		var label = Label.new()
		label.text = "Target: " + str(target)
		container.add_child(label)

func show_switch_dialog():
	is_switch_dialog_open = true
	current_switch_dialog = Window.new()
	current_switch_dialog.title = "Configure Switch"
	current_switch_dialog.size = Vector2i(400, 600)
	current_switch_dialog.unresizable = true
	current_switch_dialog.close_requested.connect(on_switch_dialog_cancelled)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2i(380, 580)
	current_switch_dialog.add_child(vbox)
	
	# Step 1: Type Selection
	var step1_label = Label.new()
	step1_label.text = "Step 1: Select Tile Type Sequence"
	vbox.add_child(step1_label)
	
	var type_container = VBoxContainer.new()
	vbox.add_child(type_container)
	
	var sequence_label = Label.new()
	sequence_label.text = "Current Sequence: (none)"
	vbox.add_child(sequence_label)
	
	# Initialize ordered_types with existing types if any
	var ordered_types: Array[int] = []
	if current_editing_switch.has("types"):
		for type in current_editing_switch.types:
			ordered_types.append(type as int)
	
	# Type buttons
	var type_buttons = {
		TileType.WALL: "Wall",
		TileType.FLOOR: "Floor",
		TileType.HOLE: "Hole",
		TileType.LADDER: "Ladder"
	}
	
	for type in type_buttons:
		var btn = Button.new()
		btn.text = "Add " + type_buttons[type]
		type_container.add_child(btn)
		btn.pressed.connect(func():
			ordered_types.append(type)
			update_sequence_label(sequence_label, ordered_types, type_buttons)
		)
	
	# Clear sequence button
	var clear_btn = Button.new()
	clear_btn.text = "Clear Sequence"
	type_container.add_child(clear_btn)
	clear_btn.pressed.connect(func():
		ordered_types.clear()
		sequence_label.text = "Current Sequence: (none)"
	)
	
	# Step 2: Target Selection
	var step2_label = Label.new()
	step2_label.text = "\nStep 2: Select Target Tiles"
	vbox.add_child(step2_label)
	
	# Create targets container with a unique name
	var targets_container = VBoxContainer.new()
	targets_container.name = "TargetsContainer"
	targets_container.custom_minimum_size = Vector2i(0, 200)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2i(0, 200)
	scroll.add_child(targets_container)
	vbox.add_child(scroll)
	
	# Show existing targets and their markers
	if not current_editing_switch.targets.is_empty():
		clear_switch_markers()  # Clear any existing markers
		for target in current_editing_switch.targets:
			add_switch_tile_marker(Vector2i(target[0], target[1]))
		update_targets_list(current_switch_dialog)
	
	var target_btn = Button.new()
	target_btn.text = "Add Targets"
	vbox.add_child(target_btn)
	
	target_btn.pressed.connect(func():
		is_adding_targets = !is_adding_targets
		target_btn.text = "Stop Adding" if is_adding_targets else "Add Targets"
	)
	
	# Save button
	var save_btn = Button.new()
	save_btn.text = "Save Switch"
	vbox.add_child(save_btn)
	save_btn.pressed.connect(func():
		if ordered_types.size() > 0:
			current_editing_switch.types = ordered_types
			enable_ui_buttons()
			is_switch_dialog_open = false
			current_switch_dialog.queue_free()
			current_switch_dialog = null
			is_adding_targets = false
			current_editing_switch = {}
	)
	
	add_child(current_switch_dialog)
	current_switch_dialog.popup_centered()

func disable_ui_buttons():
	for child in ui_layer.get_children():
		if child is Button:
			child.disabled = true

func enable_ui_buttons():
	for child in ui_layer.get_children():
		if child is Button:
			child.disabled = false

func on_switch_dialog_cancelled():
	is_switch_dialog_open = false
	# Remove the switch if dialog is cancelled
	if current_editing_switch in switches:
		switches.erase(current_editing_switch)
		# Remove the switch tile
		var pos = Vector2i(current_editing_switch.pos[0], current_editing_switch.pos[1])
		tile_map_layer.erase_cell(pos)
	
	enable_ui_buttons()
	clear_switch_markers()
	current_switch_dialog.queue_free()
	current_switch_dialog = null
	is_adding_targets = false
	current_editing_switch = {}

func update_sequence_label(label: Label, types: Array, buttons: Dictionary):
	if types.is_empty():
		label.text = "Current Sequence: (none)"
		return
	
	var names = []
	for type in types:
		names.append(buttons[type])
	label.text = "Current Sequence: " + " -> ".join(names) + " -> " + names[0]

func update_targets_list(dialog: Window):
	var targets_container = dialog.get_node_or_null("%TargetsContainer")
	if not targets_container:
		return
	
	for child in targets_container.get_children():
		child.queue_free()
	
	if current_editing_switch.targets.is_empty():
		var label = Label.new()
		label.text = "No targets selected"
		targets_container.add_child(label)
		return
		
	for i in range(current_editing_switch.targets.size()):
		var target = current_editing_switch.targets[i]
		var hbox = HBoxContainer.new()
		
		var label = Label.new()
		label.text = "Target %d: (%d, %d)" % [i + 1, target[0], target[1]]
		hbox.add_child(label)
		
		var remove_btn = Button.new()
		remove_btn.text = "Remove"
		remove_btn.pressed.connect(func():
			current_editing_switch.targets.remove_at(i)
			clear_switch_markers()
			# Recreate markers for remaining targets
			for t in current_editing_switch.targets:
				add_switch_tile_marker(Vector2i(t[0], t[1]))
			update_targets_list(dialog)
		)
		hbox.add_child(remove_btn)
		
		targets_container.add_child(hbox)

# Add function to find switch at position
func get_switch_at_position(grid_pos: Vector2i) -> Dictionary:
	for switch in switches:
		if switch.pos[0] == grid_pos.x and switch.pos[1] == grid_pos.y:
			return switch
	return {}

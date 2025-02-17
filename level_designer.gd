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
var switch_connections: Array[Switch.Connection] = []  # Store visual connections
var switch_overlays: Array[Sprite2D] = []  # Store colored overlays for switches and targets

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
				
				# Remove only the connections for the current switch being edited
				remove_switch_connections(current_editing_switch)
				# Recreate connections for the current switch
				create_switch_connections(current_editing_switch)
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
			"types": [],
			"color": "#ffff00"  # Default yellow color
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
			# Remove connections and overlays only for this switch
			remove_switch_connections(switch)
			# Remove switch and its markers
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
	clear_switch_connections()
	
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
		for switch in switches:
			create_switch_connections(switch)

func clear_switch_connections():
	for connection in switch_connections:
		connection.queue_free()
	switch_connections.clear()
	
	for overlay in switch_overlays:
		overlay.queue_free()
	switch_overlays.clear()

func create_switch_connections(switch: Dictionary):
	var switch_pos = Vector2i(switch.pos[0], switch.pos[1])
	var switch_world_pos = tile_map_layer.map_to_local(switch_pos)
	
	# Create switch overlay
	var switch_color = Color(switch.get("color", "#ffff00"))  # Default yellow if no color specified
	var switch_overlay = create_colored_overlay(switch_pos, switch_color)
	switch_overlays.append(switch_overlay)
	
	for target in switch.targets:
		var target_pos = Vector2i(target[0], target[1])
		var target_world_pos = tile_map_layer.map_to_local(target_pos)
		
		# Create connection
		var connection = Switch.Connection.new(switch_world_pos, target_world_pos, switch_color)
		add_child(connection)
		switch_connections.append(connection)
		
		# Create target overlay
		var target_overlay = create_colored_overlay(target_pos, switch_color)
		switch_overlays.append(target_overlay)

func create_colored_overlay(grid_pos: Vector2i, color: Color) -> Sprite2D:
	var overlay = Sprite2D.new()
	var tile_set_source = tile_map_layer.tile_set.get_source(GridManager.TILE_SOURCE_ID)
	overlay.texture = tile_set_source.texture
	overlay.region_enabled = true
	overlay.region_rect = Rect2(Vector2(0, 4) * Vector2(17, 17), Vector2(16, 16))  # Use floor tile as base
	var overlay_color = color.lightened(0.2)
	overlay_color.a = 0.3  # Set alpha directly
	overlay.modulate = overlay_color
	overlay.position = tile_map_layer.map_to_local(grid_pos)
	overlay.z_index = 1  # Draw on top of tiles
	add_child(overlay)
	return overlay

func show_switch_dialog():
	is_switch_dialog_open = true
	current_switch_dialog = Window.new()
	current_switch_dialog.title = "Configure Switch"
	current_switch_dialog.size = Vector2i(400, 600)  # Reduced width, kept good height
	current_switch_dialog.unresizable = false  # Allow resizing
	current_switch_dialog.close_requested.connect(on_switch_dialog_cancelled)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size = Vector2i(380, 580)  # Adjusted to fit window with padding
	current_switch_dialog.add_child(vbox)
	
	# Step 0: Color Selection
	var step0_label = Label.new()
	step0_label.text = "Step 0: Select Switch Color"
	vbox.add_child(step0_label)
	
	var color_picker = ColorPickerButton.new()
	color_picker.custom_minimum_size = Vector2(200, 30)
	if current_editing_switch.has("color"):
		color_picker.color = Color(current_editing_switch.color)
	else:
		color_picker.color = Color(1, 1, 0)  # Default yellow
	vbox.add_child(color_picker)
	
	# Update connections when color changes
	color_picker.color_changed.connect(func(new_color: Color):
		current_editing_switch.color = new_color.to_html()
		remove_switch_connections(current_editing_switch)
		create_switch_connections(current_editing_switch)
	)
	
	# Step 1: Type Selection
	var step1_label = Label.new()
	step1_label.text = "\nStep 1: Select Tile Type Sequence"
	vbox.add_child(step1_label)
	
	var type_container = VBoxContainer.new()
	type_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_container.custom_minimum_size = Vector2(0, 150)  # Reduced height
	vbox.add_child(type_container)
	
	var sequence_label = Label.new()
	sequence_label.text = "Current Sequence: (none)"
	sequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sequence_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	
	# Update sequence label with existing types immediately
	if not ordered_types.is_empty():
		update_sequence_label(sequence_label, ordered_types, type_buttons)
	
	var type_grid = GridContainer.new()
	type_grid.columns = 2  # Two buttons per row
	type_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_container.add_child(type_grid)
	
	for type in type_buttons:
		var btn = Button.new()
		btn.text = "Add " + type_buttons[type]
		btn.custom_minimum_size = Vector2(180, 30)  # Smaller buttons
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		type_grid.add_child(btn)
		btn.pressed.connect(func():
			ordered_types.append(type)
			update_sequence_label(sequence_label, ordered_types, type_buttons)
		)
	
	# Clear sequence button
	var clear_btn = Button.new()
	clear_btn.text = "Clear Sequence"
	clear_btn.custom_minimum_size = Vector2(180, 30)
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	targets_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets_container.custom_minimum_size = Vector2i(0, 150)  # Reduced height
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2i(0, 150)  # Match container height
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(targets_container)
	vbox.add_child(scroll)
	
	# Show existing targets and their markers
	if not current_editing_switch.targets.is_empty():
		clear_switch_markers()  # Clear any existing markers
		remove_switch_connections(current_editing_switch)  # Only remove connections for this switch
		for target in current_editing_switch.targets:
			add_switch_tile_marker(Vector2i(target[0], target[1]))
		create_switch_connections(current_editing_switch)  # Create new connections
		update_targets_list(current_switch_dialog)
	
	var target_btn = Button.new()
	target_btn.text = "Add Targets"
	target_btn.custom_minimum_size = Vector2(180, 30)
	target_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(target_btn)
	
	target_btn.pressed.connect(func():
		is_adding_targets = !is_adding_targets
		target_btn.text = "Stop Adding" if is_adding_targets else "Add Targets"
	)
	
	# Save button
	var save_btn = Button.new()
	save_btn.text = "Save Switch"
	save_btn.custom_minimum_size = Vector2(180, 30)
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(save_btn)
	save_btn.pressed.connect(func():
		# Validate switch configuration
		if ordered_types.is_empty():
			show_error_dialog("Please add at least one tile type to the sequence.")
			return
			
		if current_editing_switch.targets.is_empty():
			show_error_dialog("Please add at least one target tile.")
			return
			
		# Update switch data
		current_editing_switch.types = ordered_types
		current_editing_switch.color = color_picker.color.to_html()
		
		# Make sure the switch is in the switches array
		if not (current_editing_switch in switches):
			switches.append(current_editing_switch)
		
		# Update visuals
		remove_switch_connections(current_editing_switch)
		create_switch_connections(current_editing_switch)
		
		# Clean up and close dialog
		enable_ui_buttons()
		is_switch_dialog_open = false
		is_adding_targets = false
		current_switch_dialog.queue_free()
		current_switch_dialog = null
	)
	
	add_child(current_switch_dialog)
	current_switch_dialog.popup_centered()

func show_error_dialog(text: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	dialog.title = "Error"
	add_child(dialog)
	dialog.popup_centered()

func on_switch_dialog_cancelled():
	is_switch_dialog_open = false
	
	# Only remove the switch if it's new and not fully configured
	if current_editing_switch in switches:
		if current_editing_switch.types.is_empty() or current_editing_switch.targets.is_empty():
			switches.erase(current_editing_switch)
			# Remove the switch tile
			var pos = Vector2i(current_editing_switch.pos[0], current_editing_switch.pos[1])
			tile_map_layer.erase_cell(pos)
			remove_switch_connections(current_editing_switch)
	else:
		# New switch that was never saved
		var pos = Vector2i(current_editing_switch.pos[0], current_editing_switch.pos[1])
		tile_map_layer.erase_cell(pos)
		remove_switch_connections(current_editing_switch)
	
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

# Add new function to remove connections for a specific switch
func remove_switch_connections(switch: Dictionary):
	var switch_world_pos = tile_map_layer.map_to_local(Vector2i(switch.pos[0], switch.pos[1]))
	
	# Remove connections for this switch
	var connections_to_remove: Array[Switch.Connection] = []
	for connection in switch_connections:
		if connection.start_pos == switch_world_pos:
			connections_to_remove.append(connection)
	
	# Remove overlays for this switch and its targets
	var overlays_to_remove: Array[Sprite2D] = []
	for overlay in switch_overlays:
		var overlay_grid_pos = tile_map_layer.local_to_map(overlay.position)
		if overlay_grid_pos == Vector2i(switch.pos[0], switch.pos[1]):
			overlays_to_remove.append(overlay)
		for target in switch.targets:
			if overlay_grid_pos == Vector2i(target[0], target[1]):
				overlays_to_remove.append(overlay)
	
	# Free and remove the connections and overlays
	for connection in connections_to_remove:
		connection.queue_free()
		switch_connections.erase(connection)
	
	for overlay in overlays_to_remove:
		overlay.queue_free()
		switch_overlays.erase(overlay)

func disable_ui_buttons():
	for child in ui_layer.get_children():
		if child is Button:
			child.disabled = true

func enable_ui_buttons():
	for child in ui_layer.get_children():
		if child is Button:
			child.disabled = false

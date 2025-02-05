extends Node2D

enum TileType {
	WALL = 0,
	FLOOR = 1,
	HOLE = 2,
	LADDER = 3,
	SWITCH = 4,
	PLAYER_START = 5  # Add a new type for player start
}

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var type_label: Label = $UILayer/TypeLabel
@onready var player_start_button: Button = $UILayer/PlayerStartButton
@onready var export_button: Button = $UILayer/ExportButton
@onready var switch_button: Button = $UILayer/SwitchButton

var current_tile_type: int = TileType.WALL
var player_start: Vector2i = Vector2i.ZERO
var switches: Array = []
var current_switch_targets: Array = []
var is_placing_switch: bool = false
var switch_toggle_types: Array[int] = [TileType.WALL, TileType.FLOOR]

func _ready():
	# Setup UI connections

	export_button.pressed.connect(_on_export_button_pressed)
	switch_button.pressed.connect(_on_switch_button_pressed)
	
	# Setup tile type buttons
	$UILayer/WallButton.pressed.connect(func(): set_tile_type(TileType.WALL))
	$UILayer/FloorButton.pressed.connect(func(): set_tile_type(TileType.FLOOR))
	$UILayer/HoleButton.pressed.connect(func(): set_tile_type(TileType.HOLE))
	$UILayer/LadderButton.pressed.connect(func(): set_tile_type(TileType.LADDER))
	$UILayer/SwitchButton.pressed.connect(func(): set_tile_type(TileType.SWITCH))
	$UILayer/PlayerStartButton.pressed.connect(func(): set_tile_type(TileType.PLAYER_START))

func _input(event):
	# Only process input if not over a UI button
	if event is InputEventMouseButton:
		# Check if mouse is over any UI button
		for child in ui_layer.get_children():
			if child is Button and child.get_global_rect().has_point(event.global_position):
				return

		var global_mouse_pos = get_global_mouse_position()
		var grid_pos = tile_map_layer.local_to_map(global_mouse_pos)
		
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_placing_switch:
				handle_switch_placement(grid_pos)
			else:
				place_tile(grid_pos)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
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
	if current_tile_type == TileType.SWITCH:
		is_placing_switch = true
		return
	
	# Remove any existing tile at this position
	tile_map_layer.erase_cell(grid_pos)
	
	# Set the new tile
	var atlas_coords = get_atlas_coords(current_tile_type)
	
	# Special handling for player start
	if current_tile_type == TileType.PLAYER_START:
		player_start = grid_pos
		# Optionally, you could add a visual marker for player start
		tile_map_layer.set_cell(grid_pos, 0, Vector2i(1, 1))  # Use a distinct tile
	else:
		tile_map_layer.set_cell(grid_pos, 0, atlas_coords)

func remove_tile(grid_pos: Vector2i):
	# Check if the tile being removed is the player start
	if grid_pos == player_start:
		player_start = Vector2i.ZERO
	
	tile_map_layer.erase_cell(grid_pos)

func get_atlas_coords(tile_type: int) -> Vector2i:
	match tile_type:
		TileType.WALL: return Vector2i(0, 3)
		TileType.FLOOR: return Vector2i(0, 4)
		TileType.HOLE: return Vector2i(9, 0)
		TileType.LADDER: return Vector2i(8, 5)
		TileType.SWITCH: return Vector2i(7, 2)
		TileType.PLAYER_START: return Vector2i(1, 1)  # Distinct marker
	return Vector2i.ZERO

func handle_switch_placement(grid_pos: Vector2i):
	if current_switch_targets.is_empty():
		# First click places the switch
		place_tile(grid_pos)
		current_switch_targets.append(grid_pos)
	else:
		# Subsequent clicks add targets
		current_switch_targets.append(grid_pos)

func _on_player_start_button_pressed():
	var global_mouse_pos = get_global_mouse_position()
	var grid_pos = tile_map_layer.local_to_map(global_mouse_pos)
	player_start = grid_pos
	print("Player start set to: ", player_start)

func _on_switch_button_pressed():
	# Open a popup to configure switch toggle types
	var popup = PopupPanel.new()
	var vbox = VBoxContainer.new()
	popup.add_child(vbox)
	
	var wall_toggle = CheckBox.new()
	wall_toggle.text = "Wall"
	wall_toggle.button_pressed = switch_toggle_types.has(TileType.WALL)
	vbox.add_child(wall_toggle)
	
	var floor_toggle = CheckBox.new()
	floor_toggle.text = "Floor"
	floor_toggle.button_pressed = switch_toggle_types.has(TileType.FLOOR)
	vbox.add_child(floor_toggle)
	
	var hole_toggle = CheckBox.new()
	hole_toggle.text = "Hole"
	hole_toggle.button_pressed = switch_toggle_types.has(TileType.HOLE)
	vbox.add_child(hole_toggle)
	
	var ladder_toggle = CheckBox.new()
	ladder_toggle.text = "Ladder"
	ladder_toggle.button_pressed = switch_toggle_types.has(TileType.LADDER)
	vbox.add_child(ladder_toggle)
	
	var confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.pressed.connect(func():
		# Update toggle types based on checkboxes
		switch_toggle_types.clear()
		if wall_toggle.button_pressed:
			switch_toggle_types.append(TileType.WALL)
		if floor_toggle.button_pressed:
			switch_toggle_types.append(TileType.FLOOR)
		if hole_toggle.button_pressed:
			switch_toggle_types.append(TileType.HOLE)
		if ladder_toggle.button_pressed:
			switch_toggle_types.append(TileType.LADDER)
		
		# Close popup
		popup.queue_free()
		
		# Reset switch placement
		if not current_switch_targets.is_empty():
			# Finalize the switch
			switches.append({
				"pos": current_switch_targets[0],
				"targets": current_switch_targets.slice(1),
				"types": switch_toggle_types
			})
			current_switch_targets.clear()
			is_placing_switch = false
			print("Switch added: ", switches[-1])
	)
	vbox.add_child(confirm_button)
	
	add_child(popup)
	popup.popup_centered()

func _on_export_button_pressed():
	var level_data = export_level_data()
	var json_string = JSON.stringify(level_data, "  ")
	
	# Open file dialog to save
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.json", "JSON Files")
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
		"max_moves": 0,  
		"max_jumps": 0,  
		"switches": switches
	}

func get_tile_type_at_pos(pos: Vector2i) -> int:
	var atlas_coords = tile_map_layer.get_cell_atlas_coords(pos)
	
	if atlas_coords == Vector2i(0, 3): return TileType.WALL
	if atlas_coords == Vector2i(0, 4): return TileType.FLOOR
	if atlas_coords == Vector2i(9, 0): return TileType.HOLE
	if atlas_coords == Vector2i(8, 5): return TileType.LADDER
	if atlas_coords == Vector2i(7, 2): return TileType.SWITCH
	if atlas_coords == Vector2i(0, 9): return TileType.PLAYER_START
	
	return TileType.WALL  # Default 

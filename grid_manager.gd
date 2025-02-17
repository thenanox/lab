extends Node2D
class_name GridManager

signal level_changed(new_start_pos: Vector2i)
signal player_blocked_by_hole
signal player_reached_switch

const CELL_SIZE := 16
const SPRITE_SIZE := 16

# Constants for tile types - these should match your level data format
const WALL_TYPE := 0
const FLOOR_TYPE := 1
const HOLE_TYPE := 2
const LADDER_TYPE := 3
const SWITCH_TYPE := 4 

# Constants for tile atlas coordinates in the tileset
const WALL_COORDS := Vector2i(0, 3)
const FLOOR_COORDS := Vector2i(0, 4)
const HOLE_COORDS := Vector2i(9, 0)
const LADDER_COORDS := Vector2i(8, 5)
const SWITCH_OFF_COORDS := Vector2i(7, 2)  # Unpressed switch
const SWITCH_ON_COORDS := Vector2i(8, 2)   # Pressed switch
const TILE_SOURCE_ID := 0

@onready var tile_map_layer: TileMapLayer = $TileMapLayer

@export var player_scene: PackedScene  # Add this to reference the Player scene
var player: Player  # Store reference to the player instance
var active_switches: Array[Switch] = []
var switch_connections: Array[Switch.Connection] = []  # Store visual connections
var switch_overlays: Array[Sprite2D] = []  # Store colored overlays for switches and targets

func _ready():
	if !tile_map_layer:
		print("ERROR: TileMapLayer not found!")
		return
	
	if !player_scene:
		push_error("Player scene not set in GridManager!")
		return
		
	load_current_level()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		# Clean up current scene
		if player:
			player.queue_free()
		GameManager.hide_ui()  # Hide GameManager UI
		queue_free()
		get_tree().change_scene_to_file("res://menu.tscn")

func load_current_level():
	var level_data = LevelManager.load_level(LevelManager.current_level)
	print("[GridManager] Loading level: ", LevelManager.current_level)
	if level_data.is_empty():
		print("[GridManager] No level data found!")
		return
		
	print("[GridManager] Level data: ", level_data)
	
	# Set move/jump limits for this level
	if level_data.has("max_moves") and level_data.has("max_jumps"):
		GameManager.set_level_limits(level_data.max_moves, level_data.max_jumps)
	
	# Clear existing tiles and connections
	clear_tiles()
	clear_switch_connections()
		
	# Load tile data
	for cell_data in level_data.tile_data:
		var pos = Vector2i(cell_data[0], cell_data[1])
		var tile_type = cell_data[2]
		var atlas_coords
		
		# Set the correct atlas coordinates based on tile type
		match tile_type:
			WALL_TYPE: atlas_coords = WALL_COORDS
			FLOOR_TYPE: atlas_coords = FLOOR_COORDS
			HOLE_TYPE: atlas_coords = HOLE_COORDS
			LADDER_TYPE: atlas_coords = LADDER_COORDS
			SWITCH_TYPE: atlas_coords = SWITCH_OFF_COORDS
		
		tile_map_layer.set_cell(pos, TILE_SOURCE_ID, atlas_coords)
	
	# Create player if it doesn't exist
	if !player:
		player = player_scene.instantiate() as Player
		player.grid_manager = self
		add_child(player)
		# Set initial position immediately after creation
		# Convert player_start from array to Vector2i if needed
		var start_pos = Vector2i(level_data.player_start[0], level_data.player_start[1])
		player.position = grid_to_world(start_pos)
	
	# Load switches
	active_switches.clear()
	if level_data.has("switches"):
		print("[GridManager] Loading switches: ", level_data.switches)
		for switch_data in level_data.switches:
			var switch_color = Color(switch_data.get("color", "#ffff00"))  # Default to yellow if no color specified
			print("[GridManager] Creating switch with color: ", switch_color, " from data: ", switch_data.get("color"))
			var new_switch = Switch.new(
				Vector2i(switch_data.pos[0], switch_data.pos[1]), 
				switch_data.targets,
				switch_data.get("types", []),
				switch_color
			)
			print("[GridManager] New switch color after creation: ", new_switch.color)
			active_switches.append(new_switch)
			create_switch_connections(new_switch)
	
	# Emit signal for player repositioning after tiles are loaded
	level_changed.emit(Vector2i(level_data.player_start[0], level_data.player_start[1]))

func clear_tiles() -> void:
	var used_cells = tile_map_layer.get_used_cells()
	for cell in used_cells:
		tile_map_layer.erase_cell(cell)

func load_next_level():
	var level_data = LevelManager.next_level()
	if level_data.is_empty():
		GameManager.on_game_completed()
		clear_tiles()
		if player:
			player.queue_free()
			player = null
		return
		
	# Set move/jump limits for this level
	if level_data.has("max_moves") and level_data.has("max_jumps"):
		GameManager.set_level_limits(level_data.max_moves, level_data.max_jumps)
	
	clear_tiles()
	clear_switch_connections()
	
	# Load tile data
	for cell_data in level_data.tile_data:
		var pos = Vector2i(cell_data[0], cell_data[1])
		var tile_type = cell_data[2]
		var atlas_coords
		
		# Set the correct atlas coordinates based on tile type
		match tile_type:
			WALL_TYPE: atlas_coords = WALL_COORDS
			FLOOR_TYPE: atlas_coords = FLOOR_COORDS
			HOLE_TYPE: atlas_coords = HOLE_COORDS
			LADDER_TYPE: atlas_coords = LADDER_COORDS
			SWITCH_TYPE: atlas_coords = SWITCH_OFF_COORDS
		
		tile_map_layer.set_cell(pos, TILE_SOURCE_ID, atlas_coords)
	
	# Load switches
	active_switches.clear()
	if level_data.has("switches"):
		for switch_data in level_data.switches:
			var switch_color = Color(switch_data.get("color", "#ffff00"))  # Default to yellow if no color specified
			var new_switch = Switch.new(
				Vector2i(switch_data.pos[0], switch_data.pos[1]),
				switch_data.targets,
				switch_data.get("types", []),
				switch_color
			)
			active_switches.append(new_switch)
			create_switch_connections(new_switch)
	
	# Emit signal for player repositioning
	level_changed.emit(Vector2i(level_data.player_start[0], level_data.player_start[1]))

func is_wall(grid_position: Vector2i) -> bool:
	var data = tile_map_layer.get_cell_tile_data(grid_position)
	return data != null && data.get_custom_data("wall")

func is_hole(grid_position: Vector2i) -> bool:
	var data = tile_map_layer.get_cell_tile_data(grid_position)
	return data != null && data.get_custom_data("hole")

func is_ladder(grid_position: Vector2i) -> bool:
	var data = tile_map_layer.get_cell_tile_data(grid_position)
	return data != null && data.get_custom_data("ladder")

func is_valid_move(grid_position: Vector2i) -> bool:
	if is_hole(grid_position):
		player_blocked_by_hole.emit()
	return !is_wall(grid_position) && !is_hole(grid_position)

func is_switch(grid_position: Vector2i) -> bool:
	var data = tile_map_layer.get_cell_tile_data(grid_position)
	var switch_found = data != null && data.get_custom_data("switch")
	if switch_found:
		player_reached_switch.emit()
	return switch_found

func clear_switch_connections():
	for connection in switch_connections:
		connection.queue_free()
	switch_connections.clear()
	
	for overlay in switch_overlays:
		overlay.queue_free()
	switch_overlays.clear()

func create_switch_connections(switch: Switch):
	var switch_world_pos = grid_to_world(switch.position)
	
	# Create switch overlay with a pulsing effect
	var switch_overlay = create_colored_overlay(switch.position, switch.color, true)
	switch_overlays.append(switch_overlay)
	
	for target_pos in switch.target_positions:
		var target_world_pos = grid_to_world(target_pos)
		
		# Create a more subtle connection line
		var connection = switch.create_connection(switch_world_pos, target_world_pos)
		add_child(connection)
		switch_connections.append(connection)
		
		# Create target overlay with a subtle pulsing effect
		var target_overlay = create_colored_overlay(target_pos, switch.color, false)
		switch_overlays.append(target_overlay)

func create_colored_overlay(grid_pos: Vector2i, color: Color, is_switch: bool = false) -> Sprite2D:
	var overlay = Sprite2D.new()
	var tile_set_source = tile_map_layer.tile_set.get_source(TILE_SOURCE_ID)
	overlay.texture = tile_set_source.texture
	overlay.region_enabled = true
	overlay.region_rect = Rect2(Vector2(0, 4) * Vector2(17, 17), Vector2(16, 16))
	
	# Different visual treatment for switches vs targets
	var overlay_color = color
	if is_switch:
		# Make switch overlay more prominent
		overlay_color = color.lightened(0.3)
		overlay_color.a = 0.5
		
		# Add pulsing animation for switch
		var tween = create_tween()
		tween.set_loops()  # Make it repeat
		tween.tween_property(overlay, "modulate:a", 0.7, 1.0)
		tween.tween_property(overlay, "modulate:a", 0.3, 1.0)
	else:
		# Make target overlay more subtle
		overlay_color = color.darkened(0.2)
		overlay_color.a = 0.2
		
		# Add subtle breathing animation for targets
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(overlay, "modulate:a", 0.3, 1.5)
		tween.tween_property(overlay, "modulate:a", 0.1, 1.5)
	
	overlay.modulate = overlay_color
	overlay.position = grid_to_world(grid_pos)
	overlay.z_index = 1  # Draw on top of tiles
	add_child(overlay)
	return overlay

func toggle_switch(grid_pos: Vector2i) -> void:
	for switch in active_switches:
		if switch.position == grid_pos:
			switch.is_pressed = !switch.is_pressed
			print("[GridManager] Switch at ", grid_pos, " pressed. New state: ", switch.is_pressed)
			
			# Update switch appearance
			var atlas_coords = SWITCH_ON_COORDS if switch.is_pressed else SWITCH_OFF_COORDS
			tile_map_layer.set_cell(grid_pos, TILE_SOURCE_ID, atlas_coords)
			
			# Find and pulse all connections for this switch
			var switch_world_pos = grid_to_world(grid_pos)
			for connection in switch_connections:
				if connection.start_pos == switch_world_pos:
					connection.pulse()
			
			# Get the next type once for all targets
			var first_target = switch.target_positions[0]
			var first_target_data = tile_map_layer.get_cell_tile_data(first_target)
			var current_type
			if first_target_data:
				if first_target_data.get_custom_data("wall"): current_type = WALL_TYPE
				elif first_target_data.get_custom_data("hole"): current_type = HOLE_TYPE
				elif first_target_data.get_custom_data("ladder"): current_type = LADDER_TYPE
				else: current_type = FLOOR_TYPE
			
			print("[GridManager] First target at ", first_target, " current type: ", current_type)
			var next_type = switch.get_next_tile_type(current_type)
			print("[GridManager] All targets changing to type: ", next_type)
			
			# Toggle each target tile with the switch's color using the same next_type
			for target_pos in switch.target_positions:
				# Set the new tile type based on the next type
				var new_atlas_coords
				match next_type:
					WALL_TYPE: new_atlas_coords = WALL_COORDS
					FLOOR_TYPE: new_atlas_coords = FLOOR_COORDS
					HOLE_TYPE: new_atlas_coords = HOLE_COORDS
					LADDER_TYPE: new_atlas_coords = LADDER_COORDS
				
				tile_map_layer.set_cell(target_pos, TILE_SOURCE_ID, new_atlas_coords)
				
				# Add visual effect to the affected tile using the switch's color
				create_tile_toggle_effect(target_pos, switch.color)

func create_tile_toggle_effect(pos: Vector2i, effect_color: Color) -> void:
	# Create a temporary sprite for the effect
	var effect_sprite = Sprite2D.new()
	var tile_set_source = tile_map_layer.tile_set.get_source(TILE_SOURCE_ID)
	
	effect_sprite.texture = tile_set_source.texture
	effect_sprite.region_enabled = true
	
	# Get the atlas coordinates for the tile
	var atlas_coords = tile_map_layer.get_cell_atlas_coords(pos)
	
	# Set the region rect using the atlas coordinates
	effect_sprite.region_rect = Rect2(
		atlas_coords * (CELL_SIZE + 1),  # Add 1 for potential tile separation
		Vector2(CELL_SIZE, CELL_SIZE)
	)
	
	# Position the effect sprite
	effect_sprite.position = tile_map_layer.map_to_local(pos)
	effect_sprite.modulate = effect_color
	effect_sprite.z_index = 2  # Draw on top of everything
	add_child(effect_sprite)
	
	# Create a tween for the visual effect
	var tween = create_tween()
	
	# Scale and color effect
	tween.tween_property(effect_sprite, "scale", Vector2(1.5, 1.5), 0.1)
	var highlight_color = effect_color.lightened(0.5)
	highlight_color.a = 0.7  # Set alpha directly
	tween.parallel().tween_property(effect_sprite, "modulate", highlight_color, 0.1)
	tween.tween_property(effect_sprite, "scale", Vector2(1, 1), 0.1)
	tween.parallel().tween_property(effect_sprite, "modulate", effect_color, 0.1)
	
	# Remove the sprite after the effect
	tween.tween_callback(func(): effect_sprite.queue_free())

func grid_to_world(grid_position: Vector2i) -> Vector2:
	# Convert grid position to world position using TileMap's conversion
	return tile_map_layer.map_to_local(grid_position)

func world_to_grid(world_position: Vector2) -> Vector2i:
	return tile_map_layer.local_to_map(world_position)

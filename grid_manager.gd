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
var level_manager: LevelManager = LevelManager.new()

@export var player_scene: PackedScene  # Add this to reference the Player scene
var player: Player  # Store reference to the player instance
var active_switches: Array[LevelManager.Switch] = []

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
	var level_data = level_manager.load_level(level_manager.current_level)
	if level_data.is_empty():
		return
		
	# Set move/jump limits for this level
	if level_data.has("max_moves") and level_data.has("max_jumps"):
		GameManager.set_level_limits(level_data.max_moves, level_data.max_jumps)
	
	# Clear existing tiles
	var used_cells = tile_map_layer.get_used_cells()
	for cell in used_cells:
		tile_map_layer.erase_cell(cell)
		
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
		player.position = grid_to_world(level_data.player_start)
	
	# Load switches
	active_switches.clear()
	if level_data.has("switches"):
		for switch_data in level_data.switches:
			var new_switch = LevelManager.Switch.new(switch_data.pos, switch_data.target)
			active_switches.append(new_switch)
	
	# Emit signal for player repositioning after tiles are loaded
	level_changed.emit(level_data.player_start)

func clear_tiles() -> void:
	var used_cells = tile_map_layer.get_used_cells()
	for cell in used_cells:
		tile_map_layer.erase_cell(cell)

func load_next_level():
	var level_data = level_manager.next_level()
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
			var new_switch = LevelManager.Switch.new(switch_data.pos, switch_data.target)
			active_switches.append(new_switch)
	
	# Emit signal for player repositioning
	level_changed.emit(level_data.player_start)

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

func toggle_switch(grid_pos: Vector2i) -> void:
	for switch in active_switches:
		if switch.position == grid_pos:
			switch.is_pressed = !switch.is_pressed
			
			# Update switch appearance
			var atlas_coords = SWITCH_ON_COORDS if switch.is_pressed else SWITCH_OFF_COORDS
			tile_map_layer.set_cell(grid_pos, TILE_SOURCE_ID, atlas_coords)
			
			# Toggle target tile (wall <-> floor)
			var target_data = tile_map_layer.get_cell_tile_data(switch.target_pos)
			if target_data && target_data.get_custom_data("wall"):
				tile_map_layer.set_cell(switch.target_pos, TILE_SOURCE_ID, FLOOR_COORDS)
			else:
				tile_map_layer.set_cell(switch.target_pos, TILE_SOURCE_ID, WALL_COORDS)

func grid_to_world(grid_position: Vector2i) -> Vector2:
	# Convert grid position to world position using TileMap's conversion
	return tile_map_layer.map_to_local(grid_position)

func world_to_grid(world_position: Vector2) -> Vector2i:
	return tile_map_layer.local_to_map(world_position)

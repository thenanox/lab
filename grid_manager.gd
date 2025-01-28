extends Node2D
class_name GridManager

signal level_completed
signal level_changed(new_start_pos: Vector2i)
signal player_blocked_by_hole

const CELL_SIZE := 16
const SPRITE_SIZE := 16

# Constants for tile types - these should match your level data format
const WALL_TYPE := 0
const FLOOR_TYPE := 1
const HOLE_TYPE := 2
const LADDER_TYPE := 3

# Constants for tile atlas coordinates in the tileset
const WALL_COORDS := Vector2i(0, 3)
const FLOOR_COORDS := Vector2i(0, 4)
const HOLE_COORDS := Vector2i(9, 0)
const LADDER_COORDS := Vector2i(8, 5)
const TILE_SOURCE_ID := 0

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
var level_manager: LevelManager = LevelManager.new()

@export var player_scene: PackedScene  # Add this to reference the Player scene
var player: Player  # Store reference to the player instance

func _ready():
	if !tile_map_layer:
		print("ERROR: TileMapLayer not found!")
		return
	
	if !player_scene:
		push_error("Player scene not set in GridManager!")
		return
		
	load_current_level()

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
		
		tile_map_layer.set_cell(pos, TILE_SOURCE_ID, atlas_coords)
	
	# Create player if it doesn't exist
	if !player:
		player = player_scene.instantiate() as Player
		player.grid_manager = self
		add_child(player)
		# Set initial position immediately after creation
		player.position = grid_to_world(level_data.player_start)
	
	# Emit signal for player repositioning after tiles are loaded
	level_changed.emit(level_data.player_start)

func load_next_level():
	var level_data = level_manager.next_level()
	if level_data.is_empty():
		GameManager.on_game_completed()
		# Clear all tiles
		var used_cells = tile_map_layer.get_used_cells()
		for cell in used_cells:
			tile_map_layer.erase_cell(cell)
		# Remove player last
		if player:
			player.queue_free()
			player = null
		return
		
	# Set move/jump limits for this level
	if level_data.has("max_moves") and level_data.has("max_jumps"):
		GameManager.set_level_limits(level_data.max_moves, level_data.max_jumps)
	
	# Load tile data
	tile_map_layer.tile_map_data = level_data.tile_data
	
	# Emit signal for player repositioning
	level_changed.emit(level_data.player_start)

func is_wall(grid_position: Vector2i) -> bool:
	var data = tile_map_layer.get_cell_tile_data(grid_position)
	print("Checking wall at:", grid_position, " Data:", data)
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

func grid_to_world(grid_position: Vector2i) -> Vector2:
	# Convert grid position to world position using TileMap's conversion
	return tile_map_layer.map_to_local(grid_position)

func world_to_grid(world_position: Vector2) -> Vector2i:
	return tile_map_layer.local_to_map(world_position)

func print_current_level_data():
	if !tile_map_layer:
		return
		
	print("\nLevel Data:")
	print("{")
	print('    "tile_data": [')
	
	var used_cells = tile_map_layer.get_used_cells()
	for cell in used_cells:
		var tile_atlas = tile_map_layer.get_cell_atlas_coords(cell)
		var tile_alternative = tile_map_layer.get_cell_alternative_tile(cell)
		
		# Determine tile type based on atlas coordinates
		var tile_type
		var type_name
		match tile_atlas:
			WALL_COORDS: 
				tile_type = WALL_TYPE
				type_name = "Wall"
			FLOOR_COORDS: 
				tile_type = FLOOR_TYPE
				type_name = "Floor"
			HOLE_COORDS: 
				tile_type = HOLE_TYPE
				type_name = "Hole"
			LADDER_COORDS: 
				tile_type = LADDER_TYPE
				type_name = "Ladder"
			_: 
				tile_type = -1
				type_name = "Unknown"
		
		print('        [%d, %d, %d, %d],  # %s (type %d)' % [
			cell.x, 
			cell.y, 
			tile_type,
			tile_alternative,
			type_name,
			tile_type
		])
	
	print('    ],')
	print('    "player_start": Vector2i(%d, %d)' % [
		tile_map_layer.get_used_rect().position.x,
		tile_map_layer.get_used_rect().position.y
	])
	print("}")

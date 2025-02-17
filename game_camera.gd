extends Camera2D

@onready var tile_map_layer: TileMapLayer = $"../TileMapLayer"
@onready var grid_manager: GridManager = get_parent()

func _ready():
	# Get the level size from TileMapLayer
	var used_cells = tile_map_layer.get_used_cells()
	
	if used_cells.is_empty():
		return
		
	zoom = Vector2(2, 2)
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0

func _process(_delta):
	if grid_manager.player:
		# Update camera position to match player position
		position = grid_manager.player.position

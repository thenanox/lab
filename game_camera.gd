extends Camera2D

@onready var tile_map_layer: TileMapLayer = $"../TileMapLayer"
@onready var grid_manager: GridManager = get_parent()

func _ready():
	# Get the level size from TileMapLayer
	var used_cells = tile_map_layer.get_used_cells()
	
	if used_cells.is_empty():
		return
		
	# Calculate bounds
	var min_pos = Vector2i(INF, INF)
	var max_pos = Vector2i(-INF, -INF)
	
	for cell in used_cells:
		min_pos.x = min(min_pos.x, cell.x)
		min_pos.y = min(min_pos.y, cell.y)
		max_pos.x = max(max_pos.x, cell.x)
		max_pos.y = max(max_pos.y, cell.y)
	
	# Calculate level dimensions in pixels
	var level_size = (max_pos - min_pos + Vector2i.ONE) * 16
	
	zoom = Vector2(2, 2)
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0

func _process(_delta):
	if grid_manager.player:
		position = grid_manager.player.position

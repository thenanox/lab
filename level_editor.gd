extends Node2D

var level_number := 1  # Default value, will be set from menu
var moves := 0
var jumps := 0

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
var level_manager: LevelManager = LevelManager.new()
var preview_player: Sprite2D

func _ready():
	create_ui()
	create_preview_player()
	load_level()

func set_level(num: int):
	level_number = num

func create_ui():
	var ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	
	var moves_label = Label.new()
	moves_label.name = "MovesLabel"
	moves_label.position = Vector2(20, 20)
	moves_label.add_theme_font_size_override("font_size", 32)
	moves_label.text = "Moves: %d" % moves
	ui.add_child(moves_label)
	
	var jumps_label = Label.new()
	jumps_label.name = "JumpsLabel"
	jumps_label.position = Vector2(20, 70)
	jumps_label.add_theme_font_size_override("font_size", 32)
	jumps_label.text = "Jumps: %d" % jumps
	ui.add_child(jumps_label)

func create_preview_player():
	preview_player = Sprite2D.new()
	preview_player.texture = preload("res://sprites/player.png")  # Same sprite as player
	preview_player.modulate = Color(1, 1, 1, 0.5)  # Semi-transparent
	add_child(preview_player)

func load_level():
	var level_data = level_manager.load_level(level_number)
	if level_data.is_empty():
		return
		
	# Update moves and jumps from level data
	moves = level_data.max_moves
	jumps = level_data.max_jumps
	
	# Update UI
	get_node("UI/MovesLabel").text = "Moves: %d" % moves
	get_node("UI/JumpsLabel").text = "Jumps: %d" % jumps
	
	# Clear existing tiles
	var used_cells = tile_map_layer.get_used_cells()
	for cell in used_cells:
		tile_map_layer.erase_cell(cell)
		
	# Load tile data
	for cell_data in level_data.tile_data:
		var pos = Vector2i(cell_data[0], cell_data[1])
		var tile_type = cell_data[2]
		var atlas_coords
		
		match tile_type:
			GridManager.WALL_TYPE: atlas_coords = GridManager.WALL_COORDS
			GridManager.FLOOR_TYPE: atlas_coords = GridManager.FLOOR_COORDS
			GridManager.HOLE_TYPE: atlas_coords = GridManager.HOLE_COORDS
			GridManager.LADDER_TYPE: atlas_coords = GridManager.LADDER_COORDS
			GridManager.SWITCH_TYPE: atlas_coords = GridManager.SWITCH_OFF_COORDS
		
		tile_map_layer.set_cell(pos, GridManager.TILE_SOURCE_ID, atlas_coords)
	
	# Position preview player
	var start_pos = level_data.player_start
	preview_player.position = tile_map_layer.map_to_local(start_pos)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		# Clean up current scene
		preview_player.queue_free()
		get_node("UI").queue_free()  # Clean up editor UI
		GameManager.hide_ui()  # Hide GameManager UI
		queue_free()
		get_tree().change_scene_to_file("res://menu.tscn") 

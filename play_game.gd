extends Node2D
class_name PlayGame

@export var current_level: int = 1
@onready var grid_manager: GridManager = $GridManager

func _ready():
	print("[PlayGame] Starting level: ", current_level)
	LevelManager.current_level = current_level  # Set the current level in LevelManager
	var level_data = LevelManager.load_level(current_level)
	print("[PlayGame] Level data loaded: ", level_data)
	if level_data.has("switches"):
		print("[PlayGame] Switches found: ", level_data.switches)
		for switch in level_data.switches:
			print("[PlayGame] Switch color: ", switch.get("color", "#ffff00"))
	
	# Let GridManager handle the level loading
	grid_manager.load_current_level()

func _process(_delta: float) -> void:
	pass


extends Node2D
class_name PlayGame

@export var current_level: int = 1
@onready var grid_manager: GridManager = $GridManager

func _ready():
	grid_manager.set_current_level(current_level)

func _process(_delta: float) -> void:
	pass


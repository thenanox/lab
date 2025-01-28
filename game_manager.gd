extends Node

var max_moves := 1  # Default value
var max_jumps := 1   # Default value
var current_moves: int
var current_jumps: int

var moves_label: Label
var jumps_label: Label
var tooltip_label: Label
var restart_button: Button
var ui: CanvasLayer

func _ready():
	# Create UI
	ui = CanvasLayer.new()
	add_child(ui)
	
	moves_label = Label.new()
	moves_label.position = Vector2(20, 20)
	moves_label.add_theme_font_size_override("font_size", 32)
	ui.add_child(moves_label)
	
	jumps_label = Label.new()
	jumps_label.position = Vector2(20, 70)
	jumps_label.add_theme_font_size_override("font_size", 32)
	ui.add_child(jumps_label)
	
	tooltip_label = Label.new()
	tooltip_label.position = Vector2(20, 120)
	tooltip_label.size = Vector2(400, 100)
	tooltip_label.add_theme_font_size_override("font_size", 24)
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(tooltip_label)
	
	restart_button = Button.new()
	restart_button.text = "Restart Game"
	restart_button.custom_minimum_size = Vector2(200, 50)
	restart_button.hide()  # Hide initially
	restart_button.pressed.connect(restart_game)
	ui.add_child(restart_button)
	
	# Center the button
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	
	reset_actions()

func set_level_limits(moves: int, jumps: int) -> void:
	max_moves = moves
	max_jumps = jumps
	reset_actions()

func reset_actions():
	current_moves = max_moves
	current_jumps = max_jumps
	update_ui()

func _on_player_moved():
	current_moves -= 1
	update_ui()
	check_game_over()

func _on_player_jumped():
	current_jumps -= 1
	current_moves -= 1
	update_ui()
	check_game_over()

func update_ui():
	if moves_label and jumps_label:
		moves_label.text = "Moves: %d" % current_moves
		jumps_label.text = "Jumps: %d" % current_jumps

func show_tooltip(text: String, duration: float = 4.0, show_restart: bool = false) -> void:
	tooltip_label.text = text
	if !show_restart:
		var tween = create_tween()
		tween.tween_interval(duration)
		tween.tween_callback(func(): tooltip_label.text = "")
	restart_button.visible = show_restart

func check_game_over():
	if current_moves <= 0:
		show_tooltip("No moves left! Hold R and press LEFT to rewind your moves.\nThen try a different approach...")

func _on_player_blocked_by_hole():
	show_tooltip("Hold SPACE and press a direction key to jump over holes!")

func restart_game() -> void:
	# Show UI elements again
	moves_label.show()
	jumps_label.show()
	tooltip_label.position = Vector2(20, 120)  # Reset tooltip position
	
	var level_manager = get_tree().get_first_node_in_group("grid_manager").level_manager
	level_manager.current_level = 1
	get_tree().reload_current_scene()
	tooltip_label.text = ""
	restart_button.hide()

func _on_viewport_size_changed() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	restart_button.position = Vector2(
		(viewport_size.x - restart_button.size.x) / 2,
		(viewport_size.y - restart_button.size.y) / 2 + 50  # 50 pixels below center
	)

func on_game_completed() -> void:
	# Hide UI elements
	moves_label.hide()
	jumps_label.hide()
	
	# Center and show completion message and button
	var viewport_size = get_viewport().get_visible_rect().size
	tooltip_label.position = Vector2(
		(viewport_size.x - tooltip_label.size.x) / 2,
		(viewport_size.y - tooltip_label.size.y) / 2 - 50
	)
	show_tooltip("Congratulations! You've completed all levels!\nClick Restart to play again!", 0.0, true)

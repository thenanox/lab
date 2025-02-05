extends Node

var max_moves := 1  # Default value
var max_jumps := 1   # Default value
var current_moves: int
var current_jumps: int

var moves_label: Label
var jumps_label: Label
var tooltip_label: Label
var ui: CanvasLayer

func _ready():
	# Create UI
	ui = CanvasLayer.new()
	add_child(ui)
	
	moves_label = Label.new()
	moves_label.position = Vector2(20, 20)
	moves_label.add_theme_font_size_override("font_size", 32)
	moves_label.hide()  # Hide initially
	ui.add_child(moves_label)
	
	jumps_label = Label.new()
	jumps_label.position = Vector2(20, 70)
	jumps_label.add_theme_font_size_override("font_size", 32)
	jumps_label.hide()  # Hide initially
	ui.add_child(jumps_label)
	
	tooltip_label = Label.new()
	tooltip_label.position = Vector2(20, 120)
	tooltip_label.size = Vector2(400, 100)
	tooltip_label.add_theme_font_size_override("font_size", 24)
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(tooltip_label)
	
	reset_actions()

func _on_player_moved():
	current_moves -= 1
	update_ui()
	check_game_over()

func _on_player_jumped():
	current_jumps -= 1
	update_ui()
	check_game_over()

func _on_player_blocked_by_hole():
	if LevelManager.current_level == 1:
		show_tooltip("Hold SPACE and press a direction key to jump over holes!")

func set_level_limits(moves: int, jumps: int) -> void:
	max_moves = moves
	max_jumps = jumps
	reset_actions()
	moves_label.show()  # Show labels when game starts
	jumps_label.show()

func reset_actions():
	current_moves = max_moves
	current_jumps = max_jumps
	update_ui()

func update_ui():
	if moves_label and jumps_label:
		moves_label.text = "Moves: %d" % current_moves
		jumps_label.text = "Jumps: %d" % current_jumps

func show_tooltip(text: String, duration: float = 4.0) -> void:
	tooltip_label.text = text
	if duration > 0:
		var tween = create_tween()
		tween.tween_interval(duration)
		tween.tween_callback(func(): 
			if duration > 0:
				tooltip_label.text = ""
		)

func check_game_over():
	if current_moves <= 0 && LevelManager.current_level == 1:
		show_tooltip("No moves left! Hold R and press LEFT to rewind your moves.\nThen try a different approach...")

func on_game_completed() -> void:
	# Hide UI elements
	moves_label.hide()
	jumps_label.hide()
	
	# Center and show completion message
	var viewport_size = get_viewport().get_visible_rect().size
	tooltip_label.position = Vector2(
		(viewport_size.x - tooltip_label.size.x) / 2,
		(viewport_size.y - tooltip_label.size.y) / 2 - 50
	)

	show_tooltip("Congratulations! You've completed all levels!\nPress ESC to return to Main Menu", 10.0)

func hide_ui():
	if moves_label:
		moves_label.hide()
	if jumps_label:
		jumps_label.hide()
	if tooltip_label:
		tooltip_label.text = ""

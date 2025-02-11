extends Control

var selected_button := 0
var buttons: Array[Button] = []
var label_background: ColorRect
var input_container: Control  # New container for input elements

func _ready():
	# Set window size and mode
	get_window().size = Vector2i(1920, 1080)
	get_window().mode = Window.MODE_MAXIMIZED
	
	# Explicitly add buttons in the desired order
	var play_button = $CenterContainer/VBoxContainer/PlayButton
	var editor_button = $CenterContainer/VBoxContainer/EditorButton
	var quit_button = $CenterContainer/VBoxContainer/QuitButton
	
	buttons.append(play_button)
	buttons.append(editor_button)
	buttons.append(quit_button)
	
	# Disable default focus navigation for these buttons
	for button in buttons:
		button.focus_mode = Control.FOCUS_CLICK
	
	# Create a Control node as container for input elements
	input_container = Control.new()
	input_container.set_anchors_preset(Control.PRESET_CENTER)
	input_container.position = Vector2(0, -100)  # Position above buttons
	
	# Create background
	label_background = ColorRect.new()
	label_background.color = Color(0, 0, 0, 0.5)
	label_background.custom_minimum_size = Vector2(300, 50)
	label_background.position = Vector2(-150, 0)  # Center horizontally
	
	# Add elements to container
	input_container.add_child(label_background)

	# Add container to scene
	$CenterContainer/VBoxContainer.add_child(input_container)
	
	# Hide input elements initially
	label_background.hide()

	# Set initial selection
	update_selection()

func _input(event: InputEvent):
	# Block all mouse input
	if event is InputEventMouse:
		get_viewport().set_input_as_handled()
		return

func _unhandled_input(event: InputEvent):
	# Handle arrow key navigation
	if event.is_action_pressed("ui_down"):
		selected_button = (selected_button + 1) % buttons.size()
		update_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		selected_button = (selected_button - 1) if selected_button > 0 else buttons.size() - 1
		update_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		match selected_button:
			0: open_play_game()
			1: open_level_designer()
			2: quit_game()
		get_viewport().set_input_as_handled()

func update_selection():
	for i in range(buttons.size()):
		if i == selected_button:
			buttons[i].grab_focus()
		else:
			buttons[i].release_focus()

func open_play_game():
	# Create a file dialog to select level
	var file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	
	# Use an absolute path to the project's data directory
	var data_dir = ProjectSettings.globalize_path("res://data/")
	file_dialog.current_dir = data_dir
	file_dialog.add_filter("*.json", "Level Files")
	
	# Set a larger initial size for the dialog
	file_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	file_dialog.size = Vector2i(800, 600)
	file_dialog.title = "Select Level to Play"
	
	file_dialog.file_selected.connect(func(path):
		# Extract level number from filename
		var filename = path.get_file()
		if filename.begins_with("level") and filename.ends_with(".json"):
			var level_num = int(filename.trim_suffix(".json").trim_prefix("level"))
			load_play_game(level_num)
		else:
			show_error("Invalid level file name. Must be in format 'level<number>.json'")
	)
	
	add_child(file_dialog)
	file_dialog.popup_centered()

func load_play_game(level_num: int):
	LevelManager.current_level = level_num
	var game_scene = load("res://play_game.tscn") as PackedScene
	var game_instance = game_scene.instantiate()
	get_tree().root.call_deferred("add_child", game_instance)
	queue_free()

func open_level_designer():
	var level_designer_scene = load("res://level_designer.tscn") as PackedScene
	var level_designer_instance = level_designer_scene.instantiate()
	get_tree().root.call_deferred("add_child", level_designer_instance)
	queue_free()

func quit_game():
	get_tree().quit()

func show_error(text: String):
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = text
	add_child(error_dialog)
	error_dialog.popup_centered() 

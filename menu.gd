extends Control

var selected_button := 0
var buttons: Array[Button] = []
var input_mode := false
var level_input := "1"  # Prefill with 1
var is_editor := false
var input_label: Label
var label_background: ColorRect
var input_container: Control  # New container for input elements

func _ready():
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
	
	# Create input label
	input_label = Label.new()
	input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	input_label.custom_minimum_size = Vector2(300, 50)  # Match background size
	input_label.position = Vector2(-150, 0)  # Match background position
	input_label.add_theme_font_size_override("font_size", 32)
	input_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Add elements to container
	input_container.add_child(label_background)
	input_container.add_child(input_label)
	
	# Add container to scene
	$CenterContainer/VBoxContainer.add_child(input_container)
	
	# Hide input elements initially
	input_label.hide()
	label_background.hide()
	
	# Set initial selection
	update_selection()

func _input(event: InputEvent):
	# Block all mouse input
	if event is InputEventMouse:
		get_viewport().set_input_as_handled()
		return

func _unhandled_input(event: InputEvent):
	if input_mode:
		if event.is_action_pressed("ui_cancel"):
			input_mode = false
			level_input = "1"  # Reset to 1 when canceling
			input_label.hide()
			label_background.hide()  # Use direct reference
			return
		
		# Handle level input navigation
		if event.is_action_pressed("ui_right"):
			# Increment level, no upper limit specified
			level_input = str(int(level_input) + 1)
			input_label.text = "Enter Level: " + level_input
		elif event.is_action_pressed("ui_left"):
			# Decrement level, but not below 1
			var current_level = int(level_input)
			if current_level > 1:
				level_input = str(current_level - 1)
				input_label.text = "Enter Level: " + level_input
		
		# Only allow enter to load the level
		if event.is_action_pressed("ui_accept"):
			load_level(int(level_input))
		
		return
	
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
			0:  # Play Game
				start_level_input(false)
			1:  # Level Editor
				start_level_input(true)
			2:  # Quit Game
				quit_game()
		get_viewport().set_input_as_handled()


func update_selection():
	for i in range(buttons.size()):
		if i == selected_button:
			buttons[i].grab_focus()
		else:
			buttons[i].release_focus()

func start_level_input(editor: bool):
	input_mode = true
	is_editor = editor
	level_input = "1"
	input_label.text = "Enter Level: " + level_input
	label_background.show()
	input_label.show()
	buttons[selected_button].grab_focus()

func load_level(level_num: int):
	if level_num <= 0:
		show_error("Invalid level number!")
		return
		
	var temp_manager = LevelManager.new()
	var level_data = temp_manager.load_level(level_num)
	if level_data.is_empty():
		show_error("Level %d does not exist!" % level_num)
		return
		
	if is_editor:
		var editor_scene = load("res://level_editor.tscn") as PackedScene
		var editor_instance = editor_scene.instantiate()
		editor_instance.set_level(level_num)
		get_tree().root.call_deferred("add_child", editor_instance)
	else:
		var game_scene = load("res://main.tscn") as PackedScene
		var game_instance = game_scene.instantiate()
		var grid_manager = game_instance.get_node("GridManager")
		grid_manager.level_manager.current_level = level_num
		get_tree().root.call_deferred("add_child", game_instance)
	queue_free()

func quit_game():
	get_tree().quit()

func show_error(text: String):
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = text
	add_child(error_dialog)
	error_dialog.popup_centered() 

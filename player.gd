extends CharacterBody2D
class_name Player

signal moved
signal jumped

class HistoryEntry:
	var grid_pos: Vector2i
	var holes_jumped: int 
	var direction: Vector2i
	
	func _init(pos: Vector2i, holes: int, dir: Vector2i):
		grid_pos = pos
		holes_jumped = holes
		direction = dir

var move_history: Array[HistoryEntry] = []
var rewind_buffer: Array[HistoryEntry] = []
var is_moving := false
var is_rewinding := false
var grid_position: Vector2i

var grid_manager: GridManager
var trail_marker_scene: PackedScene  # Reference to the trail marker scene
var trail_markers: Array[Sprite2D] = []

func _ready():
	if !grid_manager:
		push_error("Player needs a GridManager reference! Set it in the inspector!")
		return
	
	# Connect signals to GameManager
	moved.connect(GameManager._on_player_moved)
	jumped.connect(GameManager._on_player_jumped)
	grid_manager.level_changed.connect(_on_level_changed)
	grid_manager.player_blocked_by_hole.connect(func(): GameManager._on_player_blocked_by_hole())

func _unhandled_input(event: InputEvent) -> void:
	# Allow rewind even when out of moves
	if is_moving:
		return
	
	# Handle rewind mode
	if Input.is_action_just_pressed("rewind"):
		is_rewinding = true
		return
	elif Input.is_action_just_released("rewind"):
		is_rewinding = false
		rewind_buffer.clear()
		clear_trail()  # Clear trail when exiting rewind mode
		return
		
	if is_rewinding:
		if event.is_action_pressed("move_left"):
			try_rewind()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_right"):
			try_forward()
			get_viewport().set_input_as_handled()
		return
	
	# Normal movement handling
	var direction := Vector2i.ZERO
	
	if event.is_action_pressed("move_right"): 
		direction = Vector2i.RIGHT
	elif event.is_action_pressed("move_left"): 
		direction = Vector2i.LEFT
	elif event.is_action_pressed("move_up"): 
		direction = Vector2i.UP
	elif event.is_action_pressed("move_down"): 
		direction = Vector2i.DOWN
	
	if direction != Vector2i.ZERO:
		if Input.is_action_pressed("jump"):
			try_jump(direction)
		else:
			try_move(direction)
		get_viewport().set_input_as_handled()

func _on_level_changed(new_start_pos: Vector2i):
	grid_position = new_start_pos
	# Update the actual position immediately
	position = grid_manager.grid_to_world(grid_position)
	is_moving = false

func try_move(direction: Vector2i) -> void:
	if is_moving:
		return
	
	if GameManager.current_moves <= 0:
		return
		
	var target_pos = grid_position + direction
	if grid_manager.is_valid_move(target_pos):
		is_moving = true
		move_history.append(HistoryEntry.new(grid_position, 0, direction))
		grid_position = target_pos
		position = grid_manager.grid_to_world(grid_position)
		moved.emit()
		
		# Check for switch
		if grid_manager.is_switch(grid_position):
			grid_manager.toggle_switch(grid_position)
		
		if grid_manager.is_ladder(grid_position):
			grid_manager.load_next_level()
			move_history.clear()
			
		is_moving = false

func try_jump(direction: Vector2i) -> void:
	if is_moving:
		return
		
	if GameManager.current_jumps <= 0:
		return
		
	# Count how many consecutive holes we can jump
	var holes_count := 0
	var max_holes := GameManager.current_jumps  # Limit by available jumps
	var current_pos := grid_position
	var target_pos := grid_position
	
	var can_jump := false
	# Check consecutive holes
	while holes_count < max_holes:
		var next_pos = current_pos + direction
		var landing_pos = next_pos + direction
		
		# Check if next position is a hole
		if grid_manager.is_hole(next_pos):
			holes_count += 1
			if !grid_manager.is_valid_move(landing_pos):
				current_pos = next_pos
			else:
				target_pos = landing_pos
				can_jump = true
				break
		else:
			holes_count = 0
			break
	
	if can_jump:
		is_moving = true
		move_history.append(HistoryEntry.new(grid_position, holes_count, direction))
		grid_position = target_pos
		position = grid_manager.grid_to_world(grid_position)
		
		# Emit jumped signal for each hole jumped
		for i in range(holes_count):
			jumped.emit()
		
		is_moving = false

func try_rewind() -> void:
	if is_moving or move_history.is_empty():
		return
		
	is_moving = true
	var last_move = move_history.pop_back()
	if !grid_manager.is_valid_move(last_move.grid_pos):
		move_history.push_back(last_move)
		is_moving = false
		return
		
	rewind_buffer.push_back(last_move)
	
	# Create trail marker at current position before moving
	create_trail_marker(position)
	
	grid_position = last_move.grid_pos
	position = grid_manager.grid_to_world(grid_position)
	
	# Recover jumps based on holes jumped
	if last_move.holes_jumped > 0:
		GameManager.current_jumps += last_move.holes_jumped
	else:
		GameManager.current_moves += 1

	GameManager.update_ui()
	is_moving = false

func try_forward() -> void:
	if is_moving or rewind_buffer.is_empty():
		return
		
	is_moving = true
	var next_move = rewind_buffer.pop_back()
	move_history.push_back(next_move)
	
	var target_pos
	if next_move.holes_jumped > 0:
		target_pos = grid_position + (next_move.direction * (next_move.holes_jumped +1))
	else:
		target_pos = grid_position + next_move.direction	
	
	grid_position = target_pos
	position = grid_manager.grid_to_world(grid_position)
	
	# Remove last trail marker when moving forward
	if !trail_markers.is_empty():
		var last_marker = trail_markers.pop_back()
		last_marker.queue_free()
	
	if next_move.holes_jumped > 0:
		GameManager.current_jumps -= next_move.holes_jumped
	else:
		GameManager.current_moves -= 1
	
	GameManager.update_ui()
	is_moving = false

func create_trail_marker(pos: Vector2) -> void:
	# Check if there's already a marker at this position
	for marker in trail_markers:
		if marker.position == pos:
			# Reduce existing marker's opacity
			marker.modulate.a *= 0.5
			
	var marker = trail_marker_scene.instantiate() as Sprite2D
	get_parent().add_child(marker)
	marker.texture = $Sprite2D.texture
	marker.position = pos
	trail_markers.append(marker)

func clear_trail() -> void:
	for marker in trail_markers:
		marker.queue_free()
	trail_markers.clear()

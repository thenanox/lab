extends Node2D

class_name SwitchConnection

const LINE_COLOR = Color(0.8, 0.8, 0.2, 0.5)  # Semi-transparent yellow
const LINE_WIDTH = 2.0
const PULSE_DURATION = 1.0
const PULSE_INTENSITY = 0.3

var start_pos: Vector2
var end_pos: Vector2
var is_active: bool = false

func _init(from_pos: Vector2, to_pos: Vector2):
	start_pos = from_pos
	end_pos = to_pos
	z_index = -1  # Draw behind tiles

func _draw():
	var color = LINE_COLOR
	if is_active:
		color = color.lightened(PULSE_INTENSITY)
	draw_line(start_pos, end_pos, color, LINE_WIDTH)

func set_active(active: bool):
	is_active = active
	queue_redraw()

func pulse():
	var tween = create_tween()
	tween.tween_method(func(v: float): 
		is_active = v > 0.5
		queue_redraw()
	, 0.0, 1.0, PULSE_DURATION)
	tween.tween_method(func(v: float):
		is_active = v > 0.5
		queue_redraw()
	, 1.0, 0.0, PULSE_DURATION) 
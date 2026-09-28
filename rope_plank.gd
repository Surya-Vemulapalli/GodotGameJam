@tool
extends Node2D


# A plank held upright by a rope (sprite 8 on sprites/items.png). Its origin goes at the edge of a
# gap, level with the ground: the plank stands just past the edge, tied back by the rope. When
# Pyrazure's claw (or torpedo roll) breaks the rope ("breakable_claw"), the plank tips over away
# from the rope and lands flat across the gap, its top level with the ground, as a bridge.
const PLANK_REGION = Rect2(92, 70, 11, 45)
# Once it has fallen it's drawn with the plank lying flat (sprite 9 on sprites/items.png).
const FALLEN_REGION = Rect2(142, 106, 45, 11)
const ROPE_REGION = Rect2(75, 98, 17, 17)
const FALL_TIME = 0.5

# How long the plank is (how wide a gap it bridges once fallen) and how thick, in px. The rope
# is drawn in proportion to the plank's length, as in the art.
@export_range(45.0, 600.0, 1.0) var plank_length := 90.0:
	set(value):
		plank_length = value
		_update_look()
@export_range(6.0, 60.0, 1.0) var plank_thickness := 22.0:
	set(value):
		plank_thickness = value
		_update_look()
# Which way it falls (and which way the gap is): right, or left if off.
@export var falls_right := true:
	set(value):
		falls_right = value
		_update_look()

var fallen := false


func _ready() -> void:
	_update_look()
	if Engine.is_editor_hint():
		return
	$Rope.add_to_group("breakable_claw")


# Called when Pyrazure's claw hits the rope.
func claw_break() -> void:
	if fallen:
		return
	fallen = true
	$Rope.queue_free()
	var side := 1.0 if falls_right else -1.0
	var fall := create_tween()
	fall.tween_property($Plank, "rotation", side * PI / 2.0, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Landed: switch to the lying-flat art.
	await fall.finished
	_update_look()


func _update_look() -> void:
	var plank := get_node_or_null("Plank") as Node2D
	var rope := get_node_or_null("Rope") as Node2D
	if not plank:
		return
	var side := 1.0 if falls_right else -1.0
	var size := Vector2(plank_thickness, plank_length)
	var rope_scale := plank_length / PLANK_REGION.size.y
	# The plank's pivot is its bottom corner at the gap's edge (the origin); it stands upright
	# over the gap and falls onto its side across it.
	var plank_sprite: Sprite2D = plank.get_node("Sprite2D")
	if fallen:
		# Drawn level (undoing the plank's turn), lying across the gap.
		plank_sprite.region_rect = FALLEN_REGION
		plank_sprite.rotation = -side * PI / 2.0
		plank_sprite.scale = Vector2(size.y, size.x) / FALLEN_REGION.size
	else:
		plank_sprite.region_rect = PLANK_REGION
		plank_sprite.rotation = 0.0
		plank_sprite.scale = size / PLANK_REGION.size
	plank_sprite.flip_h = not falls_right
	plank_sprite.position = Vector2(side * size.x / 2.0, -size.y / 2.0)
	var plank_shape: CollisionShape2D = plank.get_node("CollisionShape2D")
	var rect := RectangleShape2D.new()
	rect.size = size
	plank_shape.shape = rect
	plank_shape.position = plank_sprite.position
	plank.rotation = side * PI / 2.0 if fallen else 0.0
	if not rope:
		return
	# The rope runs from the plank's side back down to the ground, away from the gap.
	var rope_size := ROPE_REGION.size * rope_scale
	var rope_sprite: Sprite2D = rope.get_node("Sprite2D")
	rope_sprite.region_rect = ROPE_REGION
	rope_sprite.scale = Vector2(rope_scale, rope_scale)
	rope_sprite.flip_h = not falls_right
	rope_sprite.position = Vector2(-side * rope_size.x / 2.0, -rope_size.y / 2.0)
	var rope_shape: CollisionShape2D = rope.get_node("CollisionShape2D")
	var rope_rect := RectangleShape2D.new()
	rope_rect.size = rope_size
	rope_shape.shape = rope_rect
	rope_shape.position = rope_sprite.position

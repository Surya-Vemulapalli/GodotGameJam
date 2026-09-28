@tool
class_name Lever
extends Node2D


# A lever Lobulux pulls (X next to it). Each pull flips it and switches every one of its
# `targets` (anything with toggle(), like a mechanized door). Its origin is the bottom of its
# base, on the ground; nothing collides with it.
const OFF_REGION = Rect2(256, 256, 64, 64)
const ON_REGION = Rect2(320, 256, 64, 64)
# The base's bottom is this far below the middle of the art.
const BASE_BOTTOM = 14.0

@export var on := false:
	set(value):
		on = value
		_update_look()
@export var targets: Array[Node] = []


func _ready() -> void:
	_update_look()
	if Engine.is_editor_hint():
		return
	add_to_group("lever")


func pull() -> void:
	on = not on
	for target in targets:
		if is_instance_valid(target) and target.has_method("toggle"):
			target.toggle()


func _update_look() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return
	sprite.region_rect = ON_REGION if on else OFF_REGION
	sprite.position = Vector2(0, -BASE_BOTTOM)

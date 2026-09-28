@tool
class_name Goblet
extends Area2D


# A goblet that Pyrazure lights with blue fire (red fire doesn't light it). Once lit it stays
# lit and opens every door in its `targets` (the flame doors). Its origin is the bottom of its
# foot, on the ground; nothing collides with it.
const UNLIT_REGION = Rect2(338, 203, 29, 50)
const LIT_REGION = Rect2(18, 256, 29, 61)

@export var lit := false:
	set(value):
		lit = value
		_update_look()
@export var targets: Array[Node] = []


func _ready() -> void:
	_update_look()
	if Engine.is_editor_hint():
		return
	add_to_group("goblet")
	# Notice fire (an area on collision layer 1) flying into it.
	collision_layer = 0
	collision_mask = 1
	area_entered.connect(_on_area_entered)


func light() -> void:
	if lit:
		return
	lit = true
	for target in targets:
		if is_instance_valid(target) and "open" in target:
			target.open = true


func _on_area_entered(area: Area2D) -> void:
	if area.get("blue"):
		light.call_deferred()


func _update_look() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return
	var region := LIT_REGION if lit else UNLIT_REGION
	sprite.region_rect = region
	sprite.position = Vector2(0, -region.size.y / 2.0)

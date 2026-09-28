@tool
extends Area2D


# A bridge machine (a "machine", sprite 21): sits on the ground at the edge of a hole, facing
# across it. Squadroshock switches it on (X next to it) and a bridge of planks (sprite 22)
# slides out, level with the ground, until it reaches the ground on the other side. Switched off,
# the bridge slides back in. Its origin is the bottom of the machine, on the ground; the machine
# itself doesn't block anyone.
const MACHINE_REGION = Rect2(136, 225, 29, 21)
const PLANK_REGION = Rect2(198, 228, 53, 5)
const BRIDGE_THICKNESS = 8.0
# How fast the bridge slides out and back (px per second).
const EXTEND_SPEED = 400.0
# How much the bridge overlaps the ground on the far side.
const FAR_OVERLAP = 8.0

# 1 facing (and building the bridge) to the right, -1 to the left.
@export_enum("right:1", "left:-1") var facing := 1:
	set(value):
		facing = value
		_update_look()
# The longest bridge it can make, in pixels.
@export var max_length := 640.0
@export var on := false

var length := 0.0
var target_length := 0.0


func _ready() -> void:
	_update_look()
	if Engine.is_editor_hint():
		return
	add_to_group("machine")
	collision_layer = 0
	collision_mask = 0
	if on:
		# Measure once the rest of the level is in place.
		_extend.call_deferred()


func _extend() -> void:
	target_length = _measure_gap()


func toggle() -> void:
	on = not on
	target_length = _measure_gap() if on else 0.0


# Machines can be shut down (by the Deactivator): the bridge slides back in.
func is_on() -> bool:
	return on


func shut_down() -> void:
	if on:
		toggle()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or length == target_length:
		return
	length = move_toward(length, target_length, EXTEND_SPEED * delta)
	_build_bridge()


# How long the bridge needs to be to reach the ground on the far side of the gap in front
# (checking just under ground level). If there's no far side within max_length, it's max_length.
func _measure_gap() -> float:
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.exclude = [$Bridge.get_rid()]
	var start := MACHINE_REGION.size.x / 2.0
	var passed_gap := false
	var distance := 0.0
	while distance < max_length:
		query.position = global_position + Vector2((start + distance) * facing, 6.0)
		var solid := not space.intersect_point(query).is_empty()
		if not solid:
			passed_gap = true
		elif passed_gap:
			return minf(distance + FAR_OVERLAP, max_length)
		distance += 4.0
	return max_length


func _build_bridge() -> void:
	var bridge: StaticBody2D = $Bridge
	var planks: Node2D = $Bridge/Planks
	for child in planks.get_children():
		planks.remove_child(child)
		child.queue_free()
	var shape: CollisionShape2D = $Bridge/CollisionShape2D
	bridge.position = Vector2(MACHINE_REGION.size.x / 2.0 * facing, 0)
	shape.disabled = length <= 0.0
	if length <= 0.0:
		return
	var texture: Texture2D = load("res://sprites/items.png")
	var laid := 0.0
	while laid < length:
		var width := minf(PLANK_REGION.size.x, length - laid)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.region_enabled = true
		sprite.region_rect = Rect2(PLANK_REGION.position, Vector2(width, PLANK_REGION.size.y))
		sprite.position = Vector2((laid + width / 2.0) * facing, PLANK_REGION.size.y / 2.0)
		planks.add_child(sprite)
		laid += width
	# The bridge's top is level with the ground.
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, BRIDGE_THICKNESS)
	shape.shape = rect
	shape.position = Vector2(length / 2.0 * facing, BRIDGE_THICKNESS / 2.0)


func _update_look() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not sprite or not shape:
		return
	sprite.flip_h = facing < 0
	sprite.position = Vector2(0, -MACHINE_REGION.size.y / 2.0)
	shape.position = sprite.position

@tool
extends StaticBody2D


# A wall of purple vines that blocks everyone until the gems are on their pedestals. Its origin
# is the bottom of the wall (on the ground); it's `height` tiles tall.
const VINE_REGION = Rect2(29, 192, 10, 64)

@export_range(1, 12) var height := 3:
	set(value):
		height = value
		_build()
# The pedestals that must all be filled for it to open. Leave it empty to use every pedestal in
# the level.
@export var pedestals: Array[Pedestal] = []


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	for pedestal in _pedestals():
		pedestal.filled.connect(_check)
	_check.call_deferred()


func _pedestals() -> Array:
	if not pedestals.is_empty():
		return pedestals
	return get_tree().get_nodes_in_group("pedestals")


func _check() -> void:
	var all := _pedestals()
	if all.is_empty():
		return
	for pedestal in all:
		if not pedestal.is_filled():
			return
	# Every gem is in place: the vines part.
	queue_free()


func _build() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var vines := get_node_or_null("Vines") as Node2D
	if not shape or not vines:
		return
	for child in vines.get_children():
		vines.remove_child(child)
		child.queue_free()
	var texture: Texture2D = load("res://sprites/items.png")
	for i in height:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.region_enabled = true
		sprite.region_rect = VINE_REGION
		sprite.position = Vector2(0, -32.0 - 64.0 * i)
		vines.add_child(sprite)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(VINE_REGION.size.x, 64.0 * height)
	shape.shape = rect
	shape.position = Vector2(0, -32.0 * height)

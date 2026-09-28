@tool
class_name Door
extends StaticBody2D


# A door: solid while closed; open, it fades out and stops blocking. Its origin is the bottom
# of the door (on the ground); it's `height` tiles tall. Whatever lists it in its `targets`
# opens it: levers, red buttons, lit goblets. Its `style`:
# - mechanical (door.tscn, a stone column): mechanized, a "machine" Squadroshock can open and close (X next to it);
# - wood (wood_door.tscn): opened by red buttons and levers;
# - flame (flame_door.tscn): opened by a goblet lit with blue fire.
const REGIONS = {
	"mechanical": Rect2(86, 192, 16, 64),
	"wood": Rect2(94, 320, 27, 64),
	"flame": Rect2(141, 325, 35, 59),
}

@export_range(1, 12) var height := 3:
	set(value):
		height = value
		_build()
@export var open := false:
	set(value):
		open = value
		_update_open()
@export_enum("mechanical", "wood", "flame") var style := "mechanical":
	set(value):
		style = value
		_build()


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	if style == "mechanical":
		add_to_group("machine")


func toggle() -> void:
	open = not open


# Machines can be shut down (by the Deactivator): for a mechanized door, that means closing it.
func is_on() -> bool:
	return open


func shut_down() -> void:
	open = false


func _update_open() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var column := get_node_or_null("Column") as Node2D
	if not shape or not column:
		return
	shape.set_deferred("disabled", open)
	column.modulate.a = 0.25 if open else 1.0


func _build() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var column := get_node_or_null("Column") as Node2D
	if not shape or not column:
		return
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var texture: Texture2D = load("res://sprites/items.png")
	var region: Rect2 = REGIONS[style]
	for i in height:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.region_enabled = true
		sprite.region_rect = region
		# Each segment fills a whole tile, so stacked segments meet without gaps.
		sprite.scale.y = 64.0 / region.size.y
		sprite.position = Vector2(0, -32.0 - 64.0 * i)
		column.add_child(sprite)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(region.size.x, 64.0 * height)
	shape.shape = rect
	shape.position = Vector2(0, -32.0 * height)
	_update_open()

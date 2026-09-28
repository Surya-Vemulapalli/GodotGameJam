@tool
class_name Burnable
extends StaticBody2D


# Something Pyrazure's fire burns away, like a tree. Normally red or blue fire burns it (it's in
# "burnable_red" and "burnable_blue"); with `needs_blue`, only blue fire does ("burnable_blue"),
# and its wood is drawn in light greys so it stands out. Hit by fire, it stops blocking, bursts into
# flame (red fire: sprite 23 on items.png; blue fire: sprites/blue_burn.png), and is gone a moment
# later. Its origin is the bottom of it, on the ground.
const BURN_TIME = 0.6
const FLAME_REGION = Rect2(271, 203, 35, 44)
const BLUE_FLAME = preload("res://sprites/blue_burn.png")
const LIGHT_GRAY = preload("res://light_gray.gdshader")

@export var needs_blue := false:
	set(value):
		needs_blue = value
		_update_look()

var burning := false


func _ready() -> void:
	_update_look()
	if Engine.is_editor_hint():
		return
	add_to_group("burnable_blue")
	if not needs_blue:
		add_to_group("burnable_red")


func burn(blue: bool) -> void:
	if burning or (needs_blue and not blue):
		return
	burning = true
	$CollisionShape2D.set_deferred("disabled", true)
	var flame := Sprite2D.new()
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if blue:
		flame.texture = BLUE_FLAME
		# The art's flames reach the bottom row of the picture, so that sits on the ground.
		flame.position = Vector2(0, -BLUE_FLAME.get_height() / 2.0)
	else:
		flame.texture = load("res://sprites/items.png")
		flame.region_enabled = true
		flame.region_rect = FLAME_REGION
		flame.position = Vector2(0, -FLAME_REGION.size.y / 2.0)
	add_child(flame)
	await get_tree().create_timer(BURN_TIME, false).timeout
	queue_free()


func _update_look() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return
	if needs_blue:
		var material := ShaderMaterial.new()
		material.shader = LIGHT_GRAY
		sprite.material = material
	else:
		sprite.material = null

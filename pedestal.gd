@tool
class_name Pedestal
extends Area2D


# Holds one gem of its own colour. On the ground, Transpora fills it by putting the gem down next
# to it; hanging from the ceiling, Lobulux fills it by throwing the gem into it. Barriers linked
# to it open once all their pedestals are filled.
signal filled

# Where each colour of pedestal is drawn: on sprites/items.png, except the white one, which
# has its own image.
const ITEMS_TEXTURE = "res://sprites/items.png"
const TEXTURES = {
	"white": "res://sprites/pedestal_white.png",
}
const REGIONS = {
	"red": Rect2(209, 96, 23, 32),
	"cyan": Rect2(337, 96, 23, 32),
	"green": Rect2(81, 160, 23, 32),
	"yellow": Rect2(209, 160, 23, 32),
	"white": Rect2(0, 0, 23, 32),
}

# Which gem it takes (the gem's `kind`).
@export_enum("red", "cyan", "green", "yellow", "white") var kind := "red":
	set(value):
		kind = value
		_update_look()
# Hangs upside down from the ceiling (its origin is where it's fixed on), instead of standing on
# the ground.
@export var on_ceiling := false:
	set(value):
		on_ceiling = value
		_update_look()

var gem: Gem


# It joins the group as soon as it enters the level, before anything's _ready, so barriers find
# it whichever order they come in the scene.
func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group("pedestals")


func _ready() -> void:
	_update_look()
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = 0


func is_filled() -> bool:
	return gem != null


func accepts(item: Node) -> bool:
	return not is_filled() and item is Gem and item.kind == kind


# Where the gem sits: on top of the pedestal, or hanging under it on the ceiling.
func socket_position() -> Vector2:
	var height: float = REGIONS[kind].size.y
	return Vector2(0, height + 8.0) if on_ceiling else Vector2(0, -height - 8.0)


func place(item: Gem) -> void:
	if not accepts(item):
		return
	gem = item
	gem.attach_to(self, socket_position())
	filled.emit()


# Lobulux throws gems into ceiling pedestals: a gem flying through this area gets caught.
# (Gems check this themselves while flying; Godot doesn't report them entering areas.)
func catches(item: Node2D) -> bool:
	var shape: CollisionShape2D = $CollisionShape2D
	return on_ceiling and accepts(item) and (shape.global_transform * shape.shape.get_rect()).has_point(item.global_position)


func _update_look() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not sprite or not shape:
		return
	var region: Rect2 = REGIONS[kind]
	sprite.texture = load(TEXTURES.get(kind, ITEMS_TEXTURE))
	sprite.region_rect = region
	sprite.flip_v = on_ceiling
	# The origin is the pedestal's base (on the floor or the ceiling); the art extends away from it.
	var direction := 1.0 if on_ceiling else -1.0
	sprite.position = Vector2(0, direction * region.size.y / 2.0)
	# Catch gems around the pedestal and the spot where its gem sits.
	var catch := RectangleShape2D.new()
	catch.size = Vector2(36, region.size.y + 28.0)
	shape.shape = catch
	shape.position = Vector2(0, direction * (region.size.y + 28.0) / 2.0)

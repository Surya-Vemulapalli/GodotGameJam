@tool
class_name FloorButton
extends Area2D


# A button on the floor: any character stepping on it presses it, and it stays pressed.
# - Red: opens the wooden doors (or anything else with an `open` setting) in its `targets`, and
#   sets off anything there with a trigger() (like a stalactite, which falls).
# - Blue: sits in a pool (on its floor) and drains that pool, and only that one: the body of water
#   it's in drains away from the top row down. A blue button that isn't in water does nothing.
# Its origin is the bottom of the button, on the ground; nothing collides with it.
const REGIONS = {
	"red": {"up": Rect2(76, 27, 39, 19), "pressed": Rect2(140, 34, 39, 12)},
	"blue": {"up": Rect2(70, 282, 47, 24), "pressed": Rect2(134, 289, 47, 17)},
}
# How fast the water drops.
const DRAIN_ROW_TIME = 0.25
# How far above its origin (the bottom of the button) it checks for the water it's in.
const WATER_CHECK_HEIGHT = 4.0

@export_enum("red", "blue") var color := "red":
	set(value):
		color = value
		_update_look()
@export var pressed := false:
	set(value):
		pressed = value
		_update_look()
# Red buttons only: the doors it opens and the traps it sets off.
@export var targets: Array[Node] = []


func _ready() -> void:
	_update_look()
	if Engine.is_editor_hint():
		return
	add_to_group("button")
	# Notice characters (collision layer 3).
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)


func press() -> void:
	if pressed:
		return
	pressed = true
	if color == "blue":
		_drain()
		return
	for target in targets:
		if not is_instance_valid(target):
			continue
		if target.has_method("trigger"):
			target.trigger()
		elif "open" in target:
			target.open = true


func _drain() -> void:
	for layer in Water.layers_beside(self):
		var cells := _water_to_drain(layer)
		# Top row first, so the water level drops.
		var rows := {}
		for cell in cells:
			if not rows.has(cell.y):
				rows[cell.y] = []
			rows[cell.y].append(cell)
		var ys := rows.keys()
		ys.sort()
		for y in ys:
			for cell in rows[y]:
				layer.erase_cell(cell)
			# Platforms that were floating sink with the water.
			for platform in get_tree().get_nodes_in_group("platforms"):
				if platform.floating:
					platform.drop()
			await get_tree().create_timer(DRAIN_ROW_TIME, false, true).timeout


# Every water cell of the pool the button is in (none if it isn't in water).
func _water_to_drain(layer: TileMapLayer) -> Array[Vector2i]:
	var start := layer.local_to_map(layer.to_local(global_position + Vector2(0, -WATER_CHECK_HEIGHT)))
	if not Water.is_water_cell(layer, start):
		return []
	# Everything connected to it.
	var pool: Array[Vector2i] = [start]
	var seen := {start: true}
	var i := 0
	while i < pool.size():
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = pool[i] + step
			if not seen.has(next) and Water.is_water_cell(layer, next):
				seen[next] = true
				pool.append(next)
		i += 1
	return pool


func _on_body_entered(body: Node) -> void:
	# Deferred: its look (and detection shape) can't change while Godot is reporting the touch.
	if body is BaseCharacter and not body.dead:
		press.call_deferred()


func _update_look() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not sprite or not shape:
		return
	var region: Rect2 = REGIONS[color]["pressed" if pressed else "up"]
	sprite.region_rect = region
	sprite.position = Vector2(0, -region.size.y / 2.0)
	# Anything standing on (or walking over) the button's top presses it.
	var up: Rect2 = REGIONS[color]["up"]
	var catch := RectangleShape2D.new()
	catch.size = Vector2(up.size.x, up.size.y + 4.0)
	shape.shape = catch
	shape.position = Vector2(0, -up.size.y / 2.0 + 2.0)

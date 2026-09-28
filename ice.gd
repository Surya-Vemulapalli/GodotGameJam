extends StaticBody2D


# A slab of ice (cell (0,5) on sprites/items.png). It's solid, and slippery: characters standing on
# it speed up and slow down gradually, so they slide (see BaseCharacter). Red or blue fire melts it:
# it stops blocking, fades away and is gone. Melting spreads: any ice touching it (stacked on it,
# under it or beside it) starts melting SPREAD_DELAY seconds later, and so on through the whole
# stack. Its origin is the bottom of it, on the ground.
const MELT_TIME = 0.6
const SPREAD_DELAY = 1.5
# How far apart (px) two slabs can be and still count as touching.
const TOUCHING = 2.0

var melting := false
# Set once melting has spread to it and it's waiting to melt.
var about_to_melt := false


func _ready() -> void:
	add_to_group("ice")
	add_to_group("burnable_red")
	add_to_group("burnable_blue")


func burn(_blue: bool) -> void:
	if melting:
		return
	melting = true
	$CollisionShape2D.set_deferred("disabled", true)
	for ice in _touching_ice():
		ice.melt_later()
	var tween := create_tween()
	tween.tween_property($Sprite2D, "modulate:a", 0.0, MELT_TIME)
	tween.tween_callback(queue_free)


# Melting has spread to it from ice it touches.
func melt_later() -> void:
	if melting or about_to_melt:
		return
	about_to_melt = true
	# A connection rather than an await, so nothing breaks if fire melts it first and it's gone.
	get_tree().create_timer(SPREAD_DELAY, false).timeout.connect(burn.bind(false))


func _touching_ice() -> Array:
	var touching := []
	var rect := _rect().grow(TOUCHING)
	for node in get_tree().get_nodes_in_group("ice"):
		if node != self and not node.melting and rect.intersects(node._rect()):
			touching.append(node)
	return touching


# Where it is in the level (its collision shape).
func _rect() -> Rect2:
	var collision: CollisionShape2D = $CollisionShape2D
	return collision.global_transform * collision.shape.get_rect()

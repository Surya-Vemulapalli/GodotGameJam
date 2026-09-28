extends Area2D


# A stalactite (cell (3,4) on sprites/items.png) hanging from the ceiling; its origin is the top of
# it, against the ceiling. It hangs harmlessly, invisible (so players can't tell which buttons are
# traps; it still shows in the editor), until something triggers it (a button with it in its
# `targets`), then appears and falls. While falling it instantly kills any character it touches and hits any
# enemy; it shatters (disappears) when it lands on something solid.
# It drops at full speed the moment it's triggered (no speeding up).
const FALL_SPEED = 900.0
# How far below the origin its tip is.
const TIP = 51.0

# Invisible while it hangs; turn off to let players see it coming.
@export var hidden_until_triggered := true

var falling := false


func _ready() -> void:
	add_to_group("falling_rock")
	# Solid things (layer 1) and characters (layer 3).
	collision_layer = 0
	collision_mask = 5
	if hidden_until_triggered:
		$Sprite2D.visible = false


func trigger() -> void:
	falling = true
	$Sprite2D.visible = true


func _physics_process(delta: float) -> void:
	if not falling:
		return
	var step := FALL_SPEED * delta
	var tip := global_position + Vector2(0, TIP)
	var query := PhysicsRayQueryParameters2D.create(tip, tip + Vector2(0, step), 1)
	var landed := get_world_2d().direct_space_state.intersect_ray(query)
	global_position.y += step if landed.is_empty() else landed.position.y - tip.y
	for body in get_overlapping_bodies():
		_crush(body)
	if not landed.is_empty():
		_crush(landed.collider)
		queue_free()


func _crush(body: Object) -> void:
	if body is BaseCharacter and not body.dead and not body.in_goal:
		body.die()
	elif body is Node and body.is_in_group("enemies"):
		body.hit()

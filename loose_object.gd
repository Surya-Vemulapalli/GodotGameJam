class_name LooseObject
extends StaticBody2D


# Something loose in the level, like a Squadroshock platform or a gem. It falls until it lands
# on something, and Lobulux can pick it up and throw it (it's in the "grabbable" group).
# `thrown` is true while it's falling or flying.
var velocity := Vector2.ZERO
var thrown := false
var thrower: Node2D

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	add_to_group("grabbable")
	# Settle onto whatever is below wherever it appeared.
	drop()


# While carried, nothing collides with it.
func pick_up() -> void:
	thrown = false
	$CollisionShape2D.set_deferred("disabled", true)


# Lets go of it where it is, to fall onto whatever is below.
func drop() -> void:
	throw(null, Vector2.ZERO)


func throw(by: Node2D, launch_velocity: Vector2) -> void:
	$CollisionShape2D.set_deferred("disabled", false)
	# Don't let it hit whoever threw it on the way out.
	thrower = by
	if thrower:
		add_collision_exception_with(thrower)
	velocity = launch_velocity
	thrown = true


func _physics_process(delta: float) -> void:
	if not thrown:
		# Resting: if whatever it was resting on has gone (say, an enemy walked out from under
		# it), it falls again.
		if _resting_on_something_that_can_leave() and not test_move(global_transform, Vector2(0, 1)):
			drop()
		return
	if _settle_in_water():
		return
	velocity.y += gravity * delta
	var collision := move_and_collide(velocity * delta)
	if not collision:
		return
	if collision.get_normal().y < -0.7:
		# Landed on something: settle there, unless it came down across the edge of a bank
		# with water under part of it (then platforms float, flush with the bank).
		if not _settle_in_water():
			_settle()
	else:
		# Hit a wall or ceiling: keep falling along it.
		velocity = velocity.slide(collision.get_normal())


# Whether it's resting somewhere it could lose its support: not carried (its collision is off
# then) and not floating on water.
func _resting_on_something_that_can_leave() -> bool:
	return not $CollisionShape2D.disabled and not get("floating")


# Whether it has come to rest on water. Platforms float; everything else sinks.
func _settle_in_water() -> bool:
	return false


func _settle() -> void:
	thrown = false
	velocity = Vector2.ZERO
	if is_instance_valid(thrower):
		remove_collision_exception_with(thrower)

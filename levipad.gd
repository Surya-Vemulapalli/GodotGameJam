extends AnimatableBody2D


# A levipad: a floating platform that's a machine. Squadroshock switches it on or off (X next to it
# or standing on it), and so can a lever with it in its `targets`. While on (its light shows), after
# a START_DELAY wait it rises `travel` px from where it's placed and sinks back, over and over,
# pausing at each end (longer at the far end); anyone standing on it rides along (see carries()). Switched off, it stops
# where it is. Characters can jump up through it from below and land on top. Its origin is the
# middle of the pad; place it with its top flush with the ground (origin 5 px below the ground's
# top), so characters can walk straight onto it (Squadroshock can't jump or step up).
const SPEED = 80.0
# How long it waits at its starting point, and (longer, so riders have time to step off) at the
# far end of its trip.
const PAUSE_TIME = 0.5
const TOP_PAUSE_TIME = 3.0
# Once switched on, it waits this long (light on) before it starts moving, giving riders time to
# get on.
const START_DELAY = 1.5
# Half the pad's height: its top is this far above its origin.
const HALF_HEIGHT = 5.0
# How close (px) someone's feet have to be to its top to count as standing on it.
const STANDING_MARGIN = 3.0

# How far (px) it rises above where it's placed. Negative to go down instead.
@export var travel := 128.0
@export var on := false

var start_y := 0.0
# 1 heading to the far end (start_y - travel), -1 heading back to start_y.
var heading := 1
var pause_left := 0.0


func _ready() -> void:
	add_to_group("machine")
	start_y = position.y
	_update_look()


func toggle() -> void:
	on = not on
	if on:
		pause_left = START_DELAY
	_update_look()


# Machines can be shut down (by the Deactivator): it stops where it is.
func is_on() -> bool:
	return on


func shut_down() -> void:
	if on:
		toggle()


func _physics_process(delta: float) -> void:
	if not on:
		return
	if pause_left > 0.0:
		pause_left = maxf(pause_left - delta, 0.0)
		return
	var target := start_y - travel if heading > 0 else start_y
	var riders := _riders()
	var before := position.y
	position.y = move_toward(position.y, target, SPEED * delta)
	for rider in riders:
		rider.global_position.y += position.y - before
	if position.y == target:
		pause_left = TOP_PAUSE_TIME if heading > 0 else PAUSE_TIME
		heading = -heading


# Whether someone (a character or an enemy) is standing on it: feet at its top and overlapping it
# sideways. This counts even when the physics engine thinks they're standing on the ground the pad
# is flush with, or on the ground inside a pad placed a little above it.
func carries(body: Node2D) -> bool:
	var shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not shape or shape.disabled:
		return false
	var feet := shape.global_transform * shape.shape.get_rect()
	var top := global_position.y - HALF_HEIGHT
	var half_width: float = ($CollisionShape2D.shape as RectangleShape2D).size.x / 2.0
	return absf(feet.end.y - top) <= STANDING_MARGIN 		and feet.end.x > global_position.x - half_width and feet.position.x < global_position.x + half_width


# Everyone it has to move along with it this step: those standing on it whom the physics engine
# isn't already carrying (it carries those that land on the pad itself).
func _riders() -> Array[Node2D]:
	var riders: Array[Node2D] = []
	for group in ["characters", "enemies"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as CharacterBody2D
			if body and body.is_on_floor() and carries(body) and not _physics_carries(body):
				riders.append(body)
	return riders


func _physics_carries(body: CharacterBody2D) -> bool:
	for i in body.get_slide_collision_count():
		if body.get_slide_collision(i).get_collider() == self:
			return true
	return false


func _update_look() -> void:
	$AnimatedSprite2D.play("on" if on else "off")

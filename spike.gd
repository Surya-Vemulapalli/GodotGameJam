extends Area2D


# Spikefish's spike: flies straight until it hits something. A character it hits takes damage;
# it breaks on anything else solid (enemies aside), or once it's off screen.
const SPEED = 300.0

var direction := Vector2.LEFT
# The Spikefish that launched it, so it doesn't break on its own body.
var shooter: Node


func _ready() -> void:
	# The art points left.
	$Sprite2D.flip_h = direction.x > 0
	add_to_group("enemy_attacks")
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta


func _on_body_entered(body: Node) -> void:
	if body == shooter or body.is_in_group("enemies"):
		return
	if body is BaseCharacter:
		if body.dead or body.in_goal:
			return
		if body.hurt_cooldown == 0.0:
			body.take_damage(body._contact_damage(self))
	queue_free()

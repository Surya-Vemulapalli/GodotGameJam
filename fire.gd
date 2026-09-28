extends Area2D


const SPEED = 400.0

var direction := Vector2.RIGHT
# Whoever breathed this fire, so it doesn't burn out on their own body.
var shooter: Node
# Fire.png has the regular red fire on top and the charged blue fire below it.
var blue := false


func _ready() -> void:
	if blue:
		$Sprite2D.region_rect.position.y = 64
	if direction.x < 0:
		# The art already points left, so unflip it and move everything to the other side.
		$Sprite2D.flip_h = false
		for child in [$Sprite2D, $CollisionShape2D, $VisibleOnScreenNotifier2D]:
			child.position.x = -child.position.x
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	# Burns what it hits if that burns (trees etc.; some only burn from blue fire).
	if body.has_method("burn"):
		body.burn(blue)
	# Red fire hits enemies that aren't robots; blue fire hits every enemy, and counts as two hits.
	if body.is_in_group("enemies") and (blue or not body.is_in_group("mechanical")):
		body.hit(2 if blue else 1)
	queue_free()

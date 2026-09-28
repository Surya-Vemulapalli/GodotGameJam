extends "res://birdloch.gd"


# A spiny fish that swims back and forth underwater like Birdloch. When a character is in front
# of it, roughly level with it and within range, it turns its spikes forward (frame 2) and
# launches one straight ahead, then goes straight back to swimming (frame 1). Like Birdloch, if its
# water drains away (a blue button), it dies.
const SPIKE_SCENE = preload("res://spike.tscn")
# How far ahead (px) it looks for a character, and how far above or below them it still fires.
const SIGHT_RANGE = 320.0
const SIGHT_HEIGHT = 24.0
const FIRE_COOLDOWN = 2.0
# Where the spike starts, in front of its face.
const SPIKE_OFFSET = Vector2(32, 0)

var fire_cooldown := 0.0


func _ready() -> void:
	super()
	sprite.animation_finished.connect(_on_animation_finished)


func _move(delta: float) -> void:
	super(delta)
	if is_queued_for_deletion():
		return
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	if fire_cooldown == 0.0 and _character_ahead():
		_fire()


func _character_ahead() -> bool:
	for node in get_tree().get_nodes_in_group("characters"):
		var character := node as BaseCharacter
		if not character or character.dead or character.in_goal:
			continue
		var to_character: Vector2 = character.sprite.global_position - global_position
		if to_character.x * direction > 0.0 and absf(to_character.x) <= SIGHT_RANGE and absf(to_character.y) <= SIGHT_HEIGHT:
			return true
	return false


func _fire() -> void:
	fire_cooldown = FIRE_COOLDOWN
	sprite.play("fire")
	var spike := SPIKE_SCENE.instantiate()
	spike.direction = Vector2(direction, 0)
	spike.shooter = self
	spike.position = global_position + Vector2(SPIKE_OFFSET.x * direction, SPIKE_OFFSET.y)
	get_parent().add_child(spike)


func _on_animation_finished() -> void:
	if sprite.animation == "fire":
		sprite.play("swim")

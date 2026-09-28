extends Sprite2D


# The spark burst (sprites/spear_hit.png) shown on an enemy hit by Squadroshock's electric spear.
# It flashes a little bigger and fades out, then removes itself.
const TIME = 0.3


func _ready() -> void:
	var start_scale := scale
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", start_scale * 1.3, TIME)
	tween.tween_property(self, "modulate:a", 0.0, TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

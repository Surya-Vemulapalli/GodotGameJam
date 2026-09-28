class_name ShieldPlatform
extends LooseObject


# 1 when placed by a character facing right, -1 when facing left.
var facing := 1
var tile_layers: Array[TileMapLayer] = []
# Resting on water (rather than on something solid).
var floating := false


func _ready() -> void:
	super()
	add_to_group("platforms")
	tile_layers = Water.layers_beside(self)
	if facing < 0:
		# The shield's front edge is on the right in the art, so mirror it.
		$AnimatedSprite2D.flip_h = true
		$AnimatedSprite2D.position.x = -$AnimatedSprite2D.position.x


# Floats on the water, so characters can cross on it. It floats if water is under any part
# of it, so one that lands across the edge of a bank floats flush with it instead of
# resting on the bank and leaving a gap.
func _settle_in_water() -> bool:
	var size: Vector2 = $CollisionShape2D.shape.size
	for dx in [-size.x / 2.0 + 2.0, 0.0, size.x / 2.0 - 2.0]:
		var surface := Water.surface_above(tile_layers, global_position + Vector2(dx, size.y / 2.0 + 1.0))
		if not is_nan(surface):
			# Float with the top of the platform on the waterline, level with the banks.
			global_position.y = surface + size.y / 2.0
			_settle()
			floating = true
			return true
	return false


# Lets go of it to fall (or float) again, e.g. when the water under it drains.
func drop() -> void:
	floating = false
	super()

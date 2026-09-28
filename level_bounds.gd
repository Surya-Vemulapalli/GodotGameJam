class_name LevelBounds
extends RefCounted


# Where a level ends at the bottom. Anything that falls this far below the level's lowest tile
# has fallen out of the level: characters die (restarting the level) and enemies are removed.
const FALL_MARGIN = 256.0
# Used if a level has no tiles at all.
const DEFAULT_FALL_DEATH_Y = 1500.0


# The y below which things have fallen out of the level, from its tile layers.
static func fall_death_y(layers: Array[TileMapLayer]) -> float:
	var lowest := -INF
	for layer in layers:
		for cell in layer.get_used_cells():
			var bottom := layer.to_global(layer.map_to_local(cell) + Vector2(0, layer.tile_set.tile_size.y / 2.0)).y
			lowest = maxf(lowest, bottom)
	if lowest == -INF:
		return DEFAULT_FALL_DEATH_Y
	return lowest + FALL_MARGIN

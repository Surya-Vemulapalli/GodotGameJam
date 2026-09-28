class_name Water
extends RefCounted


# Water is any tile with the tileset's "water" flag. The waterline is how far below the top of
# the topmost water tile the surface is; things float on it. The water art and the solid ground
# tiles both fill their whole tile, so it's 0: the surface is level with solid banks.
const WATERLINE = 0.0


# The level's tile layers (siblings of the given node), to check for water.
static func layers_beside(node: Node) -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	for sibling in node.get_parent().get_children():
		if sibling is TileMapLayer:
			layers.append(sibling)
	return layers


static func is_water_cell(layer: TileMapLayer, cell: Vector2i) -> bool:
	var data := layer.get_cell_tile_data(cell)
	return data != null and data.get_custom_data("water")


# The part of a water cell that's actually water, in global coordinates (a top cell is only
# water below the waterline).
static func water_rect(layer: TileMapLayer, cell: Vector2i) -> Rect2:
	var size := Vector2(layer.tile_set.tile_size)
	var top_left := layer.map_to_local(cell) - size / 2.0
	if not is_water_cell(layer, cell + Vector2i.UP):
		top_left.y += WATERLINE
		size.y -= WATERLINE
	return Rect2(layer.to_global(top_left), size)


static func is_water_at(layers: Array[TileMapLayer], point: Vector2) -> bool:
	for layer in layers:
		var cell := layer.local_to_map(layer.to_local(point))
		if is_water_cell(layer, cell) and water_rect(layer, cell).has_point(point):
			return true
	return false


# Whether any part of the (global) rectangle is in water.
static func overlaps(layers: Array[TileMapLayer], rect: Rect2) -> bool:
	for layer in layers:
		var start := layer.local_to_map(layer.to_local(rect.position))
		var end := layer.local_to_map(layer.to_local(rect.end))
		for x in range(start.x, end.x + 1):
			for y in range(start.y, end.y + 1):
				var cell := Vector2i(x, y)
				if is_water_cell(layer, cell) and water_rect(layer, cell).intersects(rect):
					return true
	return false


# The global y of the waterline above the point, or NAN if the point isn't in water.
static func surface_above(layers: Array[TileMapLayer], point: Vector2) -> float:
	for layer in layers:
		var cell := layer.local_to_map(layer.to_local(point))
		if not is_water_cell(layer, cell) or not water_rect(layer, cell).has_point(point):
			continue
		while is_water_cell(layer, cell + Vector2i.UP):
			cell += Vector2i.UP
		return water_rect(layer, cell).position.y
	return NAN

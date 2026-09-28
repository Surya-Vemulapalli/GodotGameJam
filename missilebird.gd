extends Enemy


# A homing bird (sprites/missilebird.png, drawn nose down) that goes after one character, chosen
# per placement (`target`). It flies at them at FLY_SPEED, ignoring gravity, turning to face the
# way it's going: straight at them while nothing solid is in between, otherwise along a path
# round the walls (through the level's open tiles). Walls still stop it (it slides along them), so
# cover buys time, but it doesn't get stuck behind one. Touching its target kills it outright and
# uses the Missilebird up. Anyone else it touches on the way takes the usual contact damage, and
# it flies on. Once its target is dead or in the cave it hovers where it is. Any attack defeats
# it; Lobulux can grab and throw it.
const FLY_SPEED = 160.0
# The art points down; the sprite is turned by this much less than the flight direction.
const ART_ANGLE = PI / 2.0
# How often (seconds) it works out its path round the walls again, as its target moves.
const REPATH_TIME = 0.25
# How close (px) it has to get to the middle of a tile on its path before heading for the next.
const WAYPOINT_REACH = 12.0
# Each character's script, to find the one it's after.
const CHARACTER_SCRIPTS = {
	"Pyrazure": "res://dragon.gd",
	"Squadroshock": "res://squadroshock.gd",
	"Lobulux": "res://lobulux.gd",
	"Transpora": "res://transpora.gd",
}

@export_enum("Pyrazure", "Squadroshock", "Lobulux", "Transpora") var target := "Pyrazure"

# The level's tiles as a grid for finding paths round walls (solid tiles blocked); null if the
# level has no tiles.
var grid: AStarGrid2D
# The tile layer the grid follows.
var grid_layer: TileMapLayer
# The tiles (as global points) it's following round the walls, and when to work them out again.
var path: Array[Vector2] = []
var repath_left := 0.0


func _ready() -> void:
	super()
	add_to_group("aerial")
	add_to_group("non_mechanical")
	_build_grid()


func _move(delta: float) -> void:
	var victim := _victim()
	if not victim:
		velocity = Vector2.ZERO
		return
	# One touch kills its target, whatever its health, and uses the Missilebird up.
	if victim.hurtbox.overlaps_body(self):
		victim.die()
		queue_free()
		return
	var goal: Vector2 = victim.sprite.global_position
	var heading := goal
	if _blocked(goal):
		repath_left -= delta
		if repath_left <= 0.0 or path.is_empty():
			repath_left = REPATH_TIME
			path = _path_to(goal)
		while not path.is_empty() and global_position.distance_to(path[0]) <= WAYPOINT_REACH:
			path.pop_front()
		if not path.is_empty():
			heading = path[0]
	else:
		path.clear()
	velocity = (heading - global_position).normalized() * FLY_SPEED
	sprite.rotation = velocity.angle() - ART_ANGLE
	move_and_slide()


# The character it's after, while that character is still out in the level.
func _victim() -> BaseCharacter:
	for node in get_tree().get_nodes_in_group("characters"):
		var character := node as BaseCharacter
		if character and character.get_script().resource_path == CHARACTER_SCRIPTS[target]:
			if character.dead or character.in_goal:
				return null
			return character
	return null


# Whether something solid (tiles, doors, barriers) is between it and the point.
func _blocked(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, point, 1, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# The middles of the tiles on the way to the point, round the walls; empty if there's no way.
func _path_to(point: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if not grid:
		return points
	var from := _cell_at(global_position)
	var to := _cell_at(point)
	if not grid.is_in_boundsv(from) or not grid.is_in_boundsv(to) or grid.is_point_solid(from) or grid.is_point_solid(to):
		return points
	# If its target can't be reached (say, sealed off), it gets as close as it can.
	var cells := grid.get_id_path(from, to, true)
	# The first tile is the one it's in; head for the next.
	for i in range(1, cells.size()):
		points.append(grid_layer.to_global(grid_layer.map_to_local(cells[i])))
	return points


func _cell_at(point: Vector2) -> Vector2i:
	return grid_layer.local_to_map(grid_layer.to_local(point))


# Marks every tile that has collision (not water) as blocked, over the whole level plus a tile
# of margin round it.
func _build_grid() -> void:
	if tile_layers.is_empty():
		return
	grid_layer = tile_layers[0]
	var region := Rect2i()
	for layer in tile_layers:
		var used := layer.get_used_rect()
		region = used if region.size == Vector2i.ZERO else region.merge(used)
	if region.size == Vector2i.ZERO:
		return
	grid = AStarGrid2D.new()
	grid.region = region.grow(1)
	grid.cell_size = Vector2(grid_layer.tile_set.tile_size)
	# No cutting corners past a wall.
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for layer in tile_layers:
		for cell in layer.get_used_cells():
			var data := layer.get_cell_tile_data(cell)
			if data and data.get_collision_polygons_count(0) > 0 and grid.is_in_boundsv(cell):
				grid.set_point_solid(cell)

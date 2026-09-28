extends Node2D


# How far apart the characters line up at the spawn point.
const SPAWN_SPACING = 56.0
# The longest a death holds up the restart (the death animations themselves are shorter).
const MAX_DEATH_TIME = 0.5
# Asks before restarting the level (left shoulder button) or quitting to the start page (left
# trigger).
const RESTART_DIALOG = preload("res://restart_dialog.tscn")
const START_PAGE = "res://start.tscn"

# Which D-pad direction switches to which character. Leave a slot empty if it isn't used.
@export var up_character: BaseCharacter
@export var right_character: BaseCharacter
@export var down_character: BaseCharacter
@export var left_character: BaseCharacter
# Follows whichever character is being controlled.
@export var camera: Camera2D
# Where the characters start the level (and respawn, since dying restarts the level). They
# line up behind it in D-pad order, facing right: Pyrazure at the front, then Squadroshock,
# then Lobulux, then Transpora at the back.
@export var spawn: Marker2D
# Optional: a separate starting point for each character (by D-pad slot), for levels where they
# start in different areas. A character with one set starts there instead of in the line at `spawn`.
@export var up_spawn: Marker2D
@export var right_spawn: Marker2D
@export var down_spawn: Marker2D
@export var left_spawn: Marker2D
# The goal cave (exit.tscn). A character that walks into it goes inside and can't come back
# out; once all four are inside, the next level loads.
@export var exit: Area2D
# The level to go to next. Leave it empty on the last level.
@export_file("*.tscn") var next_level := ""
# Shown at the top of the screen, e.g. "Level 1".
@export var title := ""

var finished := false
# Set by the first death; several characters can die at once, but the level restarts once.
var restarting := false
# Shows each character's health in the top-left corner.
var health_label: Label
# The "restart this level?" or "quit?" question, while it's showing.
var restart_dialog: CanvasLayer


func _ready() -> void:
	var hud := CanvasLayer.new()
	health_label = Label.new()
	health_label.position = Vector2(8, 8)
	_outline(health_label)
	hud.add_child(health_label)
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title_label.position.y = 8
	_outline(title_label)
	hud.add_child(title_label)
	add_child(hud)
	var place := 0
	var own_spawns := {
		up_character: up_spawn, right_character: right_spawn,
		down_character: down_spawn, left_character: left_spawn,
	}
	for character in _characters():
		character.died.connect(_on_character_died)
		var own: Marker2D = own_spawns.get(character)
		if own:
			character.global_position = own.global_position
		elif spawn:
			character.global_position = spawn.global_position - Vector2(SPAWN_SPACING * place, 0)
			place += 1
	for character in _characters():
		_switch_to(character)
		break


# A dark outline so the text reads on light backgrounds (like the sky).
func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.2))
	label.add_theme_constant_override("outline_size", 6)


func _process(_delta: float) -> void:
	# The left shoulder button asks whether to restart the level; the left trigger asks whether
	# to quit to the start page. Checked here rather than in _unhandled_input because a trigger
	# sends a stream of events while held; this only fires on the press.
	if Input.is_action_just_pressed("reset_level"):
		_ask_restart()
	elif Input.is_action_just_pressed("quit_level"):
		_ask_quit()
	var lines := PackedStringArray()
	for character in _characters():
		var marker := "> " if character.active else "   "
		var status := "in the cave" if character.in_goal else "%d / %d" % [character.health, character.MAX_HEALTH]
		lines.append("%s%s  %s" % [marker, character.name, status])
	health_label.text = "\n".join(lines)


func _physics_process(_delta: float) -> void:
	if finished or not exit:
		return
	var characters := _characters()
	for character in characters:
		if not character.in_goal and exit.overlaps_body(character):
			_enter_goal(character)
	if characters.size() == 4 and characters.all(func(c: BaseCharacter) -> bool: return c.in_goal):
		_finish()


func _enter_goal(character: BaseCharacter) -> void:
	var was_controlled := character.active
	character.enter_goal()
	# Hand control (and the camera) to someone still outside.
	if was_controlled:
		for other in _characters():
			if not other.in_goal:
				_switch_to(other)
				return


func _finish() -> void:
	finished = true
	if next_level:
		get_tree().change_scene_to_file.call_deferred(next_level)
		return
	# That was the last level.
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "You finished every level!"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.add_child(label)
	add_child(layer)
	for character in _characters():
		character.active = false


func _unhandled_input(event: InputEvent) -> void:
	var character: BaseCharacter = null
	if event.is_action_pressed("switch_up"):
		character = up_character
	elif event.is_action_pressed("switch_right"):
		character = right_character
	elif event.is_action_pressed("switch_down"):
		character = down_character
	elif event.is_action_pressed("switch_left"):
		character = left_character
	# Characters already in the goal cave can't be switched to.
	if _is_alive(character) and not character.in_goal:
		_switch_to(character)


# Pauses the game and asks "Do you want to restart this level?"; Yes restarts it, No (or B)
# carries on.
func _ask_restart() -> void:
	if await _ask("Do you want to restart this level?"):
		restarting = true
		get_tree().reload_current_scene.call_deferred()


# Pauses the game and asks "Do you want to quit to the start page?"; Yes goes back to the start
# page, No (or B) carries on.
func _ask_quit() -> void:
	if await _ask("Do you want to quit to the start page?"):
		restarting = true
		get_tree().change_scene_to_file.call_deferred(START_PAGE)


# Pauses the game, asks the question, and returns the answer (false if it can't ask right now).
func _ask(question: String) -> bool:
	if finished or restarting or is_instance_valid(restart_dialog):
		return false
	restart_dialog = RESTART_DIALOG.instantiate()
	restart_dialog.question = question
	add_child(restart_dialog)
	get_tree().paused = true
	var yes: bool = await restart_dialog.answered
	get_tree().paused = false
	return yes and not restarting


func _switch_to(character: BaseCharacter) -> void:
	for other in _characters():
		other.active = other == character
	if camera:
		camera.reparent(character, false)
		# Centred on the character's origin, whatever position the camera has in the editor.
		camera.position = Vector2.ZERO


# When any character dies, everyone respawns: its death animation plays (it starts the moment its
# health hits zero), and as soon as that's over the whole level starts over. The restart never
# waits longer than MAX_DEATH_TIME, even if something cuts the animation short.
func _on_character_died(character: BaseCharacter) -> void:
	if restarting or not is_inside_tree():
		return
	restarting = true
	var timer := get_tree().create_timer(MAX_DEATH_TIME, false)
	while is_instance_valid(character) and character.is_inside_tree() and timer.time_left > 0.0:
		await get_tree().process_frame
	# The level may already be gone (say, it was finished or left at the same moment).
	if not is_inside_tree():
		return
	get_tree().reload_current_scene.call_deferred()


# Untyped, because it gets handed characters that have already left the level.
func _is_alive(character) -> bool:
	return is_instance_valid(character) and not character.dead


# The living characters, in D-pad order.
func _characters() -> Array[BaseCharacter]:
	var characters: Array[BaseCharacter] = []
	for character in [up_character, right_character, down_character, left_character]:
		if _is_alive(character):
			characters.append(character)
	return characters

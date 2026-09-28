extends Control


# DEBUG ONLY, not part of the game: nothing links here. Open debug/level_select.tscn in the editor
# and press F6 (Run Current Scene) to jump straight into any level. It lists every
# levels/level_*.tscn, so new levels show up by themselves. Gamepad (D-pad / stick, A) or mouse.
const LEVELS_DIR = "res://levels/"


func _ready() -> void:
	var files := Array(DirAccess.get_files_at(LEVELS_DIR))
	var levels := []
	for f in files:
		# Exported builds list scenes as ".tscn.remap".
		var name: String = f.trim_suffix(".remap")
		if name.begins_with("level_") and name.ends_with(".tscn") and not levels.has(name):
			levels.append(name)
	levels.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	var list: VBoxContainer = $Center/List
	for f in levels:
		var button := Button.new()
		button.text = f.trim_suffix(".tscn").replace("_", " ").capitalize()
		button.pressed.connect(get_tree().change_scene_to_file.bind(LEVELS_DIR + f))
		list.add_child(button)
	if list.get_child_count() > 1:
		(list.get_child(1) as Button).grab_focus()

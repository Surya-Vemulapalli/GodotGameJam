class_name PeculiarItem
extends LooseObject


# A curious green stone (sprites/peculiar_item.png). It does nothing on its own: Transpora can
# carry it in its backpack and put it down elsewhere. Only Transpora moves it; Lobulux can't grab it.


func _ready() -> void:
	super()
	remove_from_group("grabbable")
	# Transpora can carry it in its backpack.
	add_to_group("movable")

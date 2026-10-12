extends Node
const Motion = preload("res://scripts/ds_material_motion.gd")
var motion = Motion.new()
var clock: float = 0.0
func bind_stage(stage: Node3D, id: String) -> void:
	motion.bind_stage(stage,id)
func _process(delta: float) -> void:
	clock += delta
	motion.advance(clock)

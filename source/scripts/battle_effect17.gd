extends Node3D
## Desktop battle accents; no game state, damage, random draws, or source clips.
## The battle world's process mode also freezes this local visual clock.

const COLORS: Dictionary = {
	"Pyrus": Color("ff713b"), "Aquos": Color("43cfff"),
	"Subterra": Color("ffbd67"), "Haos": Color("fff3ac"),
	"Darkus": Color("bb81ff"), "Ventus": Color("67f3ba"),
}
var kind: String = "ability"
var age: float = 0.0
var duration: float = 0.85
var _rings: Array[MeshInstance3D] = []
var _shards: Array[MeshInstance3D] = []
var _material: StandardMaterial3D


func setup(event_kind: String, attribute: String) -> void:
	kind = event_kind
	duration = 1.25 if kind == "win" else 0.45 if kind == "damage" else 0.85
	name = "BattleAccent_" + kind
	set_meta("presentation_only", true)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = COLORS.get(attribute, Color("c4d6eb"))
	_material.disable_receive_shadows = true
	for index: int in (1 if kind == "damage" else 2):
		var mesh: TorusMesh = TorusMesh.new()
		mesh.inner_radius = 0.89
		mesh.outer_radius = 0.95
		mesh.rings = 32
		mesh.ring_segments = 6
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.mesh = mesh
		ring.material_override = _material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)
	for index: int in (0 if kind == "damage" else 8):
		var mesh: PrismMesh = PrismMesh.new()
		mesh.size = Vector3(0.065, 0.45 if kind == "win" else 0.24, 0.065)
		var shard: MeshInstance3D = MeshInstance3D.new()
		shard.mesh = mesh
		shard.material_override = _material
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shard)
		_shards.append(shard)
	_update_pose()


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	_update_pose()


func _update_pose() -> void:
	var progress: float = clampf(age / duration, 0.0, 1.0)
	var envelope: float = minf(1.0, progress * 8.0) * (1.0 - progress)
	var tint: Color = _material.albedo_color
	tint.a = envelope * 0.8
	_material.albedo_color = tint
	for index: int in _rings.size():
		var ring: MeshInstance3D = _rings[index]
		var radius: float = 0.65 + progress * (1.5 if kind == "win" else 0.9) + float(index) * 0.18
		ring.scale = Vector3(radius, 0.65, radius)
		ring.position.y = 0.08 + float(index) * 0.16 + (progress * 0.9 if kind == "win" else 0.0)
	for index: int in _shards.size():
		var angle: float = TAU * float(index) / float(_shards.size()) + progress * 0.45
		var radius: float = 1.05 + progress * 0.35
		var height: float = 0.35 + progress * (2.4 if kind == "win" else 1.25)
		_shards[index].position = Vector3(cos(angle) * radius, height + float(index % 3) * 0.12, sin(angle) * radius)
		_shards[index].rotation.y = -angle

extends RefCounted
## Native SRT and MAT0 samples, matched by original material names.
const PATH: String = "res://assets/ds/arenas/material_motion.json"
static var _data: Dictionary = {}
var bindings: Array[Dictionary] = []
var colour_bindings: Array[Dictionary] = []
func bind_stage(stage: Node3D, group: String) -> void:
	bindings.clear()
	colour_bindings.clear()
	if _data.is_empty() and FileAccess.file_exists(PATH):
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	for component: Node in stage.get_children():
		var entry: Dictionary = _data.get("groups", {}).get(group, {}).get(str(component.name), {})
		var colour_entry: Dictionary = _data.get("colour_groups", {}).get(group, {}).get(str(component.name), {})
		bind_component(component,entry,colour_entry)
	advance(0.0)

func bind_component(component: Node, entry: Dictionary, colour_entry: Dictionary = {}) -> void:
	for mesh: MeshInstance3D in component.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var material: StandardMaterial3D = mesh.get_active_material(surface) as StandardMaterial3D
			if material == null:
				continue
			for track: Dictionary in entry.get("tracks", []):
				if material.resource_name == str(track.name):
					bindings.append({"material":material,"track":track,"frames":entry.frames,"base":material.uv1_offset})
			for track: Dictionary in colour_entry.get("tracks", []):
				if material.resource_name == str(track.name):
					colour_bindings.append({"material":material,"track":track,"frames":colour_entry.frames})
					var alpha: Dictionary = track.channels[4]
					if int(alpha.get("constant",31))<31 or alpha.has("values"):
						material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
func advance(clock: float) -> void:
	if not is_finite(clock):
		return
	for item: Dictionary in bindings:
		var frame: float = fposmod(clock * 60.0,float(item.frames))
		var channels: Array = item.track.channels
		var u: float = _sample(channels[3],frame)
		var v: float = _sample(channels[4],frame)
		item.material.uv1_offset = item.base + Vector3(u,-v,0)
	for item: Dictionary in colour_bindings:
		var frame: int = floori(fposmod(clock*60.0,float(item.frames)))
		var channels: Array = item.track.channels
		var diffuse: Color = _rgb555(_sample_colour(channels[0],frame))
		diffuse.a = float(_sample_colour(channels[4],frame,true))/31.0
		item.material.albedo_color = diffuse
		var emission: Color = _rgb555(_sample_colour(channels[3],frame))
		item.material.emission_enabled = emission.r>0 or emission.g>0 or emission.b>0
		item.material.emission = emission
		# Ambient/specular colors are retained, but Godot's material lighting
		# does not have the DS's separate RGB555 lighting registers.
		item.material.set_meta("ds_ambient_rgb555",_sample_colour(channels[1],frame))
		item.material.set_meta("ds_specular_rgb555",_sample_colour(channels[2],frame))
func _sample(channel: Dictionary, frame: float) -> float:
	var values: Array = channel.get("values", [])
	if values.is_empty():
		return float(channel.get("constant",0.0))
	var stride: float = float(channel.get("step",1))
	var end: float = float(channel.get("interpolation_end",INF))
	var position: float = frame/stride if frame<end else end/stride+frame-end
	position = minf(position,values.size()-1)
	var index: int = floori(position)
	return lerpf(float(values[index]),float(values[mini(index+1,values.size()-1)]),position-index)

static func _rgb555(value: int) -> Color:
	return Color(float(value&31)/31.0,float((value>>5)&31)/31.0,float((value>>10)&31)/31.0)

func _sample_colour(channel: Dictionary, frame: int, alpha: bool = false) -> int:
	var values: Array = channel.get("values",[])
	if values.is_empty():
		return int(channel.get("constant",31 if alpha else 0x7fff))
	var stride: int = int(channel.get("step",1))
	var end: int = int(channel.get("interpolation_end",values.size()))
	var index: int = frame/stride if frame<=end else end/stride+frame-end
	index = clampi(index,0,values.size()-1)
	var a: int = int(values[index])
	if frame>=end or frame%stride==0 or index>=values.size()-1:
		return a
	var b: int = int(values[index+1])
	var fraction: int = frame%stride
	if alpha:
		return (a*(stride-fraction)+b*fraction)/stride
	var result: int = 0
	for shift: int in [0,5,10]:
		var channel_value: int = (((a>>shift)&31)*(stride-fraction)+((b>>shift)&31)*fraction)/stride
		result |= channel_value<<shift
	return result

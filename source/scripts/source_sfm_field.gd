extends RefCounted
## Static Source Filmmaker field. SFM supplies visuals, not Bakugan rules.
const ID: String = "sfm_battle_field"
const MANIFEST_PATH: String = "res://assets/sfm/battle_field/manifest.json"
static var _manifest: Dictionary = {}
static var _scene: PackedScene

static func manifest() -> Dictionary:
 if _manifest.is_empty():
  var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
  if parsed is Dictionary:
   _manifest = parsed
 return _manifest

static func make_stage() -> Node3D:
 var data: Dictionary = manifest()
 if data.is_empty():
  return null
 if _scene == null:
  _scene = load(str(data.model.path)) as PackedScene
 if _scene == null:
  return null
 var stage: Node3D = _scene.instantiate() as Node3D
 stage.name = "SFMBattleField"
 var fit: Dictionary = data.pc_fit
 stage.scale = Vector3.ONE * float(fit.uniform_scale)
 var offset: Array = fit.source_offset
 stage.position = Vector3(float(offset[0]),float(offset[1]),float(offset[2])) * stage.scale.x
 var live_materials: Array[StandardMaterial3D] = []
 for node: Node in stage.find_children("*", "MeshInstance3D", true, false):
  # The opaque shell surrounds the camera; it must not shadow the entire field.
  (node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  # Desktop battle lighting otherwise clips the bright native floor to white.
  var mesh_node: MeshInstance3D = node as MeshInstance3D
  for surface: int in mesh_node.mesh.get_surface_count():
   var material: StandardMaterial3D = mesh_node.get_active_material(surface).duplicate() as StandardMaterial3D
   material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
   live_materials.append(material)
   mesh_node.set_surface_override_material(surface, material)
 stage.set_meta("runtime_materials", live_materials)
 stage.set_meta("source_origin", "source_sfm_workshop")
 stage.set_meta("source_workshop", str(data.source.workshop_url))
 stage.set_meta("native_geometry", true)
 stage.set_meta("native_texture_coordinates", true)
 stage.set_meta("visual_only_collision", true)
 stage.set_meta("surface_y", 0.0)
 stage.set_meta("ds_far_hint", float(fit.camera_far))
 stage.set_meta("source_animation_frames", int(data.source_animation.frames))
 return stage

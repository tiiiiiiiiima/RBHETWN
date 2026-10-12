extends RefCounted
## One native Workshop board and sky, adapted to the shared rolling field.

const BOARD_PATH: String = "res://assets/imported/arenas/anime_board.glb"
const BOARD_TEXTURE: String = "res://assets/imported/arenas/anime_board.png"
const SKY_TEXTURE: String = "res://assets/imported/arenas/anime_sky.png"
const MANIFEST_PATH: String = "res://assets/imported/arenas/source_manifest.json"
const WORKSHOP_URL: String = "https://steamcommunity.com/sharedfiles/filedetails/?id=3412700725"
const DIMENSIONS: Vector3 = Vector3(12.7, 0.25, 10.8)
const SOURCE_TINT: Color = Color(0.1716086268, 0.6986061931, 0.6546897888)
const UV_SCALE: Vector3 = Vector3(1.0 / 44.0, 1.0 / 16.0, 1.0)

static var _board_scene: PackedScene
static var _board_material: StandardMaterial3D
static var _sky: Sky


static func make_board() -> Node3D:
	if _board_scene == null:
		_board_scene = load(BOARD_PATH) as PackedScene
	if _board_scene == null:
		return null
	if _board_material == null:
		_board_material = StandardMaterial3D.new()
		_board_material.albedo_texture = load(BOARD_TEXTURE) as Texture2D
		_board_material.albedo_color = SOURCE_TINT
		_board_material.uv1_scale = UV_SCALE
		_board_material.roughness = 1.0
		_board_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_board_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var board: Node3D = _board_scene.instantiate() as Node3D
	board.name = "SourceBoard"
	_assign_material(board)
	board.set_meta("source_origin", "source_table_board")
	board.set_meta("source_workshop", WORKSHOP_URL)
	board.set_meta("dimensions", DIMENSIONS)
	board.set_meta("surface_y", 0.0)
	board.set_meta("source_uv_preserved", true)
	board.set_meta("material_uv_scale", UV_SCALE)
	return board


static func _assign_material(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _board_material
	for child: Node in node.get_children():
		_assign_material(child)


static func apply_sky(environment: Environment, enabled: bool) -> void:
	if not enabled:
		environment.background_mode = Environment.BG_COLOR
		environment.sky = null
		return
	if _sky == null:
		var material: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
		material.panorama = load(SKY_TEXTURE) as Texture2D
		material.filter = true
		_sky = Sky.new()
		_sky.sky_material = material
		_sky.radiance_size = Sky.RADIANCE_SIZE_128
		_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.sky = _sky
	environment.background_mode = Environment.BG_SKY


static func manifest() -> Dictionary:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

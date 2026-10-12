extends Control
## A separate 3D battle stage. Snapshots survive removal of the gate by rules.
## Native DS resources are presented in a desktop layout; this node owns no rules.

const Models = preload("res://scripts/model_library.gd")
const BattleAccent = preload("res://scripts/battle_effect17.gd")
const ModelCatalog = preload("res://scripts/ds_model_catalog.gd")
const Stages = preload("res://scripts/ds_arena_catalog.gd")
const SFMField = preload("res://scripts/source_sfm_field.gd")
const DSCards = preload("res://scripts/ds_card_catalog.gd")
const UI_MANIFEST: String = "res://assets/ds/ui_manifest.json"
const INK: Color = Color("080b15")
const OWN: Color = Color("28bfe9")
const ENEMY: Color = Color("ed3024")
const RESULT_SECONDS: float = 1.5

var snapshot: Dictionary = {}
var actors: Dictionary = {}
var reduced_motion: bool = false
var stage_id: String = ""
var phase: String = "closed"
var camera: Camera3D
var viewport: SubViewport
var _world: Node3D
var _stage: Node3D
var _actors: Node3D
var _effects: Node3D
var _view: SubViewportContainer
var _scores: Array[Label] = []
var _names: Array[Label] = []
var _power_bars: Array[ProgressBar] = []
var _digit_rows: Array[HBoxContainer] = []
var _attribute_icons: Array[TextureRect] = []
var _portraits: Array[TextureRect] = []
var _portrait_by_identity: Dictionary = {}
var _gate_face: TextureRect
var _title: Label
var _gate_label: Label
var _event_label: Label
var _banner: TextureRect
var _response_prompt: TextureRect
var _native_ui: Dictionary = {}
var _elapsed: float = 0.0
var _event_time: float = 0.0
var _result_time: float = 0.0
var _camera_time: float = 0.0
var _camera_side: int = -1
var _suspended: bool = false
var _built: bool = false
var _support_nodes: Dictionary = {}
var _card_scene: Panel
var _scene_face: TextureRect
var _scene_title: Label
var _scene_description: Label
var _result_native_stage: int = 0


func configure(arena_id: String, motion_reduced: bool = false) -> void:
	reduced_motion = motion_reduced
	if reduced_motion:
		_clear_effects()
	if not _built:
		_build()
	_set_stage(arena_id)


func sync_battle(state: Dictionary, event: Dictionary = {}) -> void:
	if state.is_empty() or state.get("units", []).is_empty():
		return
	if not _built:
		configure(str(state.get("arena_id", "stadium")), reduced_motion)
	var new_battle: bool = str(snapshot.get("key", "")) != str(state.get("key", "")) or phase == "closed"
	if new_battle:
		_clear_effects()
		_clear_actors()
		_elapsed = 0.0
		_result_time = 0.0
		phase = "intro"
	snapshot = state.duplicate(true)
	_set_stage(str(state.get("arena_id", stage_id)))
	_sync_actors()
	_update_scores()
	_update_gate()
	_apply_sequence_frame()
	if new_battle:
		_show_event("battle", "БАКУГАНЫ — В БОЙ!", 1.1)
		_play_all("idle")
	if not event.is_empty():
		_present_event(event)
	visible = not _suspended
	_world.process_mode = Node.PROCESS_MODE_DISABLED if _suspended else Node.PROCESS_MODE_INHERIT
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED


func finish_battle(victor: int, totals: Array) -> void:
	if snapshot.is_empty():
		return
	phase = "result"
	_result_time = 2.6 if bool(snapshot.get("native_scratch",false)) else RESULT_SECONDS
	_result_native_stage = 0
	snapshot["totals"] = totals.duplicate()
	snapshot["victor"] = victor
	_update_scores()
	_show_event("win" if victor == 0 else "lose" if victor == 1 else "draw", "ПОБЕДА" if victor == 0 else "ПОРАЖЕНИЕ" if victor == 1 else "НИЧЬЯ", RESULT_SECONDS)
	for key: String in actors:
		var actor: Node3D = actors[key]
		var side: int = int(actor.get_meta("battle_owner", -1))
		Models.play_battle_animation(actor, "win" if side == victor else "lose" if victor >= 0 else "idle")
	if bool(snapshot.get("native_scratch",false)):
		_play_side(victor,"attack")
		_play_side(1-victor,"damage")
		_show_event("","РЕШАЮЩАЯ АТАКА",0.85)
	_clear_effects()
	_spawn_side_effect(victor, "win")
	_camera_side = victor
	_camera_time = RESULT_SECONDS
	visible = not _suspended


func set_suspended(value: bool) -> void:
	if _suspended == value:
		return
	_suspended = value
	visible = phase != "closed" and not value
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if _world != null:
		_world.process_mode = Node.PROCESS_MODE_DISABLED if value or phase=="closed" else Node.PROCESS_MODE_INHERIT


func reset() -> void:
	phase = "closed"
	snapshot.clear()
	_clear_effects()
	_clear_actors()
	_event_time = 0.0
	_result_time = 0.0
	_camera_time = 0.0
	_camera_side = -1
	_suspended = false
	if _world != null:
		_world.process_mode = Node.PROCESS_MODE_DISABLED
	hide()
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func is_presenting() -> bool:
	return phase != "closed"


func is_result_playing() -> bool:
	return phase == "result" and _result_time > 0.0


func _build() -> void:
	_built = true
	name = "DSBattlePresentation"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 20
	offset_top = 130
	offset_right = -375
	offset_bottom = -190
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var background: ColorRect = ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_view = SubViewportContainer.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.stretch = true
	add_child(_view)
	viewport = SubViewport.new()
	viewport.name = "BattleWorld"
	viewport.own_world_3d = true
	viewport.size = Vector2i(960, 540)
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.add_child(viewport)
	_world = Node3D.new()
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(_world)
	_actors = Node3D.new()
	_actors.name = "BattleParticipants"
	_world.add_child(_actors)
	_effects = Node3D.new()
	_effects.name = "BattleAccents"
	_world.add_child(_effects)
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("182944")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_environment.environment = environment
	_world.add_child(world_environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0)
	light.light_energy = 0.8
	_world.add_child(light)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 46.0
	camera.near = 0.05
	camera.far = 2000.0
	_world.add_child(camera)
	_set_overview_camera()
	_load_native_ui()
	_build_card_scene()
	for side: int in range(2):
		var box: Panel = Panel.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if side == 0 else Control.PRESET_TOP_RIGHT)
		box.offset_left = 12 if side == 0 else -274
		box.offset_right = 274 if side == 0 else -12
		box.offset_top = 12
		box.offset_bottom = 98
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.015, 0.025, 0.05, 0.84)
		box.add_theme_stylebox_override("panel", style)
		add_child(box)
		var frame_texture: Texture2D = _native_texture("g_frame")
		if frame_texture != null:
			var frame: TextureRect = TextureRect.new()
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = frame_texture
			atlas.region = Rect2(0 if side == 0 else 128, 0, 128, 46)
			frame.texture = atlas
			frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			frame.stretch_mode = TextureRect.STRETCH_SCALE
			frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			frame.offset_top = -27
			frame.offset_bottom = 0
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(frame)
		var name_label: Label = _label(box, "", 16)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		name_label.offset_left = 10
		name_label.offset_right = -10
		name_label.offset_top = 5
		name_label.offset_bottom = 29
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_names.append(name_label)
		var value: Label = _label(box, "0 G", 27)
		value.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		value.offset_left = 10
		value.offset_right = -10
		value.offset_top = 29
		value.offset_bottom = 69
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		_scores.append(value)
		var digit_row: HBoxContainer = HBoxContainer.new()
		digit_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		digit_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		digit_row.offset_left = 46 if side == 0 else 10
		digit_row.offset_right = -10 if side == 0 else -46
		digit_row.offset_top = 33
		digit_row.offset_bottom = 65
		digit_row.alignment = BoxContainer.ALIGNMENT_BEGIN if side == 0 else BoxContainer.ALIGNMENT_END
		digit_row.add_theme_constant_override("separation", 0)
		box.add_child(digit_row)
		_digit_rows.append(digit_row)
		var emblem: TextureRect = TextureRect.new()
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		emblem.position = Vector2(8 if side == 0 else 218, 33)
		emblem.size = Vector2(32, 32)
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(emblem)
		_attribute_icons.append(emblem)
		var portrait: TextureRect = TextureRect.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if side == 0 else Control.PRESET_CENTER_RIGHT)
		portrait.offset_left = 12 if side == 0 else -76
		portrait.offset_right = 76 if side == 0 else -12
		portrait.offset_top = -25
		portrait.offset_bottom = 71
		add_child(portrait)
		_portraits.append(portrait)
		var bar: ProgressBar = ProgressBar.new()
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_left = 10
		bar.offset_right = -10
		bar.offset_top = -12
		bar.offset_bottom = -5
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = OWN if side == 0 else ENEMY
		var native_fill: Texture2D = _native_texture("g_fill_player" if side == 0 else "g_fill_enemy")
		if native_fill != null:
			var fill_texture: StyleBoxTexture = StyleBoxTexture.new()
			fill_texture.texture = native_fill
			bar.add_theme_stylebox_override("fill", fill_texture)
		else:
			bar.add_theme_stylebox_override("fill", fill)
		var empty: StyleBoxFlat = StyleBoxFlat.new()
		empty.bg_color = Color("1c283e")
		bar.add_theme_stylebox_override("background", empty)
		box.add_child(bar)
		_power_bars.append(bar)
	_title = _label(self, "VS", 23)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.offset_left = -56
	_title.offset_right = 56
	_title.offset_top = 36
	_title.offset_bottom = 75
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vs_texture: Texture2D = _native_texture("vs_icon")
	if vs_texture != null:
		_title.hide()
		var vs: TextureRect = TextureRect.new()
		vs.texture = vs_texture
		vs.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vs.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		vs.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		vs.offset_left = -25
		vs.offset_right = 25
		vs.offset_top = 32
		vs.offset_bottom = 82
		vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vs)
	_gate_face = TextureRect.new()
	_gate_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gate_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gate_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gate_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gate_face.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_gate_face.offset_left = -28
	_gate_face.offset_right = 28
	_gate_face.offset_top = -119
	_gate_face.offset_bottom = -45
	add_child(_gate_face)
	_banner = TextureRect.new()
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -240
	_banner.offset_right = 240
	_banner.offset_top = -72
	_banner.offset_bottom = 72
	add_child(_banner)
	_response_prompt = TextureRect.new()
	_response_prompt.texture = _native_texture("ability")
	_response_prompt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_response_prompt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_response_prompt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_response_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_response_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_response_prompt.offset_left = -165
	_response_prompt.offset_right = 165
	_response_prompt.offset_top = -75
	_response_prompt.offset_bottom = -43
	_response_prompt.tooltip_text = "Можно сыграть карту способности или пасовать."
	add_child(_response_prompt)
	_event_label = _label(self, "", 27)
	_event_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_event_label.offset_left = -350
	_event_label.offset_right = 350
	_event_label.offset_top = -35
	_event_label.offset_bottom = 35
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_event_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_event_label.add_theme_constant_override("outline_size", 8)
	_gate_label = _label(self, "", 16)
	_gate_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_gate_label.offset_top = -40
	_gate_label.offset_bottom = -8
	_gate_label.offset_left = 16
	_gate_label.offset_right = -16
	_gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_gate_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_gate_label.add_theme_constant_override("outline_size", 5)
	hide()


func _label(parent: Node, text: String, font_size: int) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", load("res://assets/ui_bold.ttf") as Font)
	result.add_theme_font_size_override("font_size", font_size)
	parent.add_child(result)
	return result

func _build_card_scene() -> void:
	_card_scene = Panel.new()
	_card_scene.name = "NativeCardScene"
	_card_scene.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card_scene.offset_left = -230
	_card_scene.offset_right = 230
	_card_scene.offset_top = -150
	_card_scene.offset_bottom = 200
	_card_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03,0.07,0.12,0.97)
	style.border_color = OWN
	style.set_border_width_all(2)
	_card_scene.add_theme_stylebox_override("panel",style)
	add_child(_card_scene)
	_scene_title = _label(_card_scene,"",22)
	_scene_title.position = Vector2(14,9)
	_scene_title.size = Vector2(432,30)
	_scene_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scene_face = TextureRect.new()
	_scene_face.position = Vector2(16,48)
	_scene_face.size = Vector2(204,284)
	_scene_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scene_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_scene_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_card_scene.add_child(_scene_face)
	_scene_description = _label(_card_scene,"",18)
	_scene_description.position = Vector2(238,70)
	_scene_description.size = Vector2(204,244)
	_scene_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_scene.visible = false

func _apply_sequence_frame() -> void:
	if _card_scene==null: return
	var stage: String = str(snapshot.get("sequence_stage",""))
	_card_scene.visible = stage in ["gate_reveal","ability"]
	for actor: Node3D in actors.values():
		var side: int = int(actor.get_meta("battle_owner",-1))
		actor.visible = stage!="battle_banner" and (stage!="entry_player" or side==0)

func _show_card_scene(event: Dictionary) -> void:
	_scene_title.text = str(event.get("title","КАРТА"))
	_scene_description.text = str(event.get("description",""))
	_scene_face.texture = DSCards.texture(str(event.get("source_key","")))
	_card_scene.visible = true
	move_child(_card_scene,get_child_count()-1)


func _load_native_ui() -> void:
	if FileAccess.file_exists(UI_MANIFEST):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(UI_MANIFEST))
		if value is Dictionary:
			_native_ui = value.get("runtime", {})
			for key: String in value.get("native_portraits", {}):
				_portrait_by_identity[_identity(key)] = value.native_portraits[key]


func _native_texture(key: String) -> Texture2D:
	var entry: Variant = _native_ui.get(key, {})
	var path: String = str(entry.get("path", "")) if entry is Dictionary else str(entry)
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _portrait_texture(species: String, attribute: String) -> Texture2D:
	var entry: Dictionary = _portrait_by_identity.get(_identity(species), {})
	if entry.is_empty():
		# Source labels such as Fortress and Delta Dragonoid II resolve to a
		# canonical monster model; their portrait must follow the same identity.
		var model: Dictionary = ModelCatalog.get_entry(species)
		entry = _portrait_by_identity.get(_identity(str(model.get("key", ""))), {})
	var palette: String = attribute
	for candidate: String in ModelCatalog.ATTRIBUTES:
		if candidate.to_lower() == attribute.to_lower():
			palette = candidate
			break
	var variant: Dictionary = entry.get("attribute_palette_variants", {}).get(palette, {})
	var path: String = str(variant.get("path", entry.get("default_path", "")))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _identity(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("'", "")


func _set_stage(arena_id: String) -> void:
	if _world == null or (stage_id == arena_id and _stage != null):
		return
	stage_id = arena_id
	if is_instance_valid(_stage):
		_world.remove_child(_stage)
		_stage.queue_free()
	_stage = SFMField.make_stage() if arena_id == SFMField.ID else Stages.make_battle_stage(arena_id)
	if _stage != null:
		_world.add_child(_stage)
		camera.far = maxf(150.0, float(_stage.get_meta("ds_far_hint", 2000.0)))


func _sync_actors() -> void:
	var active: Dictionary = {}
	var side_units: Array = [[], []]
	for unit: Dictionary in snapshot.get("units", []):
		var side: int = int(unit.get("owner", -1))
		if side in [0, 1]:
			side_units[side].append(unit)
	for side: int in range(2):
		for index: int in range(side_units[side].size()):
			var unit: Dictionary = side_units[side][index]
			var key: String = "%d:%d" % [side, int(unit.get("index", index))]
			var species: String = str(unit.get("model_name", unit.get("name", "Dragonoid")))
			var attribute: String = str(unit.get("attribute", "Pyrus"))
			active[key] = true
			if actors.has(key) and (str((actors[key] as Node3D).get_meta("presentation_species", "")) != species or str((actors[key] as Node3D).get_meta("presentation_attribute", "")) != attribute):
				_delete_actor(key)
			if not actors.has(key):
				var model: Node3D = Models.make_creature(_actors, species, attribute, true, "battle")
				if model == null:
					continue
				model.set_meta("battle_owner", side)
				model.set_meta("presentation_species", species)
				model.set_meta("presentation_attribute", attribute)
				model.set_meta("battle_unit_index", int(unit.get("index", index)))
				model.set_meta("temporary_clone", unit.get("temporary_clone", false))
				actors[key] = model
				Models.play_battle_animation(model, "idle")
				_anchor_native_body(model)
			var actor: Node3D = actors[key]
			actor.position = Vector3(-3.1 if side == 0 else 3.1, 0.0, (float(index) - float(side_units[side].size() - 1) * 0.5) * 2.8)
			actor.rotation.y = PI / 3.0 if side == 0 else -PI / 3.0
	for key: String in actors.keys():
		if not active.has(key):
			_delete_actor(key)
	_sync_support()


func _anchor_native_body(actor: Node3D) -> void:
	# A long tail shifts mesh bounds far behind the body's pivot. Keep each
	# participant's torso on its own side while retaining the native floor fit.
	if not bool(actor.get_meta("native_geometry", false)):
		return
	var player: AnimationPlayer = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		player.advance(0.0)
	for node: Node in actor.find_children("*", "Skeleton3D", true, false):
		var skeleton: Skeleton3D = node as Skeleton3D
		var bone: int = skeleton.find_bone("Bip01")
		if bone < 0:
			continue
		var body: Vector3 = actor.to_local(skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin)
		var visual: Node3D = actor.get_child(0) as Node3D
		visual.position -= Vector3(body.x, 0.0, body.z)
		return


func _sync_support() -> void:
	var active: Dictionary = {}
	for support: Dictionary in snapshot.get("supports", []):
		if str(support.get("status", "")) not in ["pending", "deployed", "field"]:
			continue
		var side: int = int(support.get("owner", -1))
		if side not in [0, 1] or int(support.get("slot", -1)) != int(snapshot.get("slot", -1)):
			continue
		var signature: String = "%d:%s:%s" % [side, support.get("id", ""), support.get("attribute", "")]
		active[signature] = true
		if not _support_nodes.has(signature):
			# Prefer an actual battle model when present. The asset resolver keeps
			# the open toy as an explicit fallback until that form is imported.
			var model: Node3D = Models.make_creature(_actors, str(support.get("name", "")), str(support.get("attribute", "")), true, "battle")
			if model == null:
				continue
			model.set_meta("battle_owner", side)
			model.set_meta("category", support.get("category", "trap"))
			model.set_meta("support_id", support.get("id", ""))
			model.set_meta("attribute", support.get("attribute", ""))
			model.scale = Vector3.ONE * 0.65
			model.position = Vector3(-3.7 if side == 0 else 3.7, 0.0, 2.0)
			_support_nodes[signature] = model
			Models.play_battle_animation(model, "idle")
			_anchor_native_body(model)
	for key: String in _support_nodes.keys():
		if not active.has(key):
			var model: Node3D = _support_nodes[key]
			_actors.remove_child(model)
			model.queue_free()
			_support_nodes.erase(key)


func _delete_actor(key: String) -> void:
	var actor: Node3D = actors[key]
	_actors.remove_child(actor)
	actor.queue_free()
	actors.erase(key)


func _clear_actors() -> void:
	for key: String in actors.keys():
		_delete_actor(key)
	for node: Node3D in _support_nodes.values():
		_actors.remove_child(node)
		node.queue_free()
	_support_nodes.clear()


func _update_scores() -> void:
	var totals: Array = snapshot.get("totals", [0, 0])
	if totals.size() != 2:
		return
	var maximum: int = maxi(1000, maxi(int(totals[0]), int(totals[1])))
	for side: int in range(2):
		_scores[side].text = "%d G" % int(totals[side])
		_update_native_digits(side, int(totals[side]))
		_power_bars[side].max_value = maximum
		_power_bars[side].value = maxi(0, int(totals[side]))
		var names: PackedStringArray = []
		var attribute: String = ""
		var first_species: String = ""
		for unit: Dictionary in snapshot.get("units", []):
			if int(unit.get("owner", -1)) == side:
				names.append(str(unit.get("name", "")))
				if attribute.is_empty():
					attribute = str(unit.get("attribute", ""))
					first_species = str(unit.get("model_name", unit.get("name", "")))
		_attribute_icons[side].texture = _native_texture("attribute_" + attribute.to_lower())
		_portraits[side].texture = _portrait_texture(first_species, attribute)
		_names[side].text = " + ".join(names)
		_names[side].tooltip_text = _names[side].text
	_title.text = "VS" if phase != "result" else ""


func _update_native_digits(side: int, value: int) -> void:
	var row: HBoxContainer = _digit_rows[side]
	var rendered: String = str(value)
	if str(row.get_meta("value", "")) == rendered:
		return
	row.set_meta("value", rendered)
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	if _native_texture("digit_0") == null:
		_scores[side].show()
		return
	_scores[side].hide()
	for character: String in rendered:
		var texture: Texture2D = _native_texture("digit_" + character if character != "-" else "digit_minus")
		if texture == null:
			continue
		var digit: TextureRect = TextureRect.new()
		digit.texture = texture
		digit.custom_minimum_size = Vector2(30, 30)
		digit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		digit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		digit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(digit)
	var suffix: Label = _label(row, " G", 24)
	suffix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _update_gate() -> void:
	var gate: Dictionary = snapshot.get("gate", {})
	var revealed: bool = bool(gate.get("revealed", false))
	var may_read: bool = revealed or int(gate.get("owner", 1)) == 0
	_gate_label.text = ("ВОРОТА ОТКРЫТЫ · " if revealed else "ЗАКРЫТЫЕ ВОРОТА · ") + (str(gate.get("title", "Карта ворот")) if may_read else "Карта соперника")
	var card_key: String = str(gate.get("key", ""))
	var source_key: String = str(gate.get("source_key", card_key))
	# Reveal native DS cards by their source identity; unrelated anime cards
	# retain their existing presentation and never borrow a DS rule's face.
	if not revealed:
		_gate_face.texture = _native_texture("card_back")
	elif str(DSCards.metadata(source_key).get("kind", "")) == "gate":
		_gate_face.texture = DSCards.texture(source_key)
	else:
		_gate_face.texture = _native_texture(card_key) if card_key.begins_with("gate_") else null
	_gate_face.visible = _gate_face.texture != null
	if phase not in ["intro", "result"]:
		phase = "response"


func _present_event(event: Dictionary) -> void:
	var kind: String = str(event.get("event", ""))
	var side: int = int(event.get("owner", -1))
	match kind:
		"entry":
			_camera_side = side
			_camera_time = float(event.get("duration",0.8))
			_play_side(side,"idle")
		"countdown":
			_show_event("",str(event.title),float(event.duration))
		"gate_scene", "ability_scene":
			_show_card_scene(event)
			_play_all("idle")
		"gate_opened":
			_show_event("gate_open", "ВОРОТА ОТКРЫТЫ!", 0.9)
		"ability_played":
			_show_event("ability_activation", str(event.get("title", "АКТИВАЦИЯ СПОСОБНОСТИ!")), 0.8)
			_camera_side = side
			_camera_time = 0.85
			_play_side(side, "attack")
			_spawn_side_effect(side, "ability")
		"chain_resolved":
			_show_event("ability_activation", "СПОСОБНОСТИ ПРИМЕНЕНЫ", 0.6)
			_play_all("idle")
		"trap_deployed", "trap_played":
			_show_event("stand", str(event.get("name", event.get("title", "ЛОВУШКА В БОЮ"))), 0.85)
			for model: Node3D in _support_nodes.values():
				if int(model.get_meta("battle_owner", -1)) == side:
					_spawn_actor_effect(model, "support")
		"battle_ready", "battle_started", "battle":
			_show_event("battle", "БАКУГАНЫ — В БОЙ!", 1.0)
		"minigame_hit":
			_play_side(side, "attack")
			_play_side(1 - side, "damage")
			_spawn_side_effect(side, "ability")
			_spawn_side_effect(1 - side, "damage")
			_camera_side = side
			_camera_time = 0.6


func _clear_effects() -> void:
	if not is_instance_valid(_effects):
		return
	for effect: Node in _effects.get_children():
		_effects.remove_child(effect)
		effect.queue_free()


func _spawn_side_effect(side: int, kind: String) -> void:
	if side not in [0, 1]:
		return
	for actor: Node3D in actors.values():
		if int(actor.get_meta("battle_owner", -1)) == side:
			_spawn_actor_effect(actor, kind)


func _spawn_actor_effect(actor: Node3D, kind: String) -> void:
	if reduced_motion or not is_instance_valid(_effects):
		return
	# Fast repeated hits have bounded visual cost. Remove the oldest accent
	# without changing the rules, animated participants, or event ordering.
	while _effects.get_child_count() >= 8:
		var oldest: Node = _effects.get_child(0)
		_effects.remove_child(oldest)
		oldest.queue_free()
	var effect: Node3D = BattleAccent.new()
	effect.setup(kind, str(actor.get_meta("attribute", "")))
	effect.position = actor.position
	_effects.add_child(effect)


func _play_side(side: int, animation: String) -> void:
	for actor: Node3D in actors.values():
		if int(actor.get_meta("battle_owner", -1)) == side:
			Models.play_battle_animation(actor, animation)


func _play_all(animation: String) -> void:
	for actor: Node3D in actors.values():
		Models.play_battle_animation(actor, animation)


func _show_event(key: String, text: String, duration: float) -> void:
	_event_time = duration
	var entry: Variant = _native_ui.get(key, {})
	var path: String = str(entry.get("path", "")) if entry is Dictionary else str(entry)
	_banner.texture = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	_banner.visible = _banner.texture != null
	_event_label.text = text
	_event_label.visible = _banner.texture == null or key == "ability_activation" or key == "stand"
	if _banner.visible and _event_label.visible:
		_event_label.offset_top = 76
		_event_label.offset_bottom = 118
	else:
		_event_label.offset_top = -35
		_event_label.offset_bottom = 35


func _process(delta: float) -> void:
	if phase == "closed" or _suspended:
		return
	_elapsed += delta
	if phase == "intro" and _elapsed >= 1.1:
		phase = "response"
	_event_time = maxf(0.0, _event_time - delta)
	_banner.visible = _event_time > 0.0 and _banner.texture != null
	_event_label.visible = _event_time > 0.0 and (_banner.texture == null or _event_label.offset_top > 0)
	_response_prompt.visible = phase == "response" and _event_time <= 0.0 and int(snapshot.get("priority", -1)) == 0
	_camera_time = maxf(0.0, _camera_time - delta)
	if _camera_time > 0.0 and _camera_side in [0, 1] and not reduced_motion:
		var target: Vector3 = Vector3(-1.2 if _camera_side == 0 else 1.2, 1.0, 0.0)
		camera.look_at_from_position(Vector3(-1.3 if _camera_side == 0 else 1.3, 2.8, 8.5), target)
	else:
		_set_overview_camera()
	if phase == "result":
		_result_time = maxf(0.0, _result_time - delta)
		if bool(snapshot.get("native_scratch",false)):
			var victor: int = int(snapshot.get("victor",0))
			if _result_time<=1.75 and _result_native_stage==0:
				_result_native_stage = 1
				_play_side(victor,"win")
				_play_side(1-victor,"lose")
				_show_event("win" if victor==0 else "lose","ПОБЕДА" if victor==0 else "ПОРАЖЕНИЕ",0.85)
			elif _result_time<=0.9 and _result_native_stage==1:
				_result_native_stage = 2
				_show_event("gate_won","КАРТА ТВОЯ" if victor==0 else "КАРТА СОПЕРНИКА",0.9)
		if _result_time <= 0.0:
			reset()


func _set_overview_camera() -> void:
	if camera != null:
		var group_size: int = actors.size()
		camera.look_at_from_position(Vector3(0.0, 3.1, 9.0 if group_size <= 2 else 12.0), Vector3(0.0, 1.2, 0.0))

extends Node3D

const Rules = preload("res://scripts/match_rules.gd")
const BoardLayout = preload("res://scripts/board_layout.gd")
const Arena = preload("res://scripts/arena.gd")
const RollMotion = preload("res://scripts/roll_motion.gd")
const SpecialShots = preload("res://scripts/ds_special_shots.gd")
const FieldCards = preload("res://scripts/ds_field_cards.gd")
const DSSphere = preload("res://scripts/ds_sphere_motion.gd")
const DSGesture = preload("res://scripts/ds_throw_gesture.gd")
const DSProfiles = preload("res://scripts/ds_sphere_profiles.gd")
const DSScratch = preload("res://scripts/ds_minigame.gd")
const ThrowMotion = preload("res://scripts/throw_motion.gd")
const Roster = preload("res://scripts/roster.gd")
const CanonicalCatalog = preload("res://scripts/canonical_catalog.gd")
const TrapCatalog = preload("res://scripts/anime_trap_catalog.gd")
const Tournament = preload("res://scripts/tournament.gd")
const AbilityCatalog = preload("res://scripts/ability_catalog.gd")
const BattleEffects = preload("res://scripts/battle_effects.gd")
const TacticalAI = preload("res://scripts/tactical_ai.gd")
const GateCatalog = preload("res://scripts/gate_catalog.gd")
const ArenaCatalog = preload("res://scripts/arena_catalog.gd")
const GameSettings = preload("res://scripts/game_settings.gd")
const AssetCatalog = preload("res://scripts/asset_catalog.gd")
const ModelLibrary = preload("res://scripts/model_library.gd")
const CardArt = preload("res://scripts/card_art.gd")
const DSCardArt = preload("res://scripts/ds_card_catalog.gd")
const DSPlayableCatalog = preload("res://scripts/ds_playable_catalog.gd")
const MatchStats = preload("res://scripts/match_stats.gd")
const DSBattle = preload("res://scripts/ds_battle_presentation.gd")
const DSFieldObjects = preload("res://scripts/ds_field_objects.gd")
const DSFieldMap = preload("res://scripts/ds_field_map.gd")
const ORANGE = Color("ff9447")
const CYAN = Color("67d7f7")
const WHITE = Color("eaeafa")
const MUTED = Color("939ab8")

const DSMiniCatalog = preload("res://scripts/ds_minigame_catalog.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Checkpoint = preload("res://scripts/match_checkpoint.gd")
const Controls = preload("res://scripts/control_bindings.gd")
const AvatarView = preload("res://scripts/avatar_view.gd")
var controls = Controls.new()
var pad_shoot_target: int=0
var applied_graphics: Array = []
var player_avatar: SubViewportContainer
var enemy_avatar: SubViewportContainer
var tutorial: Panel

const CampaignPanel = preload("res://scripts/campaign_panel.gd")
const Slots = preload("res://scripts/save_slots.gd")
const SaveSlotPanel = preload("res://scripts/save_slot_panel.gd")
var campaign_slot: String="campaign_1"
var free_slot: String="free_1"
var anime_slot: String="anime_1"
var campaign_profiles: Dictionary={}
var slot_settled: Dictionary={}
var save_slot_panel: Panel
var pending_new_slot: String=""
var pending_new_mode: String=""

var campaign = Campaign.new()
var campaign_chapter: int = 0
var enemy_tactic: String = "balanced"
var experience_gained: int = 0
var campaign_panel: Panel
var overlay_campaign: Button
var overlay_resume: Button
var saved_match: Dictionary = {}
var checkpoint_clock: float = 0.0
var checkpoint_phase: String = ""
var checkpoint_error: Error = OK
var restoring_match: bool = false
var pending_timer: SceneTreeTimer
var pending_action: String = ""
var ai_choice: Dictionary = {}
var ds_current_event: Dictionary = {}
var match_token: String = ""
var settled_matches: Array[String] = []
var profile_error: Error = OK

var rules = Rules.new()
var battle_effects = BattleEffects.new()
var arena: Node3D
var rng = RandomNumberGenerator.new()
var phase: String = "menu"
var selected_gate: int = 0
var selected_unit: int = 0
var aim_point = Vector3.ZERO
var charge: float = 0.0
var charging: bool = false
var flight_ball: Node3D
var flight_owner: int = 0
var flight_unit: int = 0
var flight_start = Vector3.ZERO
var flight_end = Vector3.ZERO
var flight_time: float = 0.0
var flight_duration: float = 1.55
var flight_steer = Vector3.ZERO
var ds_sphere = DSSphere.new()
var ds_gesture = DSGesture.new()
var ds_ready_ball: Node3D
var _ds_preview_time: int = -1000
var field_map: Control
var roll_motion = RollMotion.new()
var roll_target = Vector3.ZERO
var roll_time: float = 0.0
var roll_duration: float = 4.2
var roll_bonus: int = 0
var field_damage: int = 0
var pickups: Array[Dictionary] = []
var unit_nodes: Dictionary = {}
var target_marker: MeshInstance3D
var _trajectory_cache_key: Array = []
var trajectory: MeshInstance3D
var dragons: Array[Node3D] = []
var battle_slot: int = -1
var battle_type: String = "timing"
var scratch: Control
var ds_sequence: Array[Dictionary] = []
var ds_sequence_time: float = 0.0
var ds_resume_phase: String = "battle_ready"
var ds_sequence_stage: String = ""
var ds_selected_ability: String = ""
var ds_selected_chain: Array[String] = []
var ds_ai_opportunities: int = 0
var ds_enemy_progress: float = 0.0
var ds_mini_sound_clock: float=0.0
var ds_skip_pending: bool = false
var ds_ai_ability: String = ""
var ds_ai_ability_at: float = 0.0
var battle_time: float = 0.0
var battle_duration: float = 8.0
var battle_points: int = 0
var ability_points: int = 0
var ai_points: int = 0
var ai_target_points: int = 0
var ai_ability_used: bool = false
var used_battle_abilities: bool = false
var hit_cooldown: float = 0.0
var rhythm_phase: float = 0.0
var last_shake_key: int = 0
var battle_level: int = 1
var battle_streak: int = 0
var bonus_mode: bool = false
var timing_sequence: int = 0
var timing_window_active: bool = false
var timing_window_hit: bool = false
var circle_sequence: int = 0
var powered_throw: bool = false
var flight_powered: bool = false
var flight_special: String = ""
var field_effects: Dictionary = FieldCards.initial()
var extra_throw_owner: int = -1
var throw_style: String = "lob"
var flight_style: String = "lob"
var flight_charge: float = 0.0
var sphere_collision_slot: int = -1
var pending_double_slot: int = -1
var opening_resume_owner: int = 0
var shooting_attributes: Array[String] = []
var shooting_positions: Array[Vector2] = []
var shooting_targets: Array[Button] = []
var paused: bool = false
var muted: bool = false
var match_id: int = 0
var wins: int = 0
var losses: int = 0
var selected_roster: Array = [0, 1, 2]
var selected_attributes: Array = ["Pyrus", "Pyrus", "Ventus"]
var selected_deck: Array = [0, 1, 2]
var selected_gate_deck: Array = [0, 1, 2]
# Wii indices remain isolated from the source-backed DS card catalog.
var rules_profile: String = "wii"
var profile_decks: Dictionary = {"wii": {"abilities": [0, 1, 2], "gates": [0, 1, 2]}, "ds": {"abilities": [], "gates": []}}
var profile_rosters: Dictionary = {
	"wii":{"selection":[0,1,2],"attributes":["Pyrus","Pyrus","Ventus"]},
	"ds":{"selection":DSProfiles.starter_indices(Roster.CREATURES),"attributes":["Pyrus","Ventus","Aquos"]},
}
var selected_arena: String = "stadium"
var selected_field_layout: int = 0
var s_power: Array[int] = [0,0]
var preferences: Dictionary = GameSettings.normalize({})
var match_stats = MatchStats.new()
var practice_kind: String = "timing"
var last_battle_result: Dictionary = {}
var feedback_time: float = 0.0
var preview_angle: float = 0.0
var model_camera: Camera3D
var model_preview_bounds: AABB
var last_throw_quality: String = ""
var tournament = Tournament.new()
var match_mode: String = "quick"
var enemy_power_range = Vector2i(90, 205)
var last_recorded_match_id: int = -1
var roster_previews: Array[Node3D] = []
var journal: Array[String] = []

var hud: Control
var ds_battle: Control
var phase_text: Label
var instruction: Label
var score_text: Label
var turn_text: Label
var deck_text: Label
var rules_tip: Label
var log_text: Label
var target_text: Label
var power_bar: ProgressBar
var power_label: Label
var charge_zone: ColorRect
var card_buttons: Array[Button] = []
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var overlay_start: Button
var overlay_exit: Button
var overlay_tournament: Button
var overlay_roster: Button
var overlay_deck: Button
var overlay_gates: Button
var overlay_settings: Button
var overlay_training: Button
var overlay_help: Button
var overlay_quick: Button
var overlay_models: Button
var overlay_cards: Button
var source_card_browser: Control
var overlay_menu: Button
var roster_panel: Panel
var roster_selectors: Array[OptionButton] = []
var attribute_selectors: Array[OptionButton] = []
var roster_power_labels: Array[Label] = []
var roster_source_labels: Array[Label] = []
var deck_panel: Panel
var deck_selectors: Array[OptionButton] = []
var deck_description_labels: Array[Label] = []
var deck_art: Array[TextureRect] = []
var gate_panel: Panel
var gate_selectors: Array[OptionButton] = []
var gate_description_labels: Array[Label] = []
var gate_effect_labels: Array[Label] = []
var gate_art: Array[TextureRect] = []
var ds_minigame_selector: OptionButton
var settings_panel: Panel
var rules_selector: OptionButton
var rules_description: Label
var help_title: Label
var help_body: Label
var arena_selector: OptionButton
var field_layout_selector: OptionButton
var s_power_label: Label
var help_scroll: ScrollContainer
var difficulty_selector: OptionButton
var volume_slider: HSlider
var volume_text: Label
var motion_toggle: CheckButton
var ds_gate_toggle: CheckButton
var arena_description: Label
var help_panel: Panel
var training_panel: Panel
var practice_selector: OptionButton
var model_panel: Panel
var model_name: Label
var model_info: Label
var model_slot: int = 1
var model_catalog_index: int = 1
var model_attribute: String = "Pyrus"
var model_form: String = "toy"
var model_species_selector: OptionButton
var model_attribute_selector: OptionButton
var model_form_buttons: Array[Button] = []
var model_category: String = "all"
var model_category_buttons: Array[Button] = []
var model_world: Node3D
var card_view_panel: Panel
var card_view_title: Label
var card_view_art: TextureRect
var card_view_description: Label
var card_view_kind: String = "gates"
var action_button: Button
var throw_mode_button: Button
var throw_style_button: Button
var mute_button: Button
var arena_text: Label
var battle_detail_text: Label
var battle_feedback: Label
var battle_panel: Panel
var battle_title: Label
var battle_scores: Label
var battle_effects_text: Label
var battle_hint: Label
var battle_progress: ProgressBar
var timing_track: Panel
var timing_cursor: ColorRect
var shooting_target: Button
var result_banner: Label
var audio: Node
var channel_sliders: Dictionary = {}
var font_regular: Font
var font_bold: Font

func _on_joy_connection_changed(_id: int, connected: bool) -> void:
	controls.reset()
	if not connected:
		_cancel_throw_input()
		if is_instance_valid(scratch): scratch.release()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	font_regular = load("res://assets/ui.ttf")
	font_bold = load("res://assets/ui_bold.ttf")
	arena = Arena.new()
	add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	arena.setup()
	_make_aim_visuals()
	_build_hud()
	audio = preload("res://scripts/ds_audio.gd").new()
	add_child(audio)
	audio.set_speaker("chara00")
	_load_profile()
	tutorial=preload("res://scripts/guided_lesson.gd").new()
	hud.add_child(tutorial)
	tutorial.build(self)
	player_avatar=AvatarView.new(); player_avatar.visible=false; player_avatar.position=Vector2(22,572); player_avatar.size=Vector2(156,170)
	hud.add_child(player_avatar)
	player_avatar.show_avatar(str(preferences.avatar))
	enemy_avatar=AvatarView.new(); enemy_avatar.visible=false; enemy_avatar.position=Vector2(1258,572); enemy_avatar.size=Vector2(156,170)
	hud.add_child(enemy_avatar)
	enemy_avatar.show_avatar("chara00")
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var migration: Error=Slots.migrate_legacy(campaign.to_dict())
	if migration!=OK: checkpoint_error=migration
	saved_match = Checkpoint.read()
	get_tree().auto_accept_quit = false
	_show_menu()

func _style(bg: Color, border: Color = Color.TRANSPARENT, width: int = 1, radius: int = 14) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func _panel(parent: Node, pos: Vector2, size: Vector2, bg: Color = Color(0.035, 0.045, 0.09, 0.94)) -> Panel:
	var p = Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(bg, Color(0.25, 0.3, 0.5, 0.38)))
	parent.add_child(p)
	return p

func _label(parent: Node, text: String, pos: Vector2, size: Vector2, font_size: int = 18, color: Color = WHITE, bold: bool = false) -> Label:
	var l = Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font_bold if bold else font_regular)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	l.size = size
	l.text = text
	l.size = size
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, pos: Vector2, size: Vector2, color: Color = ORANGE) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_stylebox_override("normal", _style(Color(0.08, 0.09, 0.16, 0.98), color.darkened(0.5)))
	b.add_theme_stylebox_override("hover", _style(Color(0.16, 0.16, 0.23, 1.0), color, 2))
	b.add_theme_stylebox_override("pressed", _style(color.darkened(0.65), color, 2))
	b.add_theme_stylebox_override("disabled", _style(Color(0.06, 0.07, 0.1, 0.8), Color(0.14, 0.16, 0.23)))
	parent.add_child(b)
	return b

func _build_hud() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var top = _panel(hud, Vector2(24, 22), Vector2(1392, 94))
	_label(top, "BAKUGAN", Vector2(20, 9), Vector2(330, 42), 31, ORANGE, true)
	_label(top, "BATTLE BRAWLERS  /  ARENA", Vector2(22, 54), Vector2(385, 24), 13, MUTED, true)
	score_text = _label(top, "ТЫ   0 / 3     —     0 / 3   СОПЕРНИК", Vector2(400, 20), Vector2(680, 43), 26, WHITE, true)
	score_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mute_button = _button(top, "ЗВУК", Vector2(1145, 22), Vector2(95, 46), CYAN)
	mute_button.pressed.connect(func():
		muted = not muted
		_apply_settings()
		_save_profile())
	var pause_button = _button(top, "II", Vector2(1254, 22), Vector2(96, 46), CYAN)
	pause_button.pressed.connect(_toggle_pause)
	var left = _panel(hud, Vector2(24, 144), Vector2(232, 475))
	_label(left, "МАТЧ АРЕНЫ", Vector2(18, 19), Vector2(208, 30), 19, ORANGE, true)
	_label(left, "ПЕРВЫЙ ДО ТРЁХ КАРТ", Vector2(18, 54), Vector2(206, 25), 11, MUTED, true)
	turn_text = _label(left, "Твой ход", Vector2(18, 104), Vector2(202, 45), 24, WHITE, true)
	deck_text = _label(left, "", Vector2(18, 159), Vector2(203, 135), 14, MUTED)
	deck_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(left, "КАК ПОБЕДИТЬ", Vector2(18, 313), Vector2(200, 25), 13, CYAN, true)
	rules_tip = _label(left, "", Vector2(18, 347), Vector2(200, 114), 13, MUTED)
	rules_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arena_text = _label(hud, "", Vector2(274, 121), Vector2(892, 25), 13, CYAN, true)
	arena_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var right = _panel(hud, Vector2(1184, 144), Vector2(232, 475))
	_label(right, "ХОД МАТЧА", Vector2(18, 19), Vector2(210, 30), 19, CYAN, true)
	log_text = _label(right, "", Vector2(18, 69), Vector2(200, 385), 15, MUTED)
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_text.clip_text = true
	log_text.max_lines_visible = 16
	field_map = DSFieldMap.new()
	field_map.placement_requested.connect(func(slot: int) -> void:
		if phase=="double": _resolve_double(slot)
		else: _place_player_gate(slot))
	field_map.game = self
	field_map.position = Vector2(18,65)
	field_map.size = Vector2(196,170)
	field_map.visible = false
	right.add_child(field_map)
	field_map.aim_requested.connect(func(point: Vector3):
		if phase=="aim" and not paused:
			aim_point = arena.clamp_aim(point)
			if is_instance_valid(tutorial): tutorial.observe("aim")
			_update_aim(0))
	phase_text = _label(hud, "", Vector2(274, 646), Vector2(892, 42), 26, WHITE, true)
	phase_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_text.add_theme_constant_override("outline_size",4)
	phase_text.add_theme_color_override("font_outline_color",Color("080d18"))
	instruction = _label(hud, "", Vector2(258, 690), Vector2(925, 45), 16, MUTED)
	instruction.add_theme_color_override("font_color",WHITE)
	instruction.add_theme_color_override("font_shadow_color",Color("050914"))
	instruction.add_theme_constant_override("shadow_offset_x",2)
	instruction.add_theme_constant_override("shadow_offset_y",2)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bottom = _panel(hud, Vector2(24, 752), Vector2(1392, 122))
	for i in range(3):
		var b = _button(bottom, "", Vector2(16 + i * 279, 13), Vector2(265, 94))
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_choose_card.bind(i))
		card_buttons.append(b)
	power_label = _label(bottom, "СИЛА БРОСКА", Vector2(870, 13), Vector2(470, 28), 14, ORANGE, true)
	power_bar = ProgressBar.new()
	power_bar.position = Vector2(871, 52)
	power_bar.size = Vector2(470, 18)
	power_bar.show_percentage = false
	power_bar.step = 0.0
	power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_bar.add_theme_stylebox_override("background", _style(Color("20253a"), Color.TRANSPARENT, 0, 5))
	power_bar.add_theme_stylebox_override("fill", _style(ORANGE, Color.TRANSPARENT, 0, 5))
	bottom.add_child(power_bar)
	var zone = ColorRect.new()
	charge_zone = zone
	zone.color = Color(0.4, 1.0, 0.75, 0.4)
	zone.position = Vector2(871 + 470 * 0.62, 49)
	zone.size = Vector2(470 * 0.16, 24)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(zone)
	target_text = _label(bottom, "", Vector2(870, 78), Vector2(480, 26), 12, MUTED)
	_label(hud, "Bakugan Arena  •  v"+str(ProjectSettings.get_setting("application/config/version")).trim_suffix(".0"), Vector2(29, 878), Vector2(450, 21), 10, MUTED)
	s_power_label = _label(hud,"",Vector2(24,620),Vector2(232,23),13,CYAN,true)
	var controls = _label(hud, "МЫШЬ — цель   ·   ПРОБЕЛ — бросок   ·   T — траектория   ·   P — усиление   ·   WASD — движение   ·   SHIFT — тормоз   ·   ESC — пауза", Vector2(440, 878), Vector2(970, 21), 10, MUTED)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_button = _button(hud, "БРОСИТЬ БЕЗ КАРТЫ", Vector2(1184, 645), Vector2(232, 74), CYAN)
	action_button.pressed.connect(_phase_action)
	action_button.visible = false
	throw_style_button = _button(hud, "ВЫСОКИЙ БРОСОК · T", Vector2(24, 645), Vector2(232, 35), CYAN)
	throw_style_button.add_theme_font_size_override("font_size", 14)
	throw_style_button.pressed.connect(_toggle_throw_style)
	throw_style_button.visible = false
	throw_mode_button = _button(hud, "БЕЗ УСИЛЕНИЯ · P", Vector2(24, 687), Vector2(232, 35), ORANGE)
	throw_mode_button.add_theme_font_size_override("font_size", 14)
	throw_mode_button.pressed.connect(_toggle_throw_mode)
	throw_mode_button.visible = false
	ds_battle = DSBattle.new()
	hud.add_child(ds_battle)
	ds_battle.configure(str(arena.theme_id), bool(preferences.reduced_motion))
	# Keep the battle stage between the match sidebars and above the minigame.
	ds_battle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ds_battle.position = Vector2(274, 148)
	ds_battle.size = Vector2(892, 300)
	_build_battle_panel()
	_build_overlay()
	_build_roster_panel()
	_build_deck_panel()
	_build_gate_panel()
	_build_settings_panel()
	_build_help_panel()
	_build_training_panel()
	_build_model_panel()
	_build_card_view()
	result_banner = _label(hud, "", Vector2(330, 370), Vector2(780, 130), 37, ORANGE, true)
	result_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_banner.visible = false

func _build_battle_panel() -> void:
	battle_panel = _panel(hud, Vector2(274, 453), Vector2(892, 190), Color(0.025, 0.03, 0.065, 0.94))
	battle_panel.visible = false
	battle_title = _label(battle_panel, "БОЙ БАКУГАНОВ", Vector2(18, 7), Vector2(856, 25), 17, ORANGE, true)
	battle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_scores = _label(battle_panel, "", Vector2(20, 70), Vector2(747, 62), 18, WHITE, true)
	battle_scores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The DS presentation displays the two live G totals beside its 3D stage.
	battle_scores.visible = false
	battle_effects_text = _label(battle_panel, "", Vector2(18, 34), Vector2(856, 23), 13, CYAN)
	battle_effects_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_detail_text = _label(battle_panel, "", Vector2(18, 60), Vector2(856, 57), 14, MUTED)
	battle_detail_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_hint = _label(battle_panel, "", Vector2(18, 126), Vector2(856, 45), 14, MUTED)
	battle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timing_track = _panel(battle_panel, Vector2(138, 128), Vector2(616, 24), Color("252d48"))
	var zone = ColorRect.new()
	zone.position = Vector2(252, 0)
	zone.size = Vector2(112, 24)
	zone.color = Color("3e9b79")
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timing_track.add_child(zone)
	timing_cursor = ColorRect.new()
	timing_cursor.color = Color("ffe8bc")
	timing_cursor.size = Vector2(9, 32)
	timing_cursor.position = Vector2(0, -4)
	timing_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timing_track.add_child(timing_cursor)
	shooting_target = _button(battle_panel, "+", Vector2(378, 128), Vector2(110, 30), ORANGE)
	shooting_target.pressed.connect(_shoot_target)
	shooting_target.visible = false
	shooting_targets.append(shooting_target)
	shooting_target.add_theme_font_size_override("font_size", 11)
	shooting_target.size = Vector2(110, 30)
	for index in range(1, 3):
		var target: Button = _button(battle_panel, "", Vector2(80 + index * 298, 128), Vector2(110, 30), CYAN)
		target.add_theme_font_size_override("font_size", 11)
		target.size = Vector2(110, 30)
		target.pressed.connect(_shoot_target.bind(index))
		target.visible = false
		shooting_targets.append(target)
	for target: Button in shooting_targets:
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var compact_style: StyleBoxFlat = target.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			compact_style.content_margin_top = 4
			compact_style.content_margin_bottom = 4
			compact_style.content_margin_left = 6
			compact_style.content_margin_right = 6
			target.add_theme_stylebox_override(state, compact_style)
		target.size = Vector2(110, 30)
	battle_feedback = _label(battle_panel, "", Vector2(18, 164), Vector2(856, 20), 11, ORANGE, true)
	battle_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_progress = ProgressBar.new()
	scratch = DSScratch.new()
	scratch.position = Vector2(240,170)
	scratch.size = Vector2(412,146)
	scratch.visible = false
	battle_panel.add_child(scratch)
	battle_progress.position = Vector2(18, 185)
	battle_progress.show_percentage = false
	battle_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Panel padding would force this thin timer to a 24-pixel minimum height.
	for state: String in ["fill", "background"]:
		var timer_style := StyleBoxFlat.new()
		timer_style.bg_color = CYAN if state == "fill" else Color("212841")
		timer_style.set_corner_radius_all(2)
		timer_style.set_content_margin_all(0)
		battle_progress.add_theme_stylebox_override(state, timer_style)
	battle_panel.add_child(battle_progress)
	battle_progress.size = Vector2(856, 4)

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(overlay)
	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.012, 0.018, 0.04, 0.79)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	var box = _panel(overlay, Vector2(365, 100), Vector2(710, 690), Color(0.036, 0.045, 0.095, 0.97))
	_label(box, "BAKUGAN  /  BATTLE BRAWLERS", Vector2(34, 26), Vector2(642, 29), 18, ORANGE, true)
	overlay_title = _label(box, "АРЕНА БАКУГАНОВ", Vector2(34, 87), Vector2(642, 82), 35, WHITE, true)
	overlay_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body = _label(box, "", Vector2(34, 187), Vector2(642, 210), 18, MUTED)
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_start = _button(box, "НАЧАТЬ МАТЧ", Vector2(34, 426), Vector2(395, 73), ORANGE)
	overlay_start.add_theme_font_size_override("font_size", 20)
	overlay_start.pressed.connect(_overlay_primary)
	overlay_exit = _button(box, "ВЫХОД", Vector2(448, 426), Vector2(228, 73), CYAN)
	overlay_exit.pressed.connect(_quit_game)
	overlay_tournament = _button(box, "ТУРНИР", Vector2(448, 382), Vector2(228, 60), CYAN)
	overlay_tournament.pressed.connect(func():
		if tournament.active:
			_continue_tournament()
		else:
			_start_tournament())
	overlay_roster = _button(box, "СОСТАВ КОМАНДЫ", Vector2(34, 461), Vector2(395, 60), ORANGE)
	overlay_roster.pressed.connect(_open_roster)
	overlay_deck = _button(box, "КОЛОДА СПОСОБНОСТЕЙ", Vector2(365, 444), Vector2(311, 58), CYAN)
	overlay_deck.add_theme_font_size_override("font_size", 15)
	overlay_deck.pressed.connect(_open_deck)
	overlay_gates = _button(box, "КАРТЫ ВОРОТ", Vector2(34, 450), Vector2(311, 54), ORANGE)
	overlay_gates.pressed.connect(_open_gates)
	overlay_settings = _button(box, "АРЕНА И НАСТРОЙКИ", Vector2(365, 450), Vector2(311, 54), CYAN)
	overlay_settings.pressed.connect(_open_settings)
	overlay_training = _button(box, "ТРЕНИРОВКА", Vector2(34, 512), Vector2(311, 54), ORANGE)
	overlay_training.pressed.connect(_open_training)
	overlay_help = _button(box, "КАК ИГРАТЬ", Vector2(365, 512), Vector2(311, 54), CYAN)
	overlay_help.pressed.connect(_open_help)
	overlay_quick = _button(box, "МАТЧ WII", Vector2.ZERO, Vector2(311, 54), CYAN)
	overlay_quick.pressed.connect(_start_quick_match)
	overlay_models = _button(box, "КОЛЛЕКЦИЯ БАКУГАНОВ", Vector2.ZERO, Vector2(311, 54), CYAN)
	overlay_models.add_theme_font_size_override("font_size", 15)
	overlay_models.pressed.connect(_open_model.bind(1))
	overlay_cards = _button(box, "КОЛЛЕКЦИЯ КАРТ", Vector2.ZERO, Vector2(311, 54), ORANGE)
	overlay_cards.pressed.connect(_open_source_cards)
	overlay_menu = _button(box, "В ГЛАВНОЕ МЕНЮ", Vector2(34, 510), Vector2(642, 32), CYAN)
	overlay_menu.add_theme_font_size_override("font_size", 13)
	overlay_menu.pressed.connect(_return_to_menu)
	overlay_campaign = _button(box,"КАМПАНИЯ · 7 ГЛАВ",Vector2.ZERO,Vector2(311,54),ORANGE)
	overlay_campaign.pressed.connect(_open_campaign)
	overlay_resume = _button(box,"ПРОДОЛЖИТЬ МАТЧ",Vector2.ZERO,Vector2(311,54),CYAN)
	overlay_resume.pressed.connect(_open_saves)
	campaign_panel = CampaignPanel.new()
	hud.add_child(campaign_panel)
	campaign_panel.configure(self)
	save_slot_panel=SaveSlotPanel.new()
	hud.add_child(save_slot_panel)
	save_slot_panel.configure(self)

func _set_overlay_menu_layout(menu: bool) -> void:
	overlay_campaign.visible = menu
	overlay_resume.visible = menu
	overlay_resume.disabled = false
	var box: Panel = overlay_start.get_parent() as Panel
	box.position = Vector2(365,65) if menu else Vector2(365,100)
	box.size = Vector2(710,754) if menu else Vector2(710,690)
	overlay_tournament.visible = menu
	overlay_roster.visible = menu
	overlay_deck.visible = menu
	overlay_gates.visible = menu
	overlay_settings.visible = menu
	overlay_training.visible = menu
	overlay_help.visible = menu
	overlay_quick.visible = menu
	overlay_models.visible = menu
	overlay_cards.visible = menu
	overlay_menu.visible = not menu
	overlay_start.position = Vector2(34, 318 if menu else 496)
	overlay_start.size = Vector2(311, 54) if menu else Vector2(395, 73)
	overlay_quick.position = Vector2(365, 318)
	overlay_tournament.position = Vector2(34, 550)
	overlay_tournament.size = Vector2(311, 54)
	overlay_roster.position = Vector2(34, 376)
	overlay_roster.size = Vector2(311, 54)
	overlay_models.position = Vector2(365, 376)
	overlay_cards.position = Vector2(34, 434)
	overlay_settings.position = Vector2(365, 434)
	overlay_gates.position = Vector2(34, 492)
	overlay_deck.position = Vector2(365, 492)
	overlay_deck.size = Vector2(311, 54)
	overlay_training.position = Vector2(365, 550)
	overlay_campaign.position = Vector2(34,608)
	overlay_resume.position = Vector2(365,608)
	overlay_help.position = Vector2(34, 666)
	overlay_exit.position = Vector2(365, 666) if menu else Vector2(448, 496)
	overlay_exit.size = Vector2(311, 54) if menu else Vector2(228, 73)
	overlay_menu.position = Vector2(34, 605)
	overlay_body.position = Vector2(34, 173 if menu else 187)
	overlay_body.size = Vector2(642, 136 if menu else 290)
	overlay_body.add_theme_font_size_override("font_size", 16 if menu else 18)

func _option(parent: Node, position: Vector2, width: float) -> OptionButton:
	var option = OptionButton.new()
	option.position = position
	option.size = Vector2(width, 46)
	option.focus_mode = Control.FOCUS_ALL
	option.fit_to_longest_item = false
	option.add_theme_font_override("font", font_bold)
	option.add_theme_font_size_override("font_size", 17)
	option.add_theme_color_override("font_color", WHITE)
	option.add_theme_stylebox_override("normal", _style(Color("151c32"), Color("4b5476")))
	option.add_theme_stylebox_override("hover", _style(Color("25304b"), ORANGE, 2))
	option.add_theme_stylebox_override("pressed", _style(Color("283352"), CYAN, 2))
	option.get_popup().add_theme_font_override("font", font_regular)
	option.get_popup().add_theme_font_size_override("font_size", 18)
	option.get_popup().max_size = Vector2i(800, 450)
	parent.add_child(option)
	return option

func _build_roster_panel() -> void:
	roster_panel = _panel(hud, Vector2(302, 148), Vector2(836, 470), Color(0.035, 0.045, 0.09, 0.98))
	roster_panel.visible = false
	_label(roster_panel, "СОСТАВ КОМАНДЫ", Vector2(25, 19), Vector2(780, 40), 27, ORANGE, true)
	_label(roster_panel, "99 видов. Родные стихии партнёров закреплены; обычные виды сохраняют варианты.", Vector2(25, 64), Vector2(780, 29), 15, MUTED)
	for slot in range(3):
		var card = _panel(roster_panel, Vector2(24 + slot * 264, 108), Vector2(248, 270))
		_label(card, "ПОЗИЦИЯ %d" % (slot + 1), Vector2(12, 10), Vector2(222, 22), 12, CYAN, true)
		var creature = _option(card, Vector2(12, 41), 224)
		for entry in Roster.CREATURES:
			creature.add_item(str(entry.name))
		creature.item_selected.connect(_roster_selection_from_ui.bind(slot))
		roster_selectors.append(creature)
		var attribute = _option(card, Vector2(12, 100), 224)
		for name in Roster.ATTRIBUTES:
			attribute.add_item(str(name))
		attribute.item_selected.connect(_attribute_selection_from_ui.bind(slot))
		attribute_selectors.append(attribute)
		roster_power_labels.append(_label(card, "", Vector2(13, 157), Vector2(220, 26), 15, ORANGE, true))
		var source_note: Label = _label(card, "", Vector2(13, 185), Vector2(220, 42), 12, MUTED)
		source_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		source_note.max_lines_visible = 3
		roster_source_labels.append(source_note)
		var inspect = _button(card, "ПРОСМОТР МОДЕЛИ", Vector2(12, 232), Vector2(224, 28), CYAN)
		inspect.add_theme_font_size_override("font_size", 12)
		inspect.pressed.connect(_open_model.bind(slot))
	var done = _button(roster_panel, "СОХРАНИТЬ И ВЕРНУТЬСЯ", Vector2(24, 395), Vector2(788, 53), CYAN)
	done.pressed.connect(_close_roster)

func _open_roster() -> void:
	phase = "roster"
	_hide_preparation_panels()
	overlay.visible = false
	deck_panel.visible = false
	roster_panel.visible = true
	target_marker.visible = false
	trajectory.visible = false
	phase_text.visible = false
	instruction.text = "Стрелки ← → вращают модели. Повторный выбор меняет позиции. ESC — сохранить и вернуться."
	_refresh_roster_ui()
	_update_cards()

func _close_roster() -> void:
	_save_profile()
	_show_menu()

func _roster_selection_from_ui(catalog_index: int, slot: int) -> void:
	_select_roster_slot(slot, catalog_index)

func _attribute_selection_from_ui(attribute_index: int, slot: int) -> void:
	_select_attribute(slot, attribute_index)

func _select_roster_slot(slot: int, catalog_index: int) -> void:
	if slot < 0 or slot >= 3 or catalog_index < 0 or catalog_index >= Roster.CREATURES.size():
		return
	var previous: int = int(selected_roster[slot])
	var other: int = selected_roster.find(catalog_index)
	if other >= 0 and other != slot:
		selected_roster[other] = previous
	selected_roster[slot] = catalog_index
	_refresh_roster_ui()
	_save_profile()

func _select_attribute(slot: int, attribute_index: int) -> void:
	if slot < 0 or slot >= 3 or attribute_index < 0 or attribute_index >= Roster.ATTRIBUTES.size():
		return
	var creature_id: String = str(Roster.CREATURES[int(selected_roster[slot])].id)
	var attribute: String = str(Roster.ATTRIBUTES[attribute_index])
	if not CanonicalCatalog.allowed_attributes(creature_id).has(attribute):
		return
	selected_attributes[slot] = attribute
	_refresh_roster_ui()
	_save_profile()

func _refresh_roster_ui() -> void:
	selected_attributes = Roster.normalize_selection_attributes(selected_roster, selected_attributes)
	for slot in range(3):
		var entry: Dictionary = Roster.CREATURES[int(selected_roster[slot])]
		var descriptor: Dictionary = CanonicalCatalog.resolve(str(entry.id), str(selected_attributes[slot]), int(entry.g))
		var native_motion: Dictionary = DSProfiles.resolve({"species_id":entry.id,"attribute":selected_attributes[slot],"g":descriptor.g})
		if rules_profile=="ds" and bool(native_motion.verified):
			descriptor.g = int(native_motion.g)
		roster_selectors[slot].select(int(selected_roster[slot]))
		attribute_selectors[slot].select(Roster.ATTRIBUTES.find(selected_attributes[slot]))
		attribute_selectors[slot].disabled = bool(descriptor.attribute_locked)
		for index: int in range(Roster.ATTRIBUTES.size()):
			attribute_selectors[slot].set_item_disabled(index, not descriptor.allowed_attributes.has(Roster.ATTRIBUTES[index]))
		attribute_selectors[slot].tooltip_text = "Родная стихия этого партнёра закреплена. Другие расцветки доступны в коллекции." if descriptor.attribute_locked else "Выбери вариант вида. Подтверждённость стихии и силы отмечена ниже."
		roster_power_labels[slot].text = "%d G · %s" % [int(descriptor.g), "по источнику" if descriptor.g_verified else "условная сила"]
		if rules_profile=="ds":
			roster_power_labels[slot].text = "%d G · %s" % [int(descriptor.g),"DS" if bool(native_motion.verified) else "ПК"]
			roster_power_labels[slot].tooltip_text = "Скорость / защита / контроль / поворот / магнит\n"+DSProfiles.describe(native_motion)+("\nНачальные параметры DS." if bool(native_motion.verified) else "\nВременные параметры ПК.")
		var notes: Array[String] = []
		if descriptor.unsupported_native_attribute:
			notes.append("Родная стихия: %s; вариант условный." % str(descriptor.native_attribute))
		elif descriptor.attribute_locked:
			notes.append("Родная стихия партнёра: " + str(descriptor.attribute))
		elif not descriptor.attribute_verified:
			notes.append("Расцветка игрушки; в аниме не подтверждена.")
		else:
			notes.append("Стихия по источнику.")
		if not descriptor.g_verified:
			notes.append("Исходная G не подтверждена.")
		elif not str(descriptor.variant_label).is_empty():
			notes.append(str(descriptor.variant_label))
		roster_source_labels[slot].text = " ".join(notes)
		roster_source_labels[slot].tooltip_text = str(descriptor.g_note) + "\n" + str(descriptor.source_url) + "\n" + str(descriptor.excerpt)
	if phase == "roster":
		_refresh_roster_previews()

func _refresh_roster_previews() -> void:
	_clear_roster_previews()
	for slot in range(3):
		var stand = Node3D.new()
		arena.add_child(stand)
		var entry: Dictionary = Roster.CREATURES[int(selected_roster[slot])]
		var creature: Node3D = arena.make_creature(str(entry.name), str(selected_attributes[slot]))
		creature.reparent(stand, false)
		stand.position = _screen_stage_position(0.34 + float(slot) * 0.16, 0.73)
		stand.scale = Vector3.ONE * 0.85
		stand.rotation.y = preview_angle
		roster_previews.append(stand)

func _clear_roster_previews() -> void:
	for node in roster_previews:
		if is_instance_valid(node):
			node.visible = false
			node.queue_free()
	roster_previews.clear()

func _profile_cards(kind: String) -> Array:
	if rules_profile == "ds":
		return DSPlayableCatalog.cards(kind)
	return GateCatalog.CARDS if kind == "gate" else AbilityCatalog.CARDS

func _profile_indices(kind: String, color: String) -> Array:
	if rules_profile == "ds":
		return DSPlayableCatalog.indices_for_color(kind, color)
	return GateCatalog.indices_for_color(color) if kind == "gate" else AbilityCatalog.indices_for_color(color)

func _normalize_deck(kind: String, selection: Array, profile: String = "") -> Array:
	var target_profile: String = rules_profile if profile.is_empty() else profile
	if target_profile == "ds":
		return DSPlayableCatalog.normalize_selection(kind, selection)
	return GateCatalog.normalize_selection(selection) if kind == "gate" else AbilityCatalog.normalize_selection(selection)

func _make_profile_deck(kind: String, selection: Array, owner: int) -> Array:
	if rules_profile == "ds":
		return DSPlayableCatalog.make_deck(kind, selection, owner)
	return GateCatalog.make_deck(selection, owner) if kind == "gate" else AbilityCatalog.make_deck(selection, owner)

func _enemy_profile_deck(kind: String, stage: int) -> Array:
	if rules_profile == "ds":
		return DSPlayableCatalog.enemy_deck(kind, stage)
	return GateCatalog.enemy_deck(stage) if kind == "gate" else AbilityCatalog.enemy_deck(stage)

func _profile_card_texture(card: Dictionary, kind: String, index: int = -1) -> Texture2D:
	var source_key: String = str(card.get("source_key", ""))
	if not source_key.is_empty():
		return DSCardArt.texture(source_key)
	if index < 0:
		index = CardArt.index_for_gate_key(str(card.get("key", ""))) if kind == "gate" else CardArt.index_for_ability_key(str(card.get("key", "")))
	return CardArt.gate_texture(index) if kind == "gate" else CardArt.ability_texture(index)

func _ds_profile_available() -> bool:
	for kind: String in ["gate", "ability"]:
		var selection: Array = DSPlayableCatalog.normalize_selection(kind, [])
		if selection.size() != 3 or DSPlayableCatalog.make_deck(kind, selection, 0).size() != 3:
			return false
	return true

func _store_current_decks() -> void:
	profile_decks[rules_profile] = {
		"abilities": _normalize_deck("ability", selected_deck),
		"gates": _normalize_deck("gate", selected_gate_deck),
	}
	profile_rosters[rules_profile] = {"selection":Roster.normalize_selection(selected_roster),"attributes":selected_attributes.duplicate()}

func _ds_selection_keys(kind: String, selection: Array) -> Array[String]:
	var result: Array[String] = []
	var cards: Array = DSPlayableCatalog.cards(kind)
	for index: int in DSPlayableCatalog.normalize_selection(kind, selection):
		result.append(str(cards[index].get("source_key", cards[index].get("key", ""))))
	return result

func _ds_selection_from_keys(kind: String, keys: Array) -> Array:
	var result: Array = []
	var cards: Array = DSPlayableCatalog.cards(kind)
	for key: Variant in keys:
		var found: int = -1
		for index in range(cards.size()):
			if str(cards[index].get("source_key", cards[index].get("key", ""))) == str(key):
				found = index
				break
		result.append(found)
	return DSPlayableCatalog.normalize_selection(kind, result)

func _select_rules_profile(index: int) -> void:
	if phase != "settings" or index < 0 or index > 1:
		return
	_set_rules_profile("ds" if index == 0 else "wii")
	_refresh_settings_ui()
	_save_profile()

func _set_rules_profile(profile: String) -> void:
	var target: String = "ds" if profile == "ds" and _ds_profile_available() else "wii"
	_store_current_decks()
	rules_profile = target
	var team: Dictionary = profile_rosters[target]
	selected_roster = Roster.normalize_selection(team.selection)
	selected_attributes = Roster.normalize_selection_attributes(selected_roster,team.attributes)
	if target=="ds" and not selected_arena.begins_with("ds_"):
		selected_arena = "ds_toy"
	var saved: Dictionary = profile_decks.get(target, {})
	selected_deck = _normalize_deck("ability", saved.get("abilities", []))
	selected_gate_deck = _normalize_deck("gate", saved.get("gates", []))
	_rebuild_card_selectors()
	_refresh_deck_ui()
	_refresh_gate_ui()
	_refresh_hud()

func _rebuild_card_selectors() -> void:
	for kind: String in ["gate", "ability"]:
		var selectors: Array = gate_selectors if kind == "gate" else deck_selectors
		var colors: Array = ["gold", "silver", "copper"] if kind == "gate" else ["red", "green", "blue"]
		var cards: Array = _profile_cards(kind)
		for slot in range(selectors.size()):
			var selector: OptionButton = selectors[slot]
			selector.clear()
			for index: int in _profile_indices(kind, colors[slot]):
				selector.add_item(str(cards[index].title))
				selector.set_item_metadata(selector.item_count - 1, index)

func _build_deck_panel() -> void:
	deck_panel = _panel(hud, Vector2(250, 148), Vector2(940, 430), Color(0.035, 0.045, 0.09, 0.98))
	deck_panel.visible = false
	_label(deck_panel, "КОЛОДА СПОСОБНОСТЕЙ", Vector2(24, 19), Vector2(892, 40), 27, CYAN, true)
	_label(deck_panel, "Одна красная, зелёная и синяя карта. Учитывай условия каждой способности.", Vector2(24, 66), Vector2(892, 28), 16, MUTED)
	for slot in range(3):
		var card = _panel(deck_panel, Vector2(24 + slot * 304, 110), Vector2(284, 222))
		_label(card, ["КРАСНАЯ", "ЗЕЛЁНАЯ", "СИНЯЯ"][slot], Vector2(12, 10), Vector2(260, 22), 12, ORANGE, true)
		var selector = _option(card, Vector2(12, 42), 260)
		selector.add_theme_font_size_override("font_size", 15)
		for index in _profile_indices("ability", ["red", "green", "blue"][slot]):
			selector.add_item(str(_profile_cards("ability")[index].title))
			selector.set_item_metadata(selector.item_count - 1, index)
		selector.item_selected.connect(_deck_selection_from_ui.bind(slot))
		deck_selectors.append(selector)
		var artwork: TextureRect = _card_image(card, Vector2(12, 101), Vector2(84, 112))
		artwork.mouse_filter = Control.MOUSE_FILTER_STOP
		artwork.tooltip_text = "Нажми, чтобы рассмотреть карту."
		artwork.gui_input.connect(_card_art_input.bind("abilities", slot))
		deck_art.append(artwork)
		var description = _label(card, "", Vector2(108, 103), Vector2(164, 106), 14, WHITE)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		deck_description_labels.append(description)
	var done = _button(deck_panel, "СОХРАНИТЬ И ВЕРНУТЬСЯ", Vector2(24, 354), Vector2(892, 53), CYAN)
	done.pressed.connect(_close_deck)

func _open_deck() -> void:
	phase = "deck"
	_hide_preparation_panels()
	_clear_roster_previews()
	roster_panel.visible = false
	overlay.visible = false
	deck_panel.visible = true
	target_marker.visible = false
	trajectory.visible = false
	phase_text.visible = false
	instruction.text = "Каждая позиция содержит карту своего цвета. ESC — сохранить и вернуться."
	_refresh_deck_ui()
	_update_cards()

func _close_deck() -> void:
	_save_profile()
	_show_menu()

func _deck_selection_from_ui(option_index: int, slot: int) -> void:
	_select_deck_slot(slot, int(deck_selectors[slot].get_item_metadata(option_index)))

func _select_deck_slot(slot: int, catalog_index: int) -> void:
	if slot < 0 or slot >= 3 or catalog_index < 0 or catalog_index >= _profile_cards("ability").size():
		return
	var colors: Array = ["red", "green", "blue"]
	if not _profile_indices("ability", colors[slot]).has(catalog_index):
		return
	selected_deck = _normalize_deck("ability", selected_deck)
	selected_deck[slot] = catalog_index
	_refresh_deck_ui()
	_save_profile()

func _refresh_deck_ui() -> void:
	selected_deck = _normalize_deck("ability", selected_deck)
	for slot in range(3):
		var index: int = int(selected_deck[slot])
		for option_index in range(deck_selectors[slot].item_count):
			if int(deck_selectors[slot].get_item_metadata(option_index)) == index:
				deck_selectors[slot].select(option_index)
		var card: Dictionary = _profile_cards("ability")[index]
		deck_description_labels[slot].text = str(card.description)
		deck_art[slot].texture = _profile_card_texture(card, "ability", index)

func _hide_preparation_panels() -> void:
	instruction.show()
	for panel in [roster_panel, deck_panel, gate_panel, settings_panel, help_panel, training_panel, model_panel, card_view_panel, campaign_panel, save_slot_panel]:
		if is_instance_valid(panel):
			panel.visible = false
	if is_instance_valid(source_card_browser):
		source_card_browser.visible = false

func _open_source_cards() -> void:
	ds_battle.set_suspended(true)
	_clear_roster_previews()
	_hide_preparation_panels()
	phase = "source_cards"
	overlay.visible = false
	phase_text.visible = false
	if not is_instance_valid(source_card_browser):
		var browser_script: Script = load("res://scripts/source_card_browser.gd")
		source_card_browser = browser_script.new()
		hud.add_child(source_card_browser)
		source_card_browser.closed.connect(_show_menu)
	source_card_browser.show_browser()

func _focus_first(parent: Node) -> bool:
	for child: Node in parent.get_children():
		if child is BaseButton and child.is_visible_in_tree() and not child.disabled and child.focus_mode!=Control.FOCUS_NONE:
			child.grab_focus(); return true
		if _focus_first(child): return true
	return false

func _open_preparation(next_phase: String, panel: Panel) -> void:
	ds_battle.set_suspended(true)
	_clear_roster_previews()
	_hide_preparation_panels()
	phase = next_phase
	overlay.visible = false
	panel.visible = true
	call_deferred("_focus_first",panel)
	target_marker.visible = false
	trajectory.visible = false
	phase_text.visible = false
	instruction.text = "ESC — сохранить и вернуться в меню."
	_update_cards()

func _close_preparation() -> void:
	_save_profile()
	_show_menu()

func _build_gate_panel() -> void:
	gate_panel = _panel(hud, Vector2(250, 148), Vector2(940, 490), Color(0.035, 0.045, 0.09, 0.98))
	gate_panel.visible = false
	_label(gate_panel, "КАРТЫ ВОРОТ", Vector2(24, 19), Vector2(892, 40), 27, ORANGE, true)
	_label(gate_panel, "По одной золотой, серебряной и медной карте. Бонусы открываются при начале боя.", Vector2(24, 66), Vector2(892, 29), 16, MUTED)
	for slot in range(3):
		var card = _panel(gate_panel, Vector2(24 + slot * 304, 110), Vector2(284, 276))
		_label(card, ["ЗОЛОТЫЕ", "СЕРЕБРЯНЫЕ", "МЕДНЫЕ"][slot], Vector2(12, 10), Vector2(260, 22), 12, CYAN, true)
		var selector = _option(card, Vector2(12, 42), 260)
		selector.add_theme_font_size_override("font_size", 15)
		for index in _profile_indices("gate", ["gold", "silver", "copper"][slot]):
			selector.add_item(str(_profile_cards("gate")[index].title))
			selector.set_item_metadata(selector.item_count - 1, index)
		selector.item_selected.connect(_gate_selection_from_ui.bind(slot))
		gate_selectors.append(selector)
		var artwork: TextureRect = _card_image(card, Vector2(12, 101), Vector2(84, 112))
		artwork.mouse_filter = Control.MOUSE_FILTER_STOP
		artwork.tooltip_text = "Нажми, чтобы рассмотреть карту."
		artwork.gui_input.connect(_card_art_input.bind("gates", slot))
		gate_art.append(artwork)
		var effect: Label = _label(card, "", Vector2(108, 101), Vector2(164, 112), 13, WHITE)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gate_effect_labels.append(effect)
		var description = _label(card, "", Vector2(12, 223), Vector2(260, 49), 12, WHITE)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gate_description_labels.append(description)
	var done = _button(gate_panel, "СОХРАНИТЬ И ВЕРНУТЬСЯ", Vector2(24, 410), Vector2(892, 53), CYAN)
	done.pressed.connect(_close_preparation)

func _open_gates() -> void:
	_open_preparation("gates", gate_panel)
	instruction.text = "Выбери по одной карте каждого цвета. ESC — сохранить и вернуться."
	_refresh_gate_ui()

func _gate_selection_from_ui(option_index: int, slot: int) -> void:
	_select_gate_slot(slot, int(gate_selectors[slot].get_item_metadata(option_index)))

func _select_gate_slot(slot: int, catalog_index: int) -> void:
	if slot < 0 or slot >= 3 or catalog_index < 0 or catalog_index >= _profile_cards("gate").size():
		return
	var colors: Array = ["gold", "silver", "copper"]
	if not _profile_indices("gate", colors[slot]).has(catalog_index):
		return
	selected_gate_deck = _normalize_deck("gate", selected_gate_deck)
	selected_gate_deck[slot] = catalog_index
	_refresh_gate_ui()
	_save_profile()

func _gate_description(card: Dictionary) -> String:
	var boosts: Dictionary = card.boosts
	return "%s\n\nPyrus +%d   Aquos +%d\nSubterra +%d   Haos +%d\nDarkus +%d   Ventus +%d" % [str(card.description), int(boosts.Pyrus), int(boosts.Aquos), int(boosts.Subterra), int(boosts.Haos), int(boosts.Darkus), int(boosts.Ventus)]

func _refresh_gate_ui() -> void:
	selected_gate_deck = _normalize_deck("gate", selected_gate_deck)
	for slot in range(3):
		var index: int = int(selected_gate_deck[slot])
		for option_index in range(gate_selectors[slot].item_count):
			if int(gate_selectors[slot].get_item_metadata(option_index)) == index:
				gate_selectors[slot].select(option_index)
		var card: Dictionary = _profile_cards("gate")[index]
		gate_effect_labels[slot].text = str(card.description)
		gate_description_labels[slot].text = "Pyrus +%d   Aquos +%d\nSubterra +%d   Haos +%d\nDarkus +%d   Ventus +%d" % [int(card.boosts.Pyrus), int(card.boosts.Aquos), int(card.boosts.Subterra), int(card.boosts.Haos), int(card.boosts.Darkus), int(card.boosts.Ventus)]
		gate_art[slot].texture = _profile_card_texture(card, "gate", index)

func _card_image(parent: Node, position: Vector2, dimensions: Vector2) -> TextureRect:
	var artwork: TextureRect = TextureRect.new()
	artwork.position = position
	artwork.size = dimensions
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(artwork)
	return artwork

func _build_card_view() -> void:
	card_view_panel = _panel(hud, Vector2(340, 148), Vector2(760, 584))
	card_view_panel.visible = false
	card_view_title = _label(card_view_panel, "", Vector2(20, 18), Vector2(720, 44), 28, ORANGE, true)
	card_view_art = _card_image(card_view_panel, Vector2(20, 80), Vector2(336, 448))
	card_view_description = _label(card_view_panel, "", Vector2(382, 90), Vector2(350, 360), 20, WHITE)
	card_view_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back: Button = _button(card_view_panel, "ВЕРНУТЬСЯ К КОЛОДЕ", Vector2(382, 482), Vector2(350, 60), CYAN)
	back.add_theme_font_size_override("font_size", 17)
	back.pressed.connect(_close_card_view)

func _card_art_input(event: InputEvent, kind: String, slot: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_open_card_view(kind, slot)

func _open_card_view(kind: String, slot: int) -> void:
	if not kind in ["gates", "abilities"] or slot < 0 or slot >= 3:
		return
	card_view_kind = kind
	var index: int = int(selected_gate_deck[slot]) if kind == "gates" else int(selected_deck[slot])
	var card: Dictionary = _profile_cards("gate" if kind == "gates" else "ability")[index]
	_open_preparation("card_view", card_view_panel)
	card_view_title.text = str(card.title)
	card_view_art.texture = _profile_card_texture(card, "gate" if kind == "gates" else "ability", index)
	card_view_description.text = _gate_description(card) if kind == "gates" else str(card.description)
	instruction.text = "Просмотр карты · ESC — вернуться к колоде."

func _close_card_view() -> void:
	if card_view_kind == "gates":
		_open_gates()
	else:
		_open_deck()

func _build_settings_panel() -> void:
	settings_panel = preload("res://scripts/settings_screen.gd").new()
	hud.add_child(settings_panel)
	settings_panel.build(self)

func _open_settings() -> void:
	_open_preparation("settings", settings_panel)
	_refresh_settings_ui()
	rules_selector.grab_focus()

func _select_arena(index: int) -> void:
	if index < 0 or index >= ArenaCatalog.ENTRIES.size():
		return
	selected_arena = str(ArenaCatalog.ENTRIES[index].id)
	arena.set_theme(selected_arena)
	ds_battle.configure(str(arena.theme_id), bool(preferences.reduced_motion))
	_refresh_settings_ui()
	_save_profile()

func _select_difficulty(index: int) -> void:
	if index < 0 or index > 2:
		return
	preferences.difficulty = ["easy", "normal", "hard"][index]
	_apply_settings()
	_save_profile()

func _select_field_layout(index: int) -> void:
	if rules_profile!="ds" or index<0 or index>=DSFieldObjects.layouts(selected_arena).size():
		return
	selected_field_layout = index
	arena.set_field_layout(index)
	_refresh_settings_ui()
	_save_profile()

func _set_volume(value: float) -> void:
	preferences.volume = value
	_apply_settings()
	volume_text.text = "ГРОМКОСТЬ: %d%%" % roundi(float(preferences.volume) * 100.0)
	_save_profile()

func _set_channel_volume(value: float, key: String) -> void:
	preferences[key] = value
	_apply_settings()
	_save_profile()

func _set_reduced_motion(enabled: bool) -> void:
	preferences.reduced_motion = enabled
	_apply_settings()
	_save_profile()

func _refresh_settings_ui() -> void:
	preferences = GameSettings.normalize(preferences)
	rules_selector.set_item_disabled(0, not _ds_profile_available())
	rules_selector.select(0 if rules_profile == "ds" else 1)
	rules_description.text = "Колоды DS и Wii сохраняются отдельно. Мини-игры пока адаптированы для ПК."
	selected_arena = ArenaCatalog.normalize_id(selected_arena)
	for index in range(ArenaCatalog.ENTRIES.size()):
		if str(ArenaCatalog.ENTRIES[index].id) == selected_arena:
			arena_selector.select(index)
	arena_description.text = "%s Турнир меняет арену на каждом этапе." % str(ArenaCatalog.get_entry(selected_arena).description)
	field_layout_selector.clear()
	var layouts: Array = DSFieldObjects.layouts(selected_arena) if rules_profile=="ds" else []
	field_layout_selector.disabled = layouts.is_empty()
	if layouts.is_empty():
		field_layout_selector.add_item("Выбери правила DS и поле DS")
	else:
		for index: int in layouts.size():
			field_layout_selector.add_item("Расстановка %d · исходные предметы и механизмы" % (index+1))
		selected_field_layout = clampi(selected_field_layout,0,layouts.size()-1)
		field_layout_selector.select(selected_field_layout)
	difficulty_selector.select(["easy", "normal", "hard"].find(str(preferences.difficulty)))
	volume_slider.set_value_no_signal(float(preferences.volume))
	volume_text.text = "ГРОМКОСТЬ: %d%%" % roundi(float(preferences.volume) * 100.0)
	motion_toggle.set_pressed_no_signal(bool(preferences.reduced_motion))
	ds_gate_toggle.set_pressed_no_signal(bool(preferences.ds_auto_gates))
	ds_minigame_selector.disabled=rules_profile!="ds"
	ds_minigame_selector.select(0 if str(preferences.ds_minigame)=="cycle" else DSMiniCatalog.MODES.find(str(preferences.ds_minigame))+1)
	ds_gate_toggle.disabled = rules_profile!="ds"
	for key: String in channel_sliders:
		channel_sliders[key].set_value_no_signal(float(preferences[key]))
	settings_panel.refresh_advanced()

func _apply_settings() -> void:
	preferences = GameSettings.normalize(preferences)
	var graphics: Array=[preferences.frame_cap,preferences.render_scale,preferences.msaa,preferences.vsync,preferences.screen_mode]
	if graphics!=applied_graphics:
		GameSettings.apply_graphics(get_viewport(),preferences)
		if is_instance_valid(ds_battle):
			ds_battle.viewport.scaling_3d_scale=float(preferences.render_scale)
			ds_battle.viewport.msaa_3d=get_viewport().msaa_3d
		applied_graphics=graphics
	if is_instance_valid(player_avatar): player_avatar.show_avatar(str(preferences.avatar))
	if is_instance_valid(audio): audio.set_speaker(str(preferences.avatar))
	if is_instance_valid(audio): audio.configure(preferences,muted)
	AudioServer.set_bus_mute(0, muted or float(preferences.volume) <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(preferences.volume), 0.0001)))
	if is_instance_valid(mute_button):
		mute_button.text = "ТИХО" if muted or float(preferences.volume) <= 0.0 else "ЗВУК"
	if is_instance_valid(arena):
		arena.set_reduced_motion(bool(preferences.reduced_motion))
	if is_instance_valid(ds_battle):
		ds_battle.configure(str(arena.theme_id), bool(preferences.reduced_motion))

func _build_help_panel() -> void:
	help_panel = _panel(hud, Vector2(300, 145), Vector2(840, 612), Color(0.035, 0.045, 0.09, 0.98))
	help_panel.visible = false
	help_title = _label(help_panel, "КАК ИГРАТЬ", Vector2(24, 19), Vector2(792, 40), 27, ORANGE, true)
	help_body = _label(help_panel, "1. В колоде: золотые, серебряные, медные ворота и красная, зелёная, синяя способность. Оба игрока ставят начальные ворота в центре.\n\n2. В свой ход можно добавить одну карту рядом по стороне. ПРОБЕЛ пропускает постановку. Выбери бакугана 1–3 и цель мышью. T — высокий или прямой бросок. Высокий летит дугой; прямой летит ниже и быстрее катится. Удерживай ПРОБЕЛ для силы, отпусти в зелёной зоне. P отдельно включает Sphere Attack.\n\n3. WASD — катание, SHIFT — тормоз. Собранный G остаётся только при попадании. Два своих: забери карту или переведи последнего на соседние ворота. Все трое на поле: выбери STAY до следующего своего хода.\n\n4. Соперники открывают ворота. Учитываются стихия и эффект карты. Сыграй подходящие способности, затем начни бой. Золото — стрельба, серебро — точность, медь — скорость. Клавиши показаны в бою.\n\n5. Первая сторона с тремя захваченными картами побеждает. Использованные бакуганы возвращаются в доступный резерв после исчерпания остальных. ESC — пауза.", Vector2(24, 77), Vector2(792, 449), 16, WHITE)
	help_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_scroll = ScrollContainer.new()
	help_scroll.position = Vector2(24,77)
	help_scroll.size = Vector2(792,449)
	help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	help_panel.add_child(help_scroll)
	help_body.reparent(help_scroll)
	help_body.position = Vector2.ZERO
	help_body.custom_minimum_size = Vector2(766,0)
	help_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done: Button = _button(help_panel, "ПОНЯТНО", Vector2(24, 536), Vector2(792, 53), CYAN)
	done.pressed.connect(_close_preparation)

func _open_help() -> void:
	_open_preparation("help", help_panel)
	help_title.text = "КАК ИГРАТЬ · %s" % rules_profile.to_upper()
	help_body.text = Controls.hints(_rules_help_text(),preferences)
	help_scroll.scroll_vertical = 0

func _rules_help_text() -> String:
	var profile_tip: String = "DS: исходные карты и их G-бонусы. Один бросок за ход; незавершённый бой блокирует переход хода. Свои начальные ворота ставятся ближе к сопернику." if rules_profile == "ds" else "Wii: прежние правила и отдельная колода. Переключение DS/Wii — в настройках."
	var controls: String = "1–3 — бакуган; щелчок — цель; зажми сферу и быстро проведи вверх для броска. Q/E — камера; колесо — масштаб; мини-карта — цель. T — траектория; WASD — коррекция; Shift — тормоз; Пробел после броска — прыжок." if rules_profile == "ds" else "1–3 — бакуган; мышь — цель; удерживай ПРОБЕЛ для силы, отпусти для броска. T — высокий/прямой; P — Sphere Attack; WASD — движение; SHIFT — тормоз."
	if rules_profile=="ds":
		controls += " Жёлтый G даёт бонус на этот бросок; серебряный S заполняет шкалу. При 100 S клавиша P включает усиленный бросок. Стрелки на полу ускоряют, зелёные площадки подбрасывают. Расстановка выбирается в настройках."
		controls += " Зелёный EXP приносит очки развития после боя в кампании. Препятствия разрушаются от быстрого удара; медленный удар отскакивает. Водяная струя подбрасывает, поток Ventus направляет сферу. Разряд Haos отнимает 25 G у других стихий. Ритм опасностей и урон настроены для ПК."
		controls += " Повторные прыжки становятся ниже. На поле Pyrus лавовые ловушки отнимают 30 G за касание у других стихий. Pyrus защищён; прыжок и высокий бросок позволяют пройти над лавой. Оранжевые области на мини-карте — лава."
		return "DS · Поле 8×6\n\n1. В начале автоматически появляются две карты ворот. Ручную постановку можно включить в настройках. Когда поле опустеет, ставится следующая пара из оставшихся карт. Новую карту во время хода можно добавить, только если твоих ворот на поле нет.\n\n2. %s\n\n3. Промахнувшийся бакуган возвращается на следующий ход. Два своих на одной карте — захват или перенос последнего на соседние ворота.\n\n4. Бой: выход участников, раскрытие ворот, выбор цепи до трёх карт, отсчёт. 1–3 добавляют карты в порядке нажатия; в бою активируется следующая выбранная карта. Backspace пропускает её без расхода. Способности проверяют стихии, состав команды, ворота и запреты соперника. Показ карты останавливает ввод и таймер.\n\n5. Scratch — три знак; Spin — вращай; Timing — нажми в центре; Pop — нажми появившийся знак; Trace — веди; Bound — удержи движущийся знак до вспышки. Вид выбирается в настройках; все шесть доступны в практике. G складывается из силы бакугана, ворот, сбора и способностей; мини-игра меняет шкалу преимущества, не показанное G. Захвати три карты. ESC — пауза.\n\nЧисленные тайминги и формулы мини-игр настроены для ПК. Исходный выбор вида по воротам пока не восстановлен. Ловушки доступны только в аниме-дуэли." % controls
	return "%s\n\n1. Колода: три бакугана; золотые, серебряные и медные ворота; красная, зелёная и синяя способность. Оба игрока ставят начальные карты в центре. Пустое поле — повторная постановка.\n\n2. Добавь одну карту рядом по стороне или нажми ПРОБЕЛ для броска. %s\n\n3. Два своих: забери карту без боя или переведи последнего на соседние ворота. Нет перехода — захват сразу. Все трое на поле: STAY до следующего своего хода. После исчерпания резерва бакуганы возвращаются.\n\n4. Соперники на карте — бой. Учитываются G, ворота, собранный бонус и способности. Условия недоступных карт показаны при наведении. Мини-игры пока адаптированы для ПК.\n\n5. Захвати три карты для победы. ESC — пауза." % [profile_tip, controls]

func _build_training_panel() -> void:
	training_panel = _panel(hud, Vector2(365, 90), Vector2(710, 690), Color(0.035, 0.045, 0.09, 0.98))
	training_panel.visible = false
	_label(training_panel, "ТРЕНИРОВКА", Vector2(24, 19), Vector2(662, 40), 27, CYAN, true)
	var tip = _label(training_panel, "Броски в полном матче или отдельная мини-игра. Результаты не записываются.", Vector2(24, 78), Vector2(662, 65), 17, MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var guided = _button(training_panel, "ПЕРВЫЙ БОЙ · ПОШАГОВОЕ ОБУЧЕНИЕ", Vector2(24, 149),Vector2(662,54),CYAN)
	guided.pressed.connect(_start_guided_lesson)
	var full_match = _button(training_panel, "ТРЕНИРОВОЧНЫЙ МАТЧ", Vector2(24, 217), Vector2(662, 54), ORANGE)
	full_match.pressed.connect(_start_training)
	practice_selector = _option(training_panel, Vector2(24, 290), 389)
	for title: String in ["Wii · Точность", "Wii · Меткость", "Wii · Скорость"]: practice_selector.add_item(title)
	var practice = _button(training_panel, "МИНИ-ИГРА Wii", Vector2(431, 290), Vector2(255, 46), CYAN)
	practice.pressed.connect(func():
		_set_rules_profile("wii")
		_start_practice(["timing", "shooting", "shaking"][practice_selector.selected]))
	for index: int in DSMiniCatalog.MODES.size():
		var mode: String=DSMiniCatalog.MODES[index]
		var ds_practice: Button=_button(training_panel,str(DSMiniCatalog.NAMES[mode]),Vector2(24+(index%2)*342,355+floori(float(index)/2)*58),Vector2(320,48),ORANGE)
		ds_practice.add_theme_font_size_override("font_size",13)
		ds_practice.pressed.connect(func():
			_set_rules_profile("ds")
			_start_practice(mode))
	var done = _button(training_panel, "НАЗАД", Vector2(24, 598), Vector2(662, 51), CYAN)
	done.pressed.connect(_close_preparation)

func _open_training() -> void:
	_open_preparation("training_setup", training_panel)

func _start_guided_lesson() -> void:
	_set_rules_profile("ds")
	selected_arena="ds_toy"
	match_mode="training"
	tutorial.begin()
	start_match()

func _start_training() -> void:
	tutorial.cancel()
	match_mode = "training"
	start_match()

func _start_practice(kind: String = "timing") -> void:
	tutorial.cancel()
	practice_kind = kind if DSMiniCatalog.MODES.has(kind) else "scratch" if rules_profile=="ds" else kind if kind in ["timing","shooting","shaking"] else "timing"
	match_mode = "practice"
	start_match()
	var gate_index: int = 0 if rules_profile=="ds" else int({"timing":1,"shooting":0,"shaking":2}.get(practice_kind,1))
	var slot: int = 19 if rules_profile=="ds" else 5
	# Practice has one gate, but uses the same engine sequence as a real match.
	# Mark the participant with no opening gate through the rules API.
	if rules_profile == "ds":
		rules.hands[1].clear()
		rules.begin_opening()
	rules.place_gate(0, gate_index, slot, true)
	rules.land(0, 0, slot)
	if rules_profile == "ds":
		rules.finish_turn()
	rules.land(1, 0, slot)
	_begin_battle(slot)

func _show_practice_result(result: Dictionary) -> void:
	phase = "finished"
	last_recorded_match_id = match_id
	# Preserve the resolved participants while the DS result presentation runs.
	overlay.visible = false
	_set_overlay_menu_layout(false)
	overlay_title.text = "ТРЕНИРОВКА ЗАВЕРШЕНА"
	var powers: Array = result.get("display_powers", [int(result.get("player_g", 0)), int(result.get("enemy_g", 0))])
	var score_text: String = "Твой результат %s: %d очков." % [battle_type.capitalize(),battle_points] if rules_profile=="ds" else "Твой результат мини-игры: %d G." % battle_points
	overlay_body.text = "%s\n\n%s\nG-Power: %d G против %d G.\n\n%s\n\nРезультаты профиля и этап турнира сохранены." % [battle_title.text, score_text, powers[0], powers[1], "Твоя карта!" if int(result.get("owner", 1)) == 0 else "Попробуй ещё раз или другую способность."]
	overlay_start.text = "ПОВТОРИТЬ"
	instruction.text = "Тренировка · без записи побед и поражений."
	var generation: int = match_id
	await get_tree().create_timer(2.85 if rules_profile=="ds" else 1.65, false).timeout
	if generation == match_id and phase == "finished":
		ds_battle.set_suspended(true)
		overlay.visible = true

func _build_model_panel() -> void:
	model_panel = _panel(hud, Vector2(274, 148), Vector2(892, 584), Color.TRANSPARENT)
	model_panel.visible = false
	var header = _panel(model_panel, Vector2.ZERO, Vector2(892, 181))
	model_name = _label(header, "", Vector2(20, 8), Vector2(852, 35), 25, ORANGE, true)
	model_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for index: int in range(4):
		var category_button: Button = _button(header, "", Vector2(20 + index * 216, 47), Vector2(204, 31), CYAN)
		category_button.add_theme_font_size_override("font_size", 13)
		category_button.pressed.connect(_set_model_category.bind(["all", "bakugan", "trap", "support"][index]))
		model_category_buttons.append(category_button)
	model_species_selector = _option(header, Vector2(20, 85), 524)
	_refresh_model_selector()
	model_species_selector.item_selected.connect(func(index: int):
		model_catalog_index = index
		_render_model())
	model_attribute_selector = _option(header, Vector2(560, 85), 312)
	for attribute: String in Roster.ATTRIBUTES:
		model_attribute_selector.add_item(attribute)
	model_attribute_selector.item_selected.connect(func(index: int):
		model_attribute = str(Roster.ATTRIBUTES[index])
		_render_model())
	for index in range(3):
		var form_button: Button = _button(header, ["СФЕРА", "РАСКРЫТАЯ", "БОЕВАЯ"][index], Vector2(20 + index * 288, 137), Vector2(276, 35), CYAN)
		form_button.add_theme_font_size_override("font_size", 14)
		form_button.pressed.connect(_set_model_form.bind(["ball", "toy", "battle"][index]))
		model_form_buttons.append(form_button)
	var viewport_container := SubViewportContainer.new()
	viewport_container.position = Vector2(20, 187)
	viewport_container.size = Vector2(852, 274)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	model_panel.add_child(viewport_container)
	var model_viewport := SubViewport.new()
	model_viewport.size = Vector2i(852, 274)
	model_viewport.own_world_3d = true
	model_viewport.msaa_3d = Viewport.MSAA_4X
	model_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport_container.add_child(model_viewport)
	model_world = Node3D.new()
	model_viewport.add_child(model_world)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b1223")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e1e7ef")
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	model_world.add_child(world_environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-45, -35, 0)
	key_light.light_energy = 1.0
	key_light.shadow_enabled = true
	model_world.add_child(key_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-30, 130, 0)
	fill_light.light_energy = 0.5
	model_world.add_child(fill_light)
	model_camera = Camera3D.new()
	model_world.add_child(model_camera)
	model_camera.fov = 32.0
	model_camera.look_at_from_position(Vector3(4.8, 3.8, 7.2), Vector3(0, 1.6, 0))
	model_camera.current = true
	var info_panel = _panel(model_panel, Vector2(0, 469), Vector2(892, 42))
	model_info = _label(info_panel, "", Vector2(16, 3), Vector2(860, 36), 12, MUTED)
	model_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer = _panel(model_panel, Vector2(0, 519), Vector2(892, 65))
	var previous = _button(footer, "←", Vector2(16, 8), Vector2(70, 48), ORANGE)
	previous.pressed.connect(_cycle_model.bind(-1))
	var done = _button(footer, "ВЕРНУТЬСЯ К КОМАНДЕ", Vector2(102, 8), Vector2(688, 48), CYAN)
	done.pressed.connect(_open_roster)
	var next = _button(footer, "→", Vector2(806, 8), Vector2(70, 48), ORANGE)
	next.pressed.connect(_cycle_model.bind(1))

func _open_model(slot: int = 1) -> void:
	if slot < 0 or slot >= 3:
		return
	model_slot = slot
	model_category = "all"
	_refresh_model_selector()
	model_catalog_index = int(selected_roster[slot])
	model_attribute = str(selected_attributes[slot])
	_open_preparation("model", model_panel)
	_render_model()

func _cycle_model(direction: int) -> void:
	model_catalog_index = posmod(model_catalog_index + direction, _model_entries().size())
	_render_model()

func _set_model_category(category: String) -> void:
	if category not in ["all", "bakugan", "trap", "support"]:
		return
	model_category = category
	model_catalog_index = 0
	_refresh_model_selector()
	_render_model()

func _refresh_model_selector() -> void:
	model_species_selector.clear()
	for entry: Dictionary in _model_entries():
		var classification: String = str(entry.get("classification", "bakugan"))
		var suffix: String = " · ловушка" if classification == "trap" else (" · парная поддержка" if classification == "support" else "")
		model_species_selector.add_item(str(entry.name) + suffix)
	for index: int in range(model_category_buttons.size()):
		var category: String = ["all", "bakugan", "trap", "support"][index]
		model_category_buttons[index].text = "%s · %d" % [["ВСЕ", "БАКУГАНЫ", "ЛОВУШКИ", "ПАРНАЯ"][index], _model_entries(category).size()]
		model_category_buttons[index].add_theme_stylebox_override("normal", _style(Color("25304b") if category == model_category else Color("11192e"), ORANGE if category == model_category else CYAN))

func _model_entries(category: String = "") -> Array[Dictionary]:
	if category.is_empty():
		category = model_category
	var result: Array[Dictionary] = []
	if category in ["all", "bakugan"]:
		var existing: Dictionary = {}
		for creature: Dictionary in Roster.CREATURES:
			result.append(creature)
			existing[str(creature.name).to_lower().replace(" ", "")] = true
		for entry: Dictionary in AssetCatalog.species():
			if not existing.has(str(entry.name).to_lower().replace(" ", "")):
				result.append(entry)
	var classifications: Dictionary = {}
	for profile: Dictionary in TrapCatalog.supports():
		classifications[str(profile.name)] = str(profile.get("category", "support"))
	for support_entry: Dictionary in AssetCatalog.support():
		var entry: Dictionary = support_entry.duplicate(true)
		entry["classification"] = str(classifications.get(str(entry.name), "support"))
		if category == "all" or entry.classification == category:
			result.append(entry)
	return result

func _set_model_form(form: String) -> void:
	var entry: Dictionary = _model_entries()[model_catalog_index]
	if AssetCatalog.available_forms(str(entry.name)).has(form):
		model_form = form
		_render_model()

func _render_model() -> void:
	_clear_roster_previews()
	var entries: Array[Dictionary] = _model_entries()
	model_catalog_index = clampi(model_catalog_index, 0, entries.size() - 1)
	var entry: Dictionary = entries[model_catalog_index]
	var available: Array[String] = AssetCatalog.available_forms(str(entry.name))
	if not available.has(model_form):
		model_form = "toy" if available.has("toy") else (available[0] if not available.is_empty() else "toy")
	model_species_selector.select(model_catalog_index)
	model_attribute_selector.select(Roster.ATTRIBUTES.find(model_attribute))
	for index in range(3):
		var form: String = ["ball", "toy", "battle"][index]
		model_form_buttons[index].disabled = not available.has(form)
		model_form_buttons[index].tooltip_text = "Боевой формы пока нет в коллекции." if form == "battle" and not available.has(form) else ""
		model_form_buttons[index].add_theme_stylebox_override("normal", _style(Color("25304b") if form == model_form else Color("11192e"), ORANGE if form == model_form else CYAN))
	var classification: String = str(entry.get("classification", "bakugan"))
	model_name.text = "%s%s  ·  %s  ·  %d / %d" % [str(entry.name), " · ЛОВУШКА" if classification == "trap" else (" · ПАРНАЯ ПОДДЕРЖКА" if classification == "support" else ""), model_attribute, model_catalog_index + 1, entries.size()]
	var stand = Node3D.new()
	model_world.add_child(stand)
	var creature: Node3D = arena.make_ball(model_attribute, 0, str(entry.name)) if model_form == "ball" else arena.make_creature(str(entry.name), model_attribute, model_form)
	creature.reparent(stand, false)
	var player: AnimationPlayer = ModelLibrary._form_player(creature)
	var clip: String = str(player.assigned_animation) if player != null else ""
	var position: float = player.current_animation_position if not clip.is_empty() else 0.0
	var playing: bool = player.is_playing() if player != null else false
	if not clip.is_empty():
		player.seek(player.get_animation(clip).length if model_form == "toy" else 0.0, true)
	var bounds: AABB = ModelLibrary.visual_bounds(creature)
	creature.position = -bounds.get_center()
	if not clip.is_empty():
		# Measuring the final pose must not leave an end-of-clip update queued.
		player.stop(true)
		player.play(clip)
		player.seek(position, true)
		if not playing:
			player.pause()
	stand.scale = Vector3.ONE * (4.2 if model_form == "ball" else 1.7)
	stand.rotation.y = preview_angle
	model_preview_bounds = AABB(-bounds.size * 0.5, bounds.size)
	_frame_collection_model(stand)
	roster_previews.append(stand)
	var appearance: String = ""
	if not bool(creature.get_meta("exact_attribute", true)):
		appearance = "Внешний вид: %s; стихия для правил: %s. " % [str(creature.get_meta("texture_attribute", "родная расцветка")), model_attribute]
	var texture_attributes: Array[String] = AssetCatalog.available_attributes(str(entry.name), model_form)
	instruction.text = appearance + "Коллекция: %d · расцветки: %s · ← → — поворот · ESC — назад." % [entries.size(), ", ".join(texture_attributes)]
	if str(creature.get_meta("source", {}).get("workshop_id", "")) == "3696633172":
		instruction.text += " Monster batch · статичная геометрия."
	model_info.text = instruction.text
	instruction.hide()

func _frame_collection_model(stand: Node3D) -> void:
	var direction := Vector3(4.8, 2.2, 7.2).normalized()
	model_camera.look_at_from_position(direction, Vector3.ZERO)
	var basis: Basis = model_camera.basis
	var viewport_size: Vector2i = model_camera.get_viewport().size
	var vertical: float = tan(deg_to_rad(model_camera.fov * 0.5)) * 0.82
	var horizontal: float = vertical * float(viewport_size.x) / float(viewport_size.y)
	var distance: float = 0.5
	for corner: int in 8:
		var point: Vector3 = stand.transform * model_preview_bounds.get_endpoint(corner)
		distance = maxf(distance, point.dot(direction) + maxf(absf(point.dot(basis.x)) / horizontal, absf(point.dot(basis.y)) / vertical))
	model_camera.position = direction * distance

func _start_anime_duel() -> void:
	_request_slot_start("anime")

func _launch_anime_slot() -> void:
	Checkpoint.active_slot=anime_slot
	audio.music.stop()
	audio.stop_transients()
	ds_battle.reset()
	_save_profile()
	get_tree().paused = false
	var scene: PackedScene = load("res://anime_duel.tscn")
	var duel: Node3D = scene.instantiate()
	var duel_preferences: Dictionary = preferences.duplicate()
	duel_preferences["volume"] = 0.0 if muted else float(preferences.volume)
	duel.save_slot=anime_slot
	duel.configure(Roster.make_team(selected_roster, selected_attributes, 0, true), selected_arena, duel_preferences, throw_style)
	get_tree().root.add_child(duel)
	get_tree().current_scene = duel
	queue_free()

func _start_quick_match() -> void:
	_request_slot_start("quick")

func _open_campaign() -> void:
	_open_preparation("campaign",campaign_panel)
	campaign_panel.refresh()

func _campaign_has_checkpoint() -> bool:
	var data: Dictionary=Slots.match_data(campaign_slot)
	return not data.is_empty() and str(data.main.get("match_mode",""))=="campaign" and int(data.main.campaign_chapter)==campaign.chapter and not settled_matches.has(str(data.main.match_token))

func _launch_campaign() -> void:
	if _campaign_has_checkpoint():
		_resume_slot(campaign_slot)
		return
	_set_rules_profile("ds")
	match_mode="campaign"
	campaign_chapter=campaign.chapter
	start_match()

func _start_tournament() -> void:
	_request_slot_start("tournament")

func _continue_tournament() -> void:
	if not tournament.active or tournament.completed:
		_show_menu()
		return
	var data: Dictionary=Slots.match_data(free_slot)
	if not data.is_empty() and str(data.main.match_mode)=="tournament":
		_resume_slot(free_slot); return
	_request_slot_start("tournament_continue")

func _return_to_menu() -> void:
	# Preserve the live field before invalidating timers. Menu must not start a match.
	_save_checkpoint()
	if checkpoint_error!=OK:
		if not paused: _toggle_pause()
		var dialog: ConfirmationDialog=get_node_or_null("MenuSaveFailureDialog") as ConfirmationDialog
		if dialog==null:
			dialog=ConfirmationDialog.new(); dialog.name="MenuSaveFailureDialog"
			dialog.process_mode=Node.PROCESS_MODE_ALWAYS
			dialog.title="Бой не записан"
			dialog.dialog_text="Не удалось сохранить текущий бой. Можно вернуться к нему или перейти в меню без последних изменений."
			dialog.ok_button_text="В меню без сохранения"; dialog.cancel_button_text="Вернуться к бою"
			dialog.confirmed.connect(_return_to_menu_unchecked)
			add_child(dialog)
		dialog.popup_centered(Vector2i(590,190)); return
	_return_to_menu_unchecked()

func _return_to_menu_unchecked() -> void:
	match_id += 1
	paused=false
	get_tree().paused=false
	audio.set_suspended(false)
	if is_instance_valid(flight_ball): flight_ball.queue_free()
	flight_ball=null
	for node: Variant in unit_nodes.values():
		if is_instance_valid(node): node.queue_free()
	unit_nodes.clear()
	for slot: Variant in arena.gates.keys(): arena.remove_gate(int(slot))
	_clear_dragons()
	_clear_pickups()
	tutorial.cancel()
	_show_menu()

func _show_menu() -> void:
	if is_instance_valid(overlay_quick): overlay_quick.call_deferred("grab_focus")
	_cancel_throw_input()
	phase = "menu"
	if is_instance_valid(audio):
		audio.stop_transients()
		audio.set_context("menu")
	ds_battle.reset()
	_clear_roster_previews()
	_hide_preparation_panels()
	arena.set_theme(selected_arena)
	arena.clear_highlights()
	phase_text.visible = true
	_set_overlay_menu_layout(true)
	target_marker.visible = false
	trajectory.visible = false
	overlay.visible = true
	overlay_title.text = "АРЕНА БАКУГАНОВ"
	var progress: String = "Турнир: три раунда с растущей сложностью."
	if tournament.active:
		progress = "Сохранённый турнир: %s." % str(tournament.get_stage().title)
	elif tournament.completed:
		progress = "Кубок завоёван! Можно начать новый турнир."
	overlay_body.text = "Аниме-дуэль: 3 бакугана, 6 ворот и 10 способностей.\nРазыгрывай карты и отвечай на действия соперника.\n\n99 бакуганов · ловушки отдельно · боевые формы DoC.\n%s" % progress
	overlay_start.text = "АНИМЕ-ДУЭЛЬ"
	overlay_quick.text = "МАТЧ %s" % rules_profile.to_upper()
	overlay_gates.text = "ВОРОТА · %s" % rules_profile.to_upper()
	overlay_deck.text = "СПОСОБНОСТИ · %s" % rules_profile.to_upper()
	overlay_tournament.text = "ПРОДОЛЖИТЬ" if tournament.active else "ТУРНИР"
	overlay_campaign.text = "КАМПАНИЯ · %d / 7" % (campaign.chapter+1)
	overlay_resume.text="СОХРАНЕНИЯ / ПРОДОЛЖИТЬ"
	overlay_resume.add_theme_font_size_override("font_size",15)
	phase_text.text = "ГОТОВ К БОЮ?"
	instruction.text = "Правила: %s   ·   Победы: %d   ·   Поражения: %d" % [rules_profile.to_upper(), wins, losses]
	rules.teams[0]=Roster.make_team(selected_roster,selected_attributes,0,true)
	if rules_profile=="ds": rules.teams[0]=DSProfiles.apply_team(rules.teams[0])
	_refresh_hud()
	_update_cards()

func _overlay_primary() -> void:
	if paused:
		_toggle_pause()
	elif phase == "menu":
		_start_anime_duel()
	elif phase == "finished" and match_mode == "tournament":
		if tournament.completed:
			_return_to_menu()
		else:
			_continue_tournament()
	elif phase == "finished" and match_mode == "practice":
		_start_practice(practice_kind)
	elif phase == "finished" and match_mode == "campaign":
		_open_campaign()
	else:
		start_match()

func start_match() -> void:
	match_id += 1
	match_token=str(Time.get_unix_time_from_system())+"_"+str(rng.randi())
	pending_timer=null; pending_action=""; ai_choice.clear()
	if not restoring_match and match_mode not in ["training","practice"]:
		Checkpoint.active_slot=campaign_slot if match_mode=="campaign" else free_slot
		checkpoint_error=Slots.write(Checkpoint.active_slot,{},campaign.to_dict() if match_mode=="campaign" else {"tournament":tournament.to_dict()})
		saved_match.clear()
	ds_battle.reset()
	paused = false
	if is_instance_valid(audio):
		audio.set_suspended(false)
		audio.stop_transients()

	get_tree().paused = false
	_clear_roster_previews()
	_hide_preparation_panels()
	phase_text.visible = true
	rules.new_match(rules_profile)
	selected_deck = _normalize_deck("ability", selected_deck)
	rules.abilities[0] = _make_profile_deck("ability", selected_deck, 0)
	var enemy_stage: int = tournament.stage if match_mode == "tournament" and tournament.active else 0
	rules.abilities[1] = _enemy_profile_deck("ability", enemy_stage)
	selected_gate_deck = _normalize_deck("gate", selected_gate_deck)
	rules.hands[0] = _make_profile_deck("gate", selected_gate_deck, 0)
	rules.hands[1] = _enemy_profile_deck("gate", enemy_stage)
	battle_effects.reset()
	match_stats.reset()
	last_battle_result.clear()
	last_throw_quality = ""
	_cancel_throw_input()
	_apply_settings()
	var theme: String = ["stadium", "canyon", "glacier"][clampi(enemy_stage, 0, 2)] if match_mode == "tournament" and tournament.active else selected_arena
	if match_mode=="campaign": theme=str(campaign.stage().arena)
	arena.set_native_physics(rules_profile == "ds")
	arena.set_board_profile(rules_profile)
	arena.set_field_layout(selected_field_layout)
	arena.set_theme(theme)
	arena.reset_match_field()
	ds_battle.configure(str(arena.theme_id), bool(preferences.reduced_motion))
	arena.clear_highlights()
	rules.teams[0] = Roster.make_team(selected_roster, selected_attributes, 0, true)
	rules.teams[1] = Roster.make_opponent(0, true)
	enemy_power_range = Vector2i(90, 205)
	if match_mode == "tournament" and tournament.active:
		rules.teams[1] = Roster.make_opponent(tournament.stage, true)
		var stage_data: Dictionary = tournament.get_stage()
		enemy_power_range = Vector2i(int(stage_data.enemy_min), int(stage_data.enemy_max))
	if rules_profile=="ds":
		for owner: int in range(2):
			rules.teams[owner] = DSProfiles.apply_team(rules.teams[owner])
	enemy_tactic="balanced"
	if tutorial.active:
		rules.teams[0]=DSProfiles.apply_team(Roster.make_team(DSProfiles.starter_indices(Roster.CREATURES),["Pyrus","Ventus","Aquos"],0,true))
		rules.teams[1]=DSProfiles.apply_team(Roster.make_team(DSProfiles.starter_indices(Roster.CREATURES),["Pyrus","Ventus","Aquos"],1,true))
		rules.hands[0]=DSPlayableCatalog.make_deck("gate",DSPlayableCatalog.default_selection("gate"),0)
		rules.abilities[0]=DSPlayableCatalog.make_deck("ability",DSPlayableCatalog.default_selection("ability"),0)
		rules.hands[1]=DSPlayableCatalog.make_deck("gate",DSPlayableCatalog.default_selection("gate"),1)
		enemy_tactic="offense"
		enemy_power_range=Vector2i(30,55)
	if is_instance_valid(enemy_avatar):
		var opponent: String=str(campaign.stage().opponent) if match_mode=="campaign" else "Дэн"
		enemy_avatar.show_avatar(str({"Дэн":"chara00","Маручо":"chara02","Руно":"chara01","Джули":"chara04","Шун":"chara03","Маскарад":"chara06"}.get(opponent,"chara00")))
	experience_gained=0
	if match_mode=="campaign":
		rules.teams[0]=campaign.player_team()
		rules.teams[1]=campaign.enemy_team()
		rules.hands[0]=DSPlayableCatalog.make_deck("gate",campaign.deck_indices("gate"),0)
		rules.abilities[0]=DSPlayableCatalog.make_deck("ability",campaign.deck_indices("ability"),0)
		rules.hands[1]=DSPlayableCatalog.enemy_deck("gate",campaign_chapter%3)
		rules.abilities[1]=DSPlayableCatalog.enemy_deck("ability",campaign_chapter%3)
		var campaign_stage: Dictionary=campaign.stage()
		enemy_tactic=str(campaign_stage.tactic)
		enemy_power_range=Vector2i(int(campaign_stage.range[0]),int(campaign_stage.range[1]))
	enemy_power_range = GameSettings.enemy_range(enemy_power_range, str(preferences.difficulty))
	audio.set_speaker(str(preferences.avatar),rules.teams[0][0])
	audio.voice_event("match_start")
	_set_overlay_menu_layout(false)
	for n in unit_nodes.values():
		if is_instance_valid(n):
			n.queue_free()
	unit_nodes.clear()
	if is_instance_valid(flight_ball):
		flight_ball.queue_free()
	flight_ball = null
	_clear_pickups()
	roll_motion = RollMotion.new()
	roll_time = 0.0
	roll_bonus = 0
	field_damage = 0
	s_power = [0,0]
	roll_target = Vector3.ZERO
	for old_slot: Variant in arena.gates.keys():
		arena.remove_gate(int(old_slot))
	_clear_dragons()
	journal.clear()
	_log("Тренировка: результаты не записываются." if match_mode in ["training", "practice"] else "Матч начался. Захвати три карты!")
	if match_mode == "tournament" and tournament.active:
		_log("ТУРНИР · %s" % str(tournament.get_stage().title))
	overlay.visible = false
	battle_panel.visible = false
	result_banner.visible = false
	selected_unit = 0
	selected_gate = 0
	charge = 0.0
	charging = false
	flight_time = 0.0
	flight_steer = Vector3.ZERO
	battle_slot = -1
	ds_sequence.clear()
	ds_sequence_stage = ""
	ds_current_event.clear()
	ds_selected_ability = ""
	ds_selected_chain.clear()
	ds_ai_ability = ""
	scratch.set_running(false)
	battle_time = 0.0
	battle_points = 0
	ability_points = 0
	ai_points = 0
	ai_target_points = 0
	ai_ability_used = false
	used_battle_abilities = false
	hit_cooldown = 0.0
	last_shake_key = 0
	pending_double_slot = -1
	powered_throw = false
	flight_powered = false
	flight_special = ""
	field_effects = FieldCards.initial()
	extra_throw_owner = -1
	flight_style = ThrowMotion.normalize_style(throw_style)
	flight_charge = 0.0
	battle_streak = 0
	bonus_mode = false
	timing_sequence = 0
	timing_window_active = false
	timing_window_hit = false
	circle_sequence = 0
	_refresh_hud()
	if match_mode != "practice" and not restoring_match:
		_begin_opening()
		_save_checkpoint()

func _begin_player_turn() -> void:
	if not _prepare_turn(0):
		return
	if rules.gates.is_empty():
		_begin_opening()
		return
	selected_gate = 0
	var available: Array = rules.available_units(0)
	if not available.is_empty():
		selected_unit = int(available[0])
	if rules.can_place_gate(0) and not _free_slots().is_empty():
		phase = "place"
		phase_text.text = "ДОБАВИТЬ КАРТУ ВОРОТ?"
		instruction.text = "Можно поставить одну карту рядом с воротами по стороне. ПРОБЕЛ — перейти к броску без карты."
		target_marker.visible = false
		trajectory.visible = false
		arena.highlight_legal_slots(_free_slots())
	else:
		_begin_aim()
	_refresh_hud()
	_update_cards()

func _prepare_turn(owner: int) -> bool:
	if rules.winner >= 0:
		_end_match()
		return false
	var stay: Dictionary = rules.process_stay(owner)
	if not stay.is_empty():
		var slot: int = int(stay.slot)
		match_stats.record_capture(owner, false)
		arena.capture_effect(arena.slot_position(slot), ORANGE if owner == 0 else CYAN)
		arena.remove_gate(slot)
		_sync_units()
		_log("STAY: %s забирает ворота %d." % ["ты" if owner == 0 else "соперник", slot + 1])
		_refresh_hud()
		if rules.winner >= 0:
			_end_match()
			return false
	rules.recycle_used(owner)
	if rules.needs_stay(owner):
		if owner == 0:
			phase = "stay"
			phase_text.text = "STAY — ВЫБЕРИ БАКУГАНА"
			instruction.text = "Все трое стоят. Выбери 1–3: если бакуган останется до твоего следующего хода, получишь карту."
			target_marker.visible = false
			trajectory.visible = false
			_update_cards()
		else:
			for slot in rules.gates:
				if rules.choose_stay(owner, int(slot)):
					_log("Соперник объявляет STAY на воротах %d." % (int(slot) + 1))
					_announce_then_advance("СОПЕРНИК: STAY", CYAN)
					break
		return false
	return true

func _begin_opening() -> void:
	if not rules.begin_opening():
		return
	opening_resume_owner = rules.turn
	selected_gate = 0
	if rules_profile=="ds" and bool(preferences.ds_auto_gates):
		for owner: int in range(2):
			if not rules.hands[owner].is_empty():
				var slot: int = 19 if owner==0 else 28
				if rules.place_gate(owner,0,slot,true):
					_draw_gate(slot)
		if rules.turn==0:
			_begin_player_turn()
		else:
			_ai_turn()
		return
	if rules.hands[0].is_empty():
		_finish_opening()
		return
	phase = "opening"
	phase_text.text = "НАЧАЛО — ОБА СТАВЯТ ВОРОТА"
	instruction.text = "Выбери карту внизу и поставь её на подсвеченную центральную позицию ближе к сопернику. Его начальная карта окажется ближе к тебе." if rules_profile == "ds" else "Выбери карту внизу и нажми на один из четырёх центральных контуров. Затем соперник выставит свою."
	target_marker.visible = false
	trajectory.visible = false
	arena.highlight_legal_slots(rules.legal_gate_slots(true, 0))
	_update_cards()

func _finish_opening() -> void:
	var legal: Array[int] = rules.legal_gate_slots(true, 1)
	if not rules.hands[1].is_empty() and not legal.is_empty():
		var slot: int = legal[0]
		if not rules.gates.is_empty():
			var player_slot: int = int(rules.gates.keys()[0])
			for candidate in legal:
				if arena.slot_position(candidate).distance_to(arena.slot_position(player_slot)) > arena.slot_position(slot).distance_to(arena.slot_position(player_slot)):
					slot = candidate
		var index: int = TacticalAI.choose_gate(rules, 1)
		if index >= 0 and rules.place_gate(1, index, slot, true):
			_draw_gate(slot)
			_log("Соперник выставил закрытые ворота %d." % (slot + 1))
	arena.clear_highlights()
	_refresh_hud()
	if opening_resume_owner == 0:
		_begin_player_turn()
	else:
		_ai_turn()

func _draw_gate(slot: int, revealed: bool = false) -> void:
	var gate: Dictionary = rules.gates[slot]
	arena.make_gate(slot, int(gate.owner), str(gate.title), revealed, str(gate.color_type), str(gate.get("source_key", "")))
	if is_instance_valid(audio): audio.event("gate_opened" if revealed else "gate_placed")

func _skip_gate() -> void:
	if phase == "place" and not paused:
		_begin_aim()

func _phase_action() -> void:
	if paused:
		return
	if rules_profile=="ds" and phase in ["flying","rolling"]:
		_jump_ds_sphere()
	elif phase == "place":
		_skip_gate()
	elif phase == "battle_ready":
		_start_battle_game()
	elif phase == "double":
		_resolve_double(-1)

func _special_ready(owner: int, index: int) -> bool:
	return rules.teams.size()==2 and owner in [0,1] and index in [0,1,2] and SpecialShots.available(rules.teams[owner][index],s_power[owner],match_mode)

func _activate_field_card(id: int) -> void:
	if rules_profile!="ds" or id not in FieldCards.IDS or phase not in ["flying","rolling"]: return
	field_effects.ids.append(id)
	_log("Карта поля: "+FieldCards.title(id)+".")
	audio.event("ability")
	match id:
		701: extra_throw_owner=flight_owner
		702: field_effects["restart"]=true
		703: field_effects.swap_gate=true
		704: field_effects.replace_unit=true
		705: field_effects.early=true
		706: field_effects.surprise=true
		707: field_effects.road_trip=true
		708: field_effects.invulnerable=true
		709: field_effects.multiplier=2
		710: s_power[flight_owner]=100; _refresh_s_power()
		711,712:
			rules.change_field_pickups(id==712)
			if id==711: roll_bonus=0
			field_effects.multiplier=2 if id==712 else 1

func _field_card_landing_slot(slot: int) -> int:
	if not rules.gates.has(slot): return slot
	if field_effects.get("road_trip",false):
		var slots: Array=rules.gates.keys(); slots.sort()
		slot=int(slots[rng.randi_range(0,slots.size()-1)])
		_log("Road Trip: перемещение на ворота %d." % (slot+1))
	if field_effects.get("surprise",false):
		var targets: Array[int]=[]
		for key: Variant in rules.gates:
			var occupants: Array=rules.gates[key].bakugan
			if occupants.size()==1 and int(occupants[0].owner)!=flight_owner: targets.append(int(key))
		if not targets.is_empty():
			targets.sort(); slot=targets[rng.randi_range(0,targets.size()-1)]
	if field_effects.get("swap_gate",false) and rules.swap_field_gate(flight_owner,slot,clampi(selected_gate if flight_owner==0 else 0,0,rules.hands[flight_owner].size()-1)):
		arena.remove_gate(slot); _draw_gate(slot)
		_log("Sleight of Hand: ворота заменены картой из руки.")
	if field_effects.get("replace_unit",false):
		for index: int in rules.available_units(flight_owner):
			if index==flight_unit: continue
			flight_unit=index
			_log("Trickster: на карте встанет "+str(rules.teams[flight_owner][index].name)+".")
			break
	return slot

func _special_landing(slot: int) -> bool:
	if not rules.gates.has(slot): return false
	field_effects.invulnerable=bool(field_effects.get("invulnerable",false)) or SpecialShots.protected(flight_special)
	field_effects["removal_protected"]=flight_special=="Darkus"
	var opposed: bool=rules.gates[slot].bakugan.size()==1 and int(rules.gates[slot].bakugan[0].owner)!=flight_owner
	if flight_special=="Subterra" or (flight_special=="Haos" and opposed and sphere_collision_slot==slot):
		var targets: Array=[slot]
		if flight_special=="Subterra": targets.append_array(BoardLayout.neighbors(slot,"ds"))
		else: targets=rules.gates.keys()
		var removed: int=rules.remove_field_units(targets)
		rules.consume_throw(flight_owner,flight_unit,false)
		_sync_units(); _refresh_hud()
		arena.landing_flash(arena.slot_position(slot),ORANGE)
		_log("%s: с поля убрано %d бакуганов; карты остались." % [SpecialShots.title(flight_special),removed])
		_announce_then_advance(SpecialShots.title(flight_special).to_upper(),CYAN)
		return true
	if flight_special=="Ventus" and opposed and sphere_collision_slot==slot:
		rules.remove_field_units([slot]); _sync_units()
		_log("Ventus Storm: противник сдут с ворот, защищённые бакуганы остаются.")
	return false

func _toggle_throw_mode() -> void:
	if phase != "aim" or paused:
		return
	if rules_profile=="ds" and not powered_throw and not _special_ready(0,selected_unit):
		return
	powered_throw = not powered_throw
	_update_cards()
	_draw_trajectory()

func _toggle_throw_style() -> void:
	if phase != "aim" or paused:
		return
	throw_style = "straight" if ThrowMotion.normalize_style(throw_style) == "lob" else "lob"
	_save_profile()
	_update_cards()
	_draw_trajectory()

func _begin_aim(target_slot: int = -1) -> void:
	phase = "aim"
	arena.restore_board_view()
	charging = false
	charge = 0.0
	last_throw_quality = ""
	power_bar.value = 0
	target_marker.visible = true
	trajectory.visible = true
	if rules.gates.has(target_slot):
		aim_point = arena.slot_position(target_slot)
	elif not rules.gates.is_empty():
		aim_point = arena.slot_position(int(rules.gates.keys()[0]))
	phase_text.text = "БАКУГАН — В БОЙ!"
	instruction.text = "Поле / мини-карта — цель · Сфера — жест вверх · T — бросок · Q/E — камера · Колесо — масштаб" if rules_profile == "ds" else "Мышь — цель · T — высокий / прямой · P — усиление · ПРОБЕЛ — сила и бросок · WASD — сбор G-Power."
	_update_cards()

func _free_slots() -> Array[int]:
	return rules.legal_gate_slots(phase == "opening", 0)

func _choose_card(index: int) -> void:
	if paused or index < 0:
		return
	match phase:
		"place", "opening":
			if index < rules.hands[0].size():
				selected_gate = index
				_play_sound("click")
		"aim":
			if rules.available_units(0).has(index):
				selected_unit = index
				if is_instance_valid(tutorial): tutorial.observe("unit")
				_play_sound("click")
		"stay":
			for slot in rules.gates:
				var occupants: Array = rules.gates[slot].bakugan
				if occupants.size() == 1 and int(occupants[0].owner) == 0 and int(occupants[0].index) == index and rules.choose_stay(0, int(slot)):
					_log("STAY: %s на воротах %d." % [str(occupants[0].name), int(slot) + 1])
					_announce_then_advance("STAY — ЖДИ СЛЕДУЮЩЕГО ХОДА", ORANGE)
					break
		"battle", "battle_ready":
			if rules_profile=="ds" and phase=="battle_ready":
				if index>=0 and index<rules.abilities[0].size() and _ability_allowed(0,rules.abilities[0][index]):
					var identity: String = str(rules.abilities[0][index].id)
					if ds_selected_chain.has(identity): ds_selected_chain.erase(identity)
					else: ds_selected_chain.append(identity)
					ds_selected_ability = ds_selected_chain[0] if not ds_selected_chain.is_empty() else ""
				elif index<rules.abilities[0].size():
					_log("Карта недоступна: "+_ability_unavailable_reason(0,rules.abilities[0][index]))
			else:
				_play_ability(0, index)
	_update_cards()

func _battle_unit(owner: int) -> Dictionary:
	if rules.gates.has(battle_slot):
		for unit in rules.gates[battle_slot].bakugan:
			if int(unit.owner) == owner:
				return unit
	return {}

func _battle_card_context(owner: int) -> Dictionary:
	var context: Dictionary = rules.battle_context(battle_slot, owner)
	context["team_attributes"]=[]; context["reserve_attributes"]=[]
	for index: int in rules.teams[owner].size():
		context.team_attributes.append(str(rules.teams[owner][index].attribute))
		if rules.available_units(owner).has(index): context.reserve_attributes.append(str(rules.teams[owner][index].attribute))
	context["gate_color"]=str(rules.gates.get(battle_slot,{}).get("color_type",""))
	context["blocked_families"]=battle_effects.states[owner].blocked_families
	context["opponent_blocked_families"]=battle_effects.states[1-owner].blocked_families
	context["redo_used"]=battle_effects.states[owner].redo_used
	context["preview_chain"]=phase=="battle_ready"
	var include_mini: bool = phase=="battle" and rules_profile!="ds"
	var enemy_mini: int = int(float(ai_target_points) * clampf(battle_time / maxf(battle_duration, 0.001), 0.0, 1.0)) if include_mini else 0
	context["current_powers"] = [
		_battle_base(0) + battle_effects.extra(0, battle_points if include_mini else 0),
		_battle_base(1) + battle_effects.extra(1, enemy_mini),
	]
	return context

func _ability_allowed(owner: int, card: Dictionary) -> bool:
	if not rules.ability_block_reason(battle_slot, owner).is_empty():
		return false
	return BattleEffects.can_play(card, _battle_unit(owner), _battle_unit(1 - owner), battle_type, phase == "battle_ready", _battle_card_context(owner))

func _ability_unavailable_reason(owner: int, card: Dictionary) -> String:
	var gate_reason: String = rules.ability_block_reason(battle_slot, owner)
	if not gate_reason.is_empty():
		return gate_reason
	var unit: Dictionary = _battle_unit(owner)
	if unit.is_empty():
		return "Сначала нужен бой двух соперников на воротах."
	var allowed_attributes: Array = card.get("attributes", [])
	if not allowed_attributes.is_empty() and not allowed_attributes.has(str(unit.get("attribute", ""))):
		return "Нужна стихия: %s." % ", ".join(allowed_attributes)
	var effect: Dictionary = card.get("effect", {})
	var context: Dictionary = _battle_card_context(owner)
	var family: String = str(effect.get("type",""))
	if family=="power_swap": family="swap"
	if family=="level_field": family="redo"
	if context.blocked_families.has(family): return "Соперник запретил этот тип карт до конца боя."
	if effect.has("own_attribute") and str(effect.own_attribute)!=str(unit.attribute): return "Нужна стихия: "+str(effect.own_attribute)+"."
	if effect.has("relationship"):
		var same: bool = str(unit.attribute)==str(_battle_unit(1-owner).attribute)
		if same!=(str(effect.relationship)=="same"): return "Нужны совпадающие стихии." if str(effect.relationship)=="same" else "Нужны разные стихии."
	if str(effect.get("type","")) in ["redo","level_field"]: return "Перезапуск уже использован этой стороной в текущем бою."
	if str(effect.get("type",""))=="block_family": return "Этот запрет уже действует на соперника."
	if str(effect.get("type",""))=="skip_battle": return "Нужны ворота цвета: "+str(effect.get("gate_color","любой"))+"."
	if str(effect.get("type","")) in ["hand_combo","team_combo"]: return "Нужны стихии "+", ".join(effect.required_attributes)+(" в резерве." if str(effect.type)=="hand_combo" else " в команде.")
	if str(effect.get("type",""))=="opponent_combo": return "Нужна стихия соперника: "+str(effect.opponent_attribute)+"."
	if str(effect.get("type", "")) in ["species_bonus", "character_bonus"] and str(unit.get("name", "")).to_lower() != str(effect.get("species", "")).to_lower():
		return "Нужен бакуган: %s." % str(effect.get("species", ""))
	if str(effect.get("type", "")) == "different_attribute_bonus":
		return "У соперника должна быть другая стихия."
	if str(effect.get("type", "")) == "attribute_power":
		return "У этой карты нет бонуса для твоей стихии."
	if str(effect.get("type", "")) == "gate_owned_power":
		return "Бой должен проходить на воротах соперника." if str(effect.get("gate_relation", "own")) == "opponent" else "Бой должен проходить на твоих воротах."
	if str(effect.get("type", "")) == "captured_gate_bonus":
		return "Для бонуса нужна хотя бы одна ранее захваченная карта ворот."
	if str(effect.get("type", "")) == "higher_opponent_printed_power":
		return "Исходная G-Power соперника должна быть выше твоей."
	if str(effect.get("type", "")) == "power_swap":
		if effect.has("own_attribute") and str(effect.own_attribute) != str(unit.get("attribute", "")):
			return "Нужна стихия: %s." % str(effect.own_attribute)
		if effect.has("relationship"):
			var same: bool = str(unit.get("attribute", "")) == str(_battle_unit(1 - owner).get("attribute", ""))
			if same != (str(effect.relationship) == "same"):
				return "Стихия соперника должна совпадать с твоей." if str(effect.relationship) == "same" else "У соперника должна быть другая стихия."
		return "Для обмена G-Power обеих сторон должна отличаться."
	if str(effect.get("type", "")) == "battle_type":
		return "Смена мини-игры доступна до боя и должна менять текущий вид."
	return "Условие карты сейчас не выполнено: %s" % str(card.get("description", ""))

func _play_ability(owner: int, index: int) -> bool:
	if owner < 0 or owner > 1 or rules.winner != -1 or not rules.gates.has(battle_slot):
		return false
	if rules.gates[battle_slot].bakugan.size() != 2:
		return false
	if index < 0 or index >= rules.abilities[owner].size() or phase not in ["battle_ready", "battle"]:
		return false
	var card: Dictionary = rules.abilities[owner][index]
	if rules_profile=="ds":
		if phase!="battle": return false
		if owner==0 and str(card.id)!=ds_selected_ability: return false
	if not _ability_allowed(owner, card):
		return false
	var projected = battle_effects.copy()
	var context: Dictionary = _battle_card_context(owner)
	if not projected.apply(owner, card, _battle_unit(owner), _battle_unit(1 - owner), battle_type, phase == "battle_ready", context):
		return false
	if rules.use_ability(owner, index, battle_slot, battle_type, phase == "battle_ready", context).is_empty():
		return false
	battle_effects = projected
	if owner == 0:
		ability_points = int(battle_effects.states[0].power)
		used_battle_abilities = true
	else:
		ai_points = int(battle_effects.states[1].power)
		ai_ability_used = true
	if str(card.get("type", "")) == "battle_type":
		battle_type = battle_effects.selected_battle_type(battle_type)
		_configure_minigame()
	_log("%s%s: %s" % ["Соперник: " if owner == 1 else "", str(card.title), str(card.description)])
	audio.set_speaker(str(preferences.avatar) if owner==0 else str(enemy_avatar.avatar_id),_battle_unit(owner))
	audio.event("ability")
	_refresh_hud()
	_refresh_battle_scores()
	_sync_ds_battle({"event": "ability_played", "owner": owner, "title": str(card.title)})
	_update_cards()
	if rules_profile=="ds":
		if owner==0:
			ds_selected_chain.erase(str(card.id))
			ds_selected_ability = ds_selected_chain[0] if not ds_selected_chain.is_empty() else ""
		_apply_ds_mode_effect(owner,card)
		_start_ds_sequence([{"stage":"ability","event":"ability_scene","owner":owner,"source_key":str(card.get("source_key","")),"title":str(card.title),"description":str(card.description),"duration":1.7}],"battle")
	return true

func _apply_ds_mode_effect(owner: int, card: Dictionary) -> void:
	var effect: Dictionary = card.effect
	if str(effect.type) in ["redo","level_field"]:
		if str(effect.type)=="redo" and str(effect.get("mode","current"))!="current": battle_type=str(effect.mode)
		battle_time=0.0; battle_points=0; ds_enemy_progress=0.0
		scratch.configure(str(_battle_unit(0).attribute),battle_type)
		_configure_minigame()
	if str(effect.type)=="skip_battle":
		ds_skip_pending=true; battle_points=0; ds_enemy_progress=0.0; ai_target_points=0; scratch.score=0
	scratch.input_multiplier=float(battle_effects.states[0].input_multiplier)
	scratch.blocked=float(battle_effects.states[0].input_block)

func _skip_ds_chain_card() -> void:
	if ds_selected_chain.is_empty(): return
	ds_selected_chain.pop_front()
	ds_selected_ability=ds_selected_chain[0] if not ds_selected_chain.is_empty() else ""
	_update_cards()

func _place_player_gate(slot: int) -> void:
	if phase not in ["place", "opening"] or paused:
		return
	var opening: bool = phase == "opening"
	if rules.place_gate(0, selected_gate, slot, opening):
		_draw_gate(slot)
		_log("Твоя карта %s на месте %d." % [str(rules.gates[slot].title), slot + 1])
		if opening:
			_finish_opening()
		else:
			_begin_aim(slot)
		_refresh_hud()
	else:
		instruction.text = "Выбери подсвеченный контур: центральный при начале, по стороне соседних ворот во время матча."

func _input(event: InputEvent) -> void:
	for name: String in ["SaveFailureDialog","ReplaceSlotDialog","MenuSaveFailureDialog"]:
		var dialog: Window=get_node_or_null(name) as Window
		if dialog!=null and dialog.visible: return
	controls.record(event)
	if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_B and event.pressed and paused:
		_toggle_pause(); get_viewport().set_input_as_handled(); return
	if is_instance_valid(settings_panel) and not settings_panel.capture_action.is_empty(): return
	if is_instance_valid(tutorial) and tutorial.active and tutorial.visible and tutorial.next.visible and not paused:
		var accept: bool=event is InputEventJoypadButton and event.button_index==JOY_BUTTON_A and event.pressed
		if event is InputEventKey:
			var mapped: InputEventKey=Controls.remap(event,preferences)
			accept=mapped.pressed and not mapped.echo and mapped.keycode in [KEY_SPACE,KEY_ENTER]
		if accept:
			tutorial.advance(); get_viewport().set_input_as_handled(); return
	if event is InputEventJoypadMotion and event.axis==JOY_AXIS_TRIGGER_RIGHT and phase=="battle" and rules_profile=="ds" and not paused:
		var held_now: bool=event.axis_value>0.5
		if held_now!=bool(controls.buttons.get("trigger",false)):
			controls.buttons["trigger"]=held_now
			controls.pointer_action(scratch,held_now)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and phase in Checkpoint.PHASES and not overlay.visible:
		var physical: int=int(event.physical_keycode if event.physical_keycode!=0 else event.keycode)
		if physical in preferences.bindings.values() or event.keycode in [KEY_ESCAPE,KEY_ENTER]:
			_unhandled_input(event)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton:
		if event.button_index==JOY_BUTTON_B and event.pressed and phase in ["roster","deck","gates","settings","help","training_setup","model","card_view","campaign"]:
			var escape:=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
			_unhandled_input(escape); get_viewport().set_input_as_handled(); return
		if not overlay.visible and phase in Checkpoint.PHASES:
			_unhandled_input(event); get_viewport().set_input_as_handled(); return
	# Keep the captured stroke when its release crosses a HUD panel.
	if ds_gesture.active and (event is InputEventMouseMotion or (event is InputEventMouseButton and not event.pressed)):
		_unhandled_input(event)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_throw_input()
		controls.reset()
		if is_instance_valid(scratch): scratch.release()

func _cancel_throw_input() -> void:
	ds_gesture.cancel()
	charging = false
	charge = 0.0

func _rotate_ds_view(direction: int) -> void:
	if rules_profile!="ds" or paused or overlay.visible or phase not in ["opening","place","aim","stay","double"]:
		return
	_cancel_throw_input()
	arena.rotate_view(direction)
	_trajectory_cache_key.clear()
	if phase=="aim":
		_draw_ds_trajectory()

func _jump_ds_sphere() -> bool:
	if rules_profile!="ds" or paused or flight_owner!=0 or phase not in ["flying","rolling"] or not is_instance_valid(flight_ball):
		return false
	var jumped: bool = ds_sphere.jump()
	if jumped: _play_sound("jump")
	return jumped

func _set_ds_aim_from_screen(screen: Vector2) -> void:
	var origin: Vector3 = arena.camera.project_ray_origin(screen)
	var direction: Vector3 = arena.camera.project_ray_normal(screen)
	var hit: Variant = Plane(Vector3.UP,0.0).intersects_ray(origin,direction)
	if hit != null:
		aim_point = arena.clamp_aim(hit)
		if is_instance_valid(tutorial): tutorial.observe("aim")

func _unhandled_input(event: InputEvent) -> void:
	for name: String in ["SaveFailureDialog","ReplaceSlotDialog","MenuSaveFailureDialog"]:
		var dialog: Window=get_node_or_null(name) as Window
		if dialog!=null and dialog.visible: return
	if event is InputEventKey: event=Controls.remap(event,preferences)
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and rules_profile=="ds" and not paused and not overlay.visible and phase in ["aim","flying","rolling","opening","place"]:
		arena.zoom_view(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1)
		return
	if event is InputEventKey:
		if event.echo:
			return
		if event.keycode == KEY_ESCAPE and event.pressed:
			if phase == "source_cards":
				source_card_browser.close_browser()
			elif phase == "card_view":
				_close_card_view()
			elif phase == "model":
				_open_roster()
			elif phase == "roster":
				_close_roster()
			elif phase == "deck":
				_close_deck()
			elif phase in ["gates", "settings", "help", "training_setup", "campaign", "saves"]:
				_close_preparation()
			else:
				_toggle_pause()
			return
		if paused or overlay.visible:
			if event.keycode == KEY_ENTER and event.pressed and not paused:
				_overlay_primary()
			return
		if event.keycode==KEY_BACKSPACE and event.pressed and rules_profile=="ds" and phase=="battle":
			_skip_ds_chain_card()
		if event.keycode >= KEY_1 and event.keycode <= KEY_3 and event.pressed:
			var index: int = event.keycode - KEY_1
			_choose_card(index)
		if event.keycode == KEY_SPACE:
			_handle_action(event.pressed)
		if event.keycode in [KEY_R,KEY_F] and event.pressed and rules_profile=="ds":
			arena.zoom_view(-1 if event.keycode==KEY_R else 1)
		if event.keycode==KEY_H and event.pressed:
			_toggle_pause()
			return
		if event.keycode == KEY_P and event.pressed:
			_toggle_throw_mode()
		if event.keycode == KEY_T and event.pressed:
			_toggle_throw_style()
		if event.keycode in [KEY_Q,KEY_E] and event.pressed:
			_rotate_ds_view(-1 if event.keycode==KEY_Q else 1)
		if event.keycode == KEY_ENTER and event.pressed:
			_phase_action()
		if phase == "battle" and event.pressed and [KEY_A, KEY_D, KEY_W, KEY_S].has(event.keycode):
			_battle_hit(event.keycode)
	elif event is InputEventMouseMotion and ds_gesture.active:
		ds_gesture.move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if paused or overlay.visible:
			return
		if phase in ["place", "opening", "double"] and event.pressed and _mouse_in_arena(event.position):
			var hit = _mouse_on_floor()
			var slot: int = _nearest_slot(hit, 1.25)
			if slot >= 0:
				if phase == "double":
					_resolve_double(slot)
				else:
					_place_player_gate(slot)
		elif rules_profile == "ds" and phase in ["aim","flying","rolling"] and (phase == "aim" or flight_owner == 0) and (_mouse_in_arena(event.position) or ds_gesture.active or _near_ready_sphere(event.position)):
			if event.pressed:
				var near_sphere: bool = _near_ready_sphere(event.position)
				if phase != "aim" or near_sphere:
					ds_gesture.begin(event.position,Time.get_ticks_msec()/1000.0)
				else:
					_set_ds_aim_from_screen(event.position)
			else:
				var gesture: Dictionary = ds_gesture.finish(event.position,Time.get_ticks_msec()/1000.0,phase != "aim")
				if bool(gesture.get("valid",false)):
					if phase == "aim":
						charge = float(gesture.power)
						_launch_ball(0,selected_unit,arena.ground_point(aim_point))
					else:
						ds_sphere.impulse(arena.control_direction(gesture.direction),gesture.power)
				elif phase == "aim":
					instruction.text = "Проведи мышью вверх не менее 40 пикселей и отпусти: быстрее жест — сильнее бросок."
		elif phase == "aim" and (_mouse_in_arena(event.position) or (not event.pressed and charging)):
			_handle_action(event.pressed)
	elif event is InputEventJoypadButton:
		if event.button_index==JOY_BUTTON_START and event.pressed:
			_toggle_pause()
		elif paused: return
		elif phase=="battle" and rules_profile=="wii" and event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER] and event.pressed:
			if battle_type=="shooting":
				pad_shoot_target=posmod(pad_shoot_target+(-1 if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_LEFT_SHOULDER] else 1),shooting_targets.size())
				shooting_targets[pad_shoot_target].grab_focus()
			else:
				_battle_hit(int({JOY_BUTTON_DPAD_LEFT:KEY_A,JOY_BUTTON_DPAD_RIGHT:KEY_D,JOY_BUTTON_DPAD_UP:KEY_W,JOY_BUTTON_DPAD_DOWN:KEY_S,JOY_BUTTON_LEFT_SHOULDER:KEY_A,JOY_BUTTON_RIGHT_SHOULDER:KEY_D}[event.button_index]))
		elif event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER] and event.pressed:
			_rotate_ds_view(-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1)
		elif event.button_index==JOY_BUTTON_X and event.pressed:
			_toggle_throw_style()
		elif event.button_index==JOY_BUTTON_Y and event.pressed:
			_toggle_throw_mode()
		elif event.button_index==JOY_BUTTON_B and event.pressed and phase=="battle" and rules_profile=="ds":
			_skip_ds_chain_card()
		elif event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN] and event.pressed:
			var direction: int=-1 if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_UP] else 1
			if phase=="aim":
				var choices: Array=rules.available_units(0)
				if not choices.is_empty(): _choose_card(int(choices[posmod(choices.find(selected_unit)+direction,choices.size())]))
			elif phase in ["opening","place"]:
				if not rules.hands[0].is_empty(): _choose_card(posmod(selected_gate+direction,rules.hands[0].size()))
			elif phase in ["battle_ready","battle"]:
				if not rules.abilities[0].is_empty():
					selected_gate=posmod(selected_gate+direction,rules.abilities[0].size())
					_choose_card(selected_gate)
		elif event.button_index==JOY_BUTTON_A:
			if overlay.visible and event.pressed: _overlay_primary()
			else: _handle_action(event.pressed)

func _handle_action(pressed: bool) -> void:
	if paused or overlay.visible: return
	if phase=="battle" and rules_profile=="ds":
		controls.pointer_action(scratch,pressed)
		return
	if rules_profile=="ds" and phase in ["flying","rolling"] and pressed:
		_jump_ds_sphere()
	elif phase in ["place", "battle_ready", "double"] and pressed:
		_phase_action()
	elif phase == "aim":
		if pressed:
			if tutorial.active and not tutorial.permits_throw(): return
			charging = true
			charge = 0.0
		elif charging:
			charging = false
			last_throw_quality = "ТОЧНЫЙ БРОСОК" if charge >= 0.62 and charge <= 0.78 else ("СЛАБЫЙ БРОСОК" if charge < 0.62 else "ПЕРЕБОР СИЛЫ")
			var endpoint: Vector3 = _throw_target(aim_point, charge)
			_launch_ball(0, selected_unit, endpoint)
	elif phase == "battle" and pressed:
		if battle_type=="shooting": _shoot_target(pad_shoot_target)
		else: _battle_hit()
	elif phase == "rolling" and pressed and rules_profile != "ds":
		_land_ball()

func _process(delta: float) -> void:
	_sync_audio_context()
	if is_instance_valid(tutorial): tutorial.update()
	if is_instance_valid(player_avatar):
		var show: bool=phase in ["battle_ready","battle","ds_scene","result"]
		player_avatar.visible=show and not tutorial.active and not overlay.visible
		enemy_avatar.visible=show and not overlay.visible
		player_avatar.set_suspended(paused or not player_avatar.visible)
		enemy_avatar.set_suspended(paused or not enemy_avatar.visible)
	if phase in Checkpoint.PHASES:
		phase_text.visible=phase not in ["battle","battle_ready","ds_scene"]
		instruction.visible=phase!="battle"
	if paused:
		ds_gesture.cancel()
		return
	if phase in ["place","opening","aim","ai","stay","double"]:
		arena.advance_field(delta)
	match phase:
		"ds_scene":
			_step_ds_sequence(delta)
		"aim":
			_update_aim(delta)
		"flying":
			_update_flight(delta)
		"rolling":
			_update_roll(delta)
		"battle":
			_update_battle(delta)
		"roster", "model":
			_update_roster_rotation(delta)
	checkpoint_clock += delta
	if phase in Checkpoint.PHASES and (checkpoint_clock>=3.0 or checkpoint_phase!=phase):
		_save_checkpoint()

func _near_ready_sphere(screen: Vector2) -> bool:
	return phase=="aim" and is_instance_valid(ds_ready_ball) and arena.camera.unproject_position(ds_ready_ball.global_position).distance_to(screen)<60.0

func _quit_game() -> void:
	_save_checkpoint()
	_save_profile()
	preload("res://scripts/save_files.gd").quit_or_warn(self,[profile_error,checkpoint_error])

func _save_checkpoint() -> void:
	if restoring_match: return
	var data: Dictionary=Checkpoint.capture(self)
	if data.is_empty():
		checkpoint_error=OK
		return
	saved_match=data
	checkpoint_clock=0.0; checkpoint_phase=phase
	checkpoint_error=Slots.write(Checkpoint.active_slot,data,campaign.to_dict() if match_mode=="campaign" else {"tournament":tournament.to_dict()})

func _resume_match() -> void:
	var data: Dictionary=saved_match.duplicate(true)
	if not Checkpoint.valid(data):
		overlay_body.text="Сохранение матча повреждено. Профиль и кампания сохранены."
		return
	# Presentation preferences belong to the profile, not to an older match.
	for key: String in ["volume","music_volume","effects_volume","voice_volume","reduced_motion","subtitles","bindings","avatar","render_scale","msaa","frame_cap","vsync","screen_mode","camera_sensitivity","gamepad_deadzone","tutorial_completed"]:
		data.main.preferences[key]=preferences[key]
	if data.get("mode","")=="anime":
		audio.stop_transients(); audio.music.stop(); _save_profile()
		var duel: Node3D=load("res://anime_duel.tscn").instantiate()
		duel.configure(data.main.selected_team,str(data.main.arena_id),data.main.preferences,str(data.main.throw_style))
		duel.save_slot=Checkpoint.active_slot
		duel.resume_data=data
		get_tree().root.add_child(duel); get_tree().current_scene=duel
		queue_free()
		return
	if not Checkpoint.compatible(self,data.main,Checkpoint.MAIN_FIELDS):
		overlay_body.text="Формат состояния матча не поддерживается."
		return
	for pair: Array in [[rules,data.rules,Checkpoint.RULE_FIELDS],[ds_sphere,data.sphere,Checkpoint.SPHERE_FIELDS],[roll_motion,data.roll,Checkpoint.ROLL_FIELDS],[battle_effects,data.effects,Checkpoint.EFFECT_FIELDS],[scratch,data.mini,Checkpoint.MINI_FIELDS]]:
		if not Checkpoint.compatible(pair[0],pair[1],pair[2]):
			overlay_body.text="Сохранение содержит несовместимые данные боя."
			return
	restoring_match=true
	rules_profile=str(data.main.rules_profile); match_mode=str(data.main.match_mode)
	campaign_chapter=int(data.main.campaign_chapter)
	selected_arena=str(data.field.theme); selected_field_layout=int(data.field.layout)
	start_match()
	Checkpoint.put(rules,data.rules,Checkpoint.RULE_FIELDS)
	Checkpoint.put(self,data.main,Checkpoint.MAIN_FIELDS)
	Checkpoint.put(ds_sphere,data.sphere,Checkpoint.SPHERE_FIELDS)
	if data.get("special") is Dictionary:
		Checkpoint.put(self,data.special.get("main",{}),["flight_special","field_effects","extra_throw_owner"])
		Checkpoint.put(ds_sphere,data.special.get("sphere",{}),["special_shot","field_start_clock"])
	elif flight_powered:
		# Old saves keep the legacy power impulse, not a newly invented shot.
		flight_special=""
	arena.configure_roll(roll_motion)
	Checkpoint.put(roll_motion,data.roll,Checkpoint.ROLL_FIELDS)
	Checkpoint.put(battle_effects,data.effects,Checkpoint.EFFECT_FIELDS)
	match_stats.totals.assign(data.stats)
	_apply_settings()
	arena.view_quadrant=int(data.field.quadrant); arena.camera_zoom=float(data.field.zoom)
	if arena.native_surface!=null:
		arena.native_surface.clock=float(data.field.clock)
		arena.native_surface.advance(0.0,true)
	if is_instance_valid(arena.field_objects):
		arena.field_objects.advance(float(data.field.clock))
		for id: int in data.field.collected: arena.field_objects.collect(id)
	for slot: Variant in rules.gates:
		_draw_gate(int(slot),bool(rules.gates[slot].get("revealed",false)))
	_sync_units()
	if bool(data.has_flight):
		var unit: Dictionary=rules.teams[flight_owner][flight_unit]
		flight_ball=arena.make_ball(str(unit.attribute),flight_owner,str(unit.name))
		flight_ball.transform=data.flight_transform
		_attach_special_aura()
	_spawn_pickups()
	if not data.pickups.is_empty():
		if rules_profile=="ds" and is_instance_valid(arena.field_objects):
			# Rebuild pickup nodes, preserving the saved collected flags.
			var nodes: Dictionary={}
			for item: Dictionary in arena.field_objects.items: nodes[int(item.id)]=item.node
			pickups.clear()
			for item: Dictionary in data.pickups:
				var copy: Dictionary=item.duplicate(true)
				copy["node"]=nodes.get(int(copy.get("id",-1)))
				pickups.append(copy)
		else:
			_clear_pickups()
			for item: Dictionary in data.pickups:
				var copy: Dictionary=item.duplicate(true)
				copy["node"]=null if bool(copy.collected) else arena.make_pickup(copy.position,int(copy.amount))
				pickups.append(copy)
	rng.seed=int(data.rng_seed); rng.state=int(data.rng_state)
	if phase in ["battle_ready","battle","ds_scene"]:
		_configure_minigame()
		scratch.configure(str(_battle_unit(0).attribute),battle_type)
		Checkpoint.put(scratch,data.mini,Checkpoint.MINI_FIELDS)
		scratch.set_running(phase=="battle")
		battle_panel.visible=phase!="ds_scene"
		_sync_ds_battle(ds_current_event if phase=="ds_scene" else {})
		_refresh_battle_scores()
	elif phase=="result" and not data.presentation.is_empty():
		var presentation: Dictionary=data.presentation.duplicate(true)
		presentation["key"]="resume:%d" % match_id
		ds_battle.sync_battle(presentation)
		ds_battle.finish_battle(int(presentation.get("victor",last_battle_result.get("owner",0))),presentation.get("totals",[0,0]))
	phase_text.text=str(data.ui.phase); instruction.text=str(data.ui.instruction)
	result_banner.text=str(data.ui.banner); result_banner.visible=bool(data.ui.banner_visible)
	arena.camera.transform=data.field.camera
	if data.field.get("camera_state") is Dictionary:
		Checkpoint.put(arena,data.field.camera_state,Checkpoint.CAMERA_FIELDS)
	if phase in ["opening","place"]:
		arena.highlight_legal_slots(rules.legal_gate_slots(phase=="opening",0))
	elif phase=="double": arena.highlight_legal_slots(rules.legal_double_destinations(pending_double_slot))
	elif phase=="aim":
		target_marker.visible=true; trajectory.visible=true
		arena._aim_camera=true; arena._aim_sphere=arena.launch_position(0)
		arena._throw_heading=(aim_point-arena._aim_sphere).normalized()
		_sync_ready_ball()
		_trajectory_cache_key.clear()
	overlay.hide(); _refresh_hud(); _update_cards()
	_refresh_s_power()
	if not pending_action.is_empty():
		pending_timer=get_tree().create_timer(maxf(0.01,float(data.timer_remaining)),false)
		_resume_pending_action()
	restoring_match=false
	checkpoint_clock=0.0; checkpoint_phase=phase
	_log("Матч продолжен с сохранённого момента.")

func _update_roster_rotation(delta: float) -> void:
	var direction: float = float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
	var amount: float = direction * delta * 1.5
	if is_zero_approx(direction) and not bool(preferences.reduced_motion):
		amount = delta * 0.22
	_rotate_roster(amount)

func _rotate_roster(amount: float) -> void:
	if not is_finite(amount):
		return
	preview_angle = fposmod(preview_angle + amount, TAU)
	for stand in roster_previews:
		if is_instance_valid(stand):
			stand.rotation.y = preview_angle
			if phase == "model":
				_frame_collection_model(stand)

func _mouse_on_floor() -> Vector3:
	var cam = get_viewport().get_camera_3d()
	var mouse = get_viewport().get_mouse_position()
	var start = cam.project_ray_origin(mouse)
	var normal = cam.project_ray_normal(mouse)
	var hit = Plane(Vector3.UP, 0.13).intersects_ray(start, normal)
	if hit == null:
		return aim_point
	return Vector3(hit.x, 0.0, hit.z)

func _update_aim(delta: float) -> void:
	if rules_profile != "ds" and _mouse_in_arena() and not ds_gesture.active and controls.last_device=="mouse":
		var hit = _mouse_on_floor()
		aim_point = Vector3(clampf(hit.x, -4.2, 4.2), 0, clampf(hit.z, -4.1, 4.1))
	var input: Vector2=controls.movement(preferences)
	if input.length()>0.01:
		var direction: Vector2=arena.control_direction(input)
		var factor: float=arena.throw_scale()
		if rules_profile=="ds":
			var profile: Dictionary=DSProfiles.resolve(rules.teams[0][selected_unit])
			factor*=0.7+float(profile.control)*0.2
		aim_point=arena.clamp_aim(aim_point+Vector3(direction.x,0,direction.y)*delta*4.0*factor*float(preferences.camera_sensitivity))
		if tutorial.active: tutorial.observe("aim")
	target_marker.position = arena.aim_ground_point(aim_point, 0.13)
	target_marker.rotation.y += delta
	if rules_profile=="ds":
		arena.aim_sphere(arena.launch_position(0),aim_point,delta)
	if charging:
		charge = minf(charge + delta * 0.58, 1.0)
	_draw_trajectory()
	power_bar.value = charge * 100.0
	power_label.text = "ОТПУСТИ В ЗЕЛЁНОЙ ЗОНЕ" if charging else "БЫСТРЫЙ ЖЕСТ ВВЕРХ" if rules_profile == "ds" else "УДЕРЖИВАЙ ПРОБЕЛ"
	var nearest: int = _nearest_slot(aim_point, 1.02)
	if nearest >= 0 and rules.gates.has(nearest):
		var unit: Dictionary = rules.teams[0][selected_unit]
		var occupants: Array = rules.gates[nearest].bakugan
		var prediction: String = ""
		if not occupants.is_empty():
			prediction = " · ДВОЙНОЕ ПОПАДАНИЕ" if int(occupants[0].owner) == 0 else " · СОПЕРНИК %d G" % rules.get_standing_power(nearest, 1)
		var known: bool = int(rules.gates[nearest].owner) == 0 or bool(rules.gates[nearest].get("revealed", false))
		var bonus: String = "%s +%d G" % [str(unit.attribute), int(rules.gates[nearest].boosts.get(str(unit.attribute), 0))] if known else "ЗАКРЫТАЯ КАРТА"
		target_text.text = "ВОРОТА %d · %s%s" % [nearest + 1, bonus, prediction]
		arena.highlight_target(nearest)
	else:
		target_text.text = "ЦЕЛЬ МИМО КАРТЫ — НАВЕДИ НА ВОРОТА"
		arena.clear_highlights()

func _mouse_in_arena(screen: Vector2 = Vector2(INF,INF)) -> bool:
	var mouse: Vector2 = hud.get_global_transform_with_canvas().affine_inverse()*screen if screen.is_finite() else hud.get_local_mouse_position()
	return mouse.x > 272 and mouse.x < 1168 and mouse.y > 124 and mouse.y < 636

func _make_aim_visuals() -> void:
	target_marker = MeshInstance3D.new()
	var mesh = TorusMesh.new()
	mesh.inner_radius = 0.38
	mesh.outer_radius = 0.52
	mesh.rings = 24
	mesh.ring_segments = 12
	target_marker.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = ORANGE
	mat.emission_enabled = true
	mat.emission = ORANGE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target_marker.material_override = mat
	add_child(target_marker)
	trajectory = MeshInstance3D.new()
	trajectory.material_override = mat
	add_child(trajectory)

func _draw_trajectory() -> void:
	if rules_profile == "ds":
		_draw_ds_trajectory()
		return
	var preview_charge: float = charge if charging else 0.7
	var signature: Array = [arena.theme_id, aim_point, preview_charge, throw_style, powered_throw, rules.gates.keys()]
	if trajectory.mesh != null and signature == _trajectory_cache_key:
		return
	_trajectory_cache_key = signature
	var line = ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	var start: Vector3 = arena.launch_position(0)
	var target: Vector3 = _throw_target(aim_point, preview_charge)
	var touchdown: Vector3 = _throw_touchdown(start, target)
	for i in range(20):
		var t1: float = float(i) / 20.0
		var t2: float = float(i + 1) / 20.0
		var first: Vector3 = ThrowMotion.flight_position(start, touchdown, t1, throw_style, powered_throw)
		var swept: Dictionary = ThrowMotion.sweep_flight(arena, start, touchdown, t1, t2, throw_style, powered_throw)
		line.surface_add_vertex(first)
		line.surface_add_vertex(swept.position)
		if bool(swept.collided):
			touchdown = swept.position
			break
	# Continue the preview with the same coasting model used after touchdown.
	# Charge and style therefore show their actual ground range, not a full-air
	# arc to a gate which the live sphere never follows.
	var predicted_roll = RollMotion.new()
	arena.configure_roll(predicted_roll)
	var velocity: Vector3 = ThrowMotion.initial_roll_velocity(touchdown, target, preview_charge, throw_style, powered_throw)
	predicted_roll.begin(touchdown, target, velocity.length(), roll_duration)
	for sample in range(40):
		predicted_roll.step(roll_duration / 40.0)
		var gate_hit: int = -1
		for segment: Dictionary in predicted_roll.travel_segments:
			line.surface_add_vertex(segment.from)
			line.surface_add_vertex(segment.to)
			gate_hit = _gate_on_segment(segment.from, segment.to)
			if gate_hit >= 0:
				line.surface_add_vertex(segment.to)
				line.surface_add_vertex(arena.ground_point(arena.slot_position(gate_hit)))
				break
		if gate_hit >= 0 or predicted_roll.is_finished():
			break
	line.surface_end()
	trajectory.mesh = line

func _draw_ds_trajectory() -> void:
	var preview_charge: float = charge if charging else 0.70
	var signature: Array = [arena.theme_id,aim_point,preview_charge,throw_style,powered_throw,s_power[0],selected_unit,match_mode,rules.gates.keys()]
	# Moving geometry changes the path. Limit this expensive forecast to 8 Hz.
	if trajectory.mesh != null and Time.get_ticks_msec()-_ds_preview_time<125:
		return
	_trajectory_cache_key = signature
	_ds_preview_time = Time.get_ticks_msec()
	var predicted = DSSphere.new()
	predicted.configure_field(arena)
	predicted.configure_unit(rules.teams[0][selected_unit])
	predicted.launch(arena.launch_position(0),arena.aim_ground_point(aim_point),preview_charge,throw_style,false,str(rules.teams[0][selected_unit].attribute) if powered_throw and _special_ready(0,selected_unit) else "")
	var line := ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	for index: int in range(150):
		predicted.step(1.0/30.0,arena,Vector2.ZERO,false,false)
		var hit: int = -1
		for segment: Dictionary in predicted.travel_segments:
			line.surface_add_vertex(segment.from)
			line.surface_add_vertex(segment.to)
			hit = _ds_shot_gate_contact(segment.from,segment.to,predicted.special_shot,predicted.velocity.length(),predicted.magnet_margin())
			if hit>=0:
				break
		if hit>=0 or predicted.is_finished():
			break
	line.surface_end()
	trajectory.mesh = line

func _ds_shot_gate_contact(from: Vector3,to: Vector3,shot: String,speed: float,margin: float=0.0,owner: int=0) -> int:
	var slot: int=_gate_on_segment(from,to,margin)
	if shot=="Darkus" and speed>=2.2 and rules.gates.has(slot):
		var occupants: Array=rules.gates[slot].bakugan
		if occupants.size()==1 and int(occupants[0].owner)!=owner: return -1
	return slot

func _update_ds_sphere(delta: float) -> void:
	if not is_instance_valid(flight_ball):
		return
	var steering := Vector2.ZERO
	var braking: bool = false
	if flight_owner == 0:
		steering = controls.movement(preferences)
		steering = arena.control_direction(steering)
		braking = Controls.held("brake",preferences) or controls.pad_held(JOY_BUTTON_B)
	else:
		var direction: Vector3 = roll_target-ds_sphere.position
		steering = Vector2(direction.x,direction.z).limit_length(0.45)
	var previous: Vector3 = ds_sphere.position
	var contacts_before: int = ds_sphere.collision_count
	var impact_speed: float = ds_sphere.velocity.length()
	flight_ball.position = ds_sphere.step(delta,arena,steering,braking)
	if ds_sphere.collision_count>contacts_before and impact_speed>4: _play_sound("SE_GAM_BG_LAND")
	arena.follow_sphere(flight_ball.position,delta,ds_sphere.velocity)
	flight_time = ds_sphere.elapsed
	roll_time = ds_sphere.elapsed
	var movement: Vector3 = flight_ball.position-previous
	flight_ball.rotate_x(movement.z/0.44)
	flight_ball.rotate_z(-movement.x/0.44)
	phase = "rolling" if ds_sphere.grounded else "flying"
	action_button.visible = flight_owner==0
	action_button.text = "ПРЫЖОК · %s / A" % Controls.key_name("action",preferences)
	action_button.disabled = not ds_sphere.can_jump()
	for segment: Dictionary in ds_sphere.travel_segments:
		var hit: int = _ds_shot_gate_contact(segment.from,segment.to,flight_special,float(segment.speed),ds_sphere.magnet_margin(),flight_owner)
		var hit_fraction: float = BoardLayout.gate_contact_fraction(segment.from,segment.to,arena.slot_position(hit),ds_sphere.magnet_margin()) if hit>=0 else 1.0
		for event: Dictionary in segment.get("events",[]):
			if float(event.get("fraction",0.0))>hit_fraction: continue
			if event.kind in ["lava","energy_orb"]:
				field_damage += int(event.damage)
				if int(event.damage) > 0:
					_play_sound("SE_GAM_BG_LAND")
					_log(("Лава: −%d G. Pyrus защищён." if event.kind=="lava" else "Разряд Haos: −%d G. Haos защищён.") % int(event.damage))
			else:
				_play_sound("trampoline" if event.kind=="trampoline" else "speed")
				_log({"trampoline":"Трамплин подбросил сферу.","speed_pad":"Ускоритель разогнал сферу.","water_jet":"Водяная струя подбросила сферу.","wind_jet":"Поток ветра изменил траекторию.","breakable":"Препятствие разрушено." if bool(event.get("destroyed",false)) else "Препятствие отбросило сферу."}.get(str(event.kind),"Контакт с механизмом."))
		var end: Vector3 = segment.to
		if hit >= 0:
			end = segment.from.lerp(segment.to,hit_fraction)
		_collect_pickups(segment.from,end)
		if bool(field_effects.get("restart",false)):
			field_effects.erase("restart")
			roll_bonus=0; field_damage=0
			ds_sphere.launch(flight_start,roll_target,flight_charge,flight_style,false,flight_special)
			flight_ball.position=flight_start; flight_time=0.0; roll_time=0.0
			return
		if hit>=0:
			var occupants: Array = rules.gates[hit].bakugan
			if occupants.size()==1 and int(occupants[0].owner)!=flight_owner and float(segment.speed)>=2.2:
				sphere_collision_slot = hit
			flight_ball.position = arena.ground_point(arena.slot_position(hit))
			_land_ball()
			return
	_refresh_s_power()
	power_bar.value = maxf(0,1.0-ds_sphere.elapsed/ds_sphere.duration)*100
	power_label.text = "СБОР +%d G · УРОН −%d G" % [roll_bonus,field_damage] if field_damage>0 else "СОБРАНО +%d G" % roll_bonus
	target_text.text = "СКОРОСТЬ %.1f · КОРОТКИЙ ЖЕСТ — КОРРЕКЦИЯ" % ds_sphere.velocity.length()
	instruction.text = Controls.hints("Короткий жест / WASD / стик — коррекция · Shift / B — тормоз · Пробел / A — прыжок",preferences) if flight_owner==0 else "Соперник бросает бакугана."
	if ds_sphere.is_finished():
		_land_ball()

func _throw_target(point: Vector3, power: float) -> Vector3:
	if rules_profile == "ds":
		return arena.aim_ground_point(point)
	var safe_power: float = clampf(power, 0.0, 1.0) if is_finite(power) else 0.0
	return arena.ground_point(Vector3(point.x, 0.0, point.z + (0.7 - safe_power) * 3.2))

func _throw_touchdown(start: Vector3, target: Vector3) -> Vector3:
	var touchdown: Vector3 = start.lerp(target, 0.34)
	return arena.ground_point(touchdown)

func _current_flight_duration() -> float:
	var base_duration: float = flight_duration if is_finite(flight_duration) and flight_duration > 0.0 else 1.55
	return base_duration * ThrowMotion.flight_duration(flight_style, flight_powered) / ThrowMotion.flight_duration("lob")

func _attach_special_aura() -> void:
	if not is_instance_valid(flight_ball) or flight_special.is_empty(): return
	var aura:=MeshInstance3D.new(); var mesh:=SphereMesh.new()
	mesh.radius=0.53; mesh.height=1.06; mesh.radial_segments=20; mesh.rings=10; aura.mesh=mesh
	var material:=StandardMaterial3D.new(); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color={"Pyrus":Color(1,0.2,0.05,0.23),"Aquos":Color(0.1,0.7,1,0.23),"Subterra":Color(0.8,0.6,0.2,0.23),"Haos":Color(1,0.95,0.6,0.23),"Darkus":Color(0.6,0.2,1,0.15),"Ventus":Color(0.2,1,0.6,0.23)}.get(flight_special,Color.WHITE)
	aura.material_override=material; aura.name="SpecialAura"; flight_ball.add_child(aura)

func _launch_ball(owner: int, unit_index: int, endpoint: Vector3) -> void:
	if owner==0 and is_instance_valid(tutorial):
		if not tutorial.permits_throw(): return
		tutorial.observe("throw")
	if not rules.available_units(owner).has(unit_index):
		return
	phase = "flying"
	charging = false
	flight_owner = owner
	flight_unit = unit_index
	flight_powered = powered_throw if owner == 0 else rng.randf() < 0.35
	if rules_profile=="ds":
		flight_powered = (powered_throw if owner==0 else true) and _special_ready(owner,unit_index)
		flight_special = str(rules.teams[owner][unit_index].attribute) if flight_powered else ""
		field_effects = FieldCards.initial()
		if flight_powered:
			s_power[owner] -= 100
		powered_throw = false
		_refresh_s_power()
	flight_style = ThrowMotion.normalize_style(throw_style) if owner == 0 else str(ai_choice.get("style",("straight" if rng.randf() < 0.5 else "lob")))
	flight_charge = clampf(charge, 0.0, 1.0) if is_finite(charge) else 0.0
	sphere_collision_slot = -1
	flight_start = arena.launch_position(owner)
	roll_target = arena.aim_ground_point(endpoint) if rules_profile=="ds" else arena.ground_point(endpoint)
	flight_end = _throw_touchdown(flight_start, roll_target)
	flight_time = 0.0
	flight_steer = Vector3.ZERO
	roll_bonus = 0
	field_damage = 0
	roll_time = 0.0
	_clear_pickups()
	flight_ball = arena.make_ball(str(rules.teams[owner][unit_index].attribute), owner, str(rules.teams[owner][unit_index].name))
	flight_ball.position = flight_start
	if rules_profile == "ds":
		ds_sphere.configure_field(arena)
		ds_sphere.configure_unit(rules.teams[owner][flight_unit])
		ds_sphere.launch(flight_start,roll_target,flight_charge,flight_style,false,flight_special)
		_attach_special_aura()
		ds_gesture.cancel()
		_spawn_pickups()
	target_marker.visible = false
	trajectory.visible = false
	arena.clear_highlights()
	phase_text.text = "%s — В БОЙ!" % str(rules.teams[owner][unit_index].name).to_upper()
	instruction.text = "%s · WASD или стрелки — корректируй полёт." % (last_throw_quality if not last_throw_quality.is_empty() else "БАКУГАН В ВОЗДУХЕ") if owner == 0 else "Соперник бросает бакугана."
	audio.set_speaker(str(preferences.avatar) if owner==0 else str(enemy_avatar.avatar_id),rules.teams[owner][unit_index])
	audio.event("throw")
	_update_cards()

func _update_flight(delta: float) -> void:
	if rules_profile == "ds":
		_update_ds_sphere(delta)
		return
	var previous_progress: float = minf(flight_time / _current_flight_duration(), 1.0)
	flight_time += delta
	var t: float = minf(flight_time / _current_flight_duration(), 1.0)
	if flight_owner == 0:
		var movement: Vector2=controls.movement(preferences)
		var x: float=movement.x
		var z: float=movement.y
		var camera_control: Vector2 = arena.control_direction(Vector2(x, z))
		flight_steer += Vector3(camera_control.x, 0.0, camera_control.y) * delta * 1.7
		flight_steer.x = clampf(flight_steer.x, -1.3, 1.3)
		flight_steer.z = clampf(flight_steer.z, -1.3, 1.3)
	var collided: bool = false
	if is_instance_valid(flight_ball):
		var swept: Dictionary = ThrowMotion.sweep_flight(arena, flight_start, flight_end + flight_steer, previous_progress, t, flight_style, flight_powered)
		flight_ball.position = swept.position
		collided = bool(swept.collided)
		flight_ball.rotate_x(delta * 7.0)
		flight_ball.rotate_z(delta * (2.0 if flight_owner == 0 else -2.0))
	if t >= 1.0 or collided:
		_begin_roll()

func _begin_roll() -> void:
	if not is_instance_valid(flight_ball):
		return
	phase = "rolling"
	roll_time = 0.0
	var velocity: Vector3 = ThrowMotion.initial_roll_velocity(flight_ball.position, roll_target + flight_steer, flight_charge, flight_style, flight_powered)
	arena.configure_roll(roll_motion)
	roll_motion.begin(flight_ball.position, roll_target + flight_steer, velocity.length(), roll_duration)
	flight_ball.position = roll_motion.position
	_spawn_pickups()
	phase_text.text = "СОБЕРИ G-POWER — ПОПАДИ НА КАРТУ!" if flight_owner == 0 else "БАКУГАН СОПЕРНИКА НА ПОЛЕ"
	instruction.text = "WASD / стрелки — катание · SHIFT — тормоз · ПРОБЕЛ — остановка · Кристалл: +20 G" if flight_owner == 0 else "Соперник собирает энергию и катится к воротам."
	_update_cards()

func _spawn_pickups() -> void:
	_clear_pickups()
	if rules_profile=="ds" and is_instance_valid(arena.field_objects):
		pickups = arena.field_objects.available_pickups()
		for item: Dictionary in pickups:
			item["amount"] = 20 if item.kind=="g_power" else 25 if item.kind=="s_power" else 5 if item.kind=="experience" else 10
		return
	var start: Vector3 = ds_sphere.position if rules_profile == "ds" else roll_motion.position
	var direction: Vector3 = roll_target - start
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3.FORWARD
	var side: Vector3 = Vector3(-direction.z, 0.0, direction.x).normalized()
	var positions: Array[Vector3] = []
	for fraction in [0.2, 0.4, 0.62]:
		positions.append(start.lerp(roll_target, float(fraction)))
	var middle: Vector3 = start.lerp(roll_target, 0.42)
	positions.append(middle + side * 1.45)
	positions.append(middle - side * 1.45)
	positions.append(start.lerp(roll_target, 0.7) + side * 1.2)
	for point in positions:
		point = arena.ground_point(Vector3(clampf(point.x, -4.8, 4.8), 0.0, clampf(point.z, -4.5, 4.5)), 0.18)
		var on_gate: bool = false
		for slot in rules.gates.keys():
			if point.distance_to(arena.slot_position(int(slot))) < 0.98:
				on_gate = true
				break
		if on_gate:
			continue
		var node: Node3D = arena.make_pickup(point, 20)
		pickups.append({"position": point, "amount": 20, "node": node, "collected": false})

func _update_roll(delta: float) -> void:
	if rules_profile == "ds":
		_update_ds_sphere(delta)
		return
	if not is_instance_valid(flight_ball):
		return
	var previous: Vector3 = roll_motion.position
	var steering = Vector2.ZERO
	var braking: bool = false
	if flight_owner == 0:
		steering=controls.movement(preferences)
		braking=Controls.held("brake",preferences) or controls.pad_held(JOY_BUTTON_B)
	if flight_owner == 0:
		steering = arena.control_direction(steering)
	var current: Vector3 = roll_motion.step(delta, steering, braking)
	roll_time = roll_motion.elapsed
	flight_ball.position = current
	var movement: Vector3 = current - previous
	flight_ball.rotate_x(movement.z / 0.44)
	flight_ball.rotate_z(-movement.x / 0.44)
	var gate_hit: int = -1
	var hit_from: Vector3 = previous
	for segment: Dictionary in roll_motion.travel_segments:
		gate_hit = _gate_on_segment(segment.from, segment.to)
		if gate_hit >= 0:
			hit_from = segment.from
			break
		_collect_pickups(segment.from, segment.to)
	if gate_hit >= 0:
		var occupants: Array = rules.gates[gate_hit].bakugan
		if occupants.size() == 1 and int(occupants[0].owner) != flight_owner and roll_motion.velocity.length() >= 2.2:
			var defender_key: String = _unit_key(int(occupants[0].owner), int(occupants[0].index))
			# The landing controller moves the ball from the card edge to its
			# final centre. Check that complete impact path, before snapping it.
			if unit_nodes.has(defender_key) and RollMotion.segment_distance(unit_nodes[defender_key].position, hit_from, arena.slot_position(gate_hit)) <= 0.58:
				sphere_collision_slot = gate_hit
		flight_ball.position = arena.ground_point(arena.slot_position(gate_hit))
		_collect_pickups(hit_from, flight_ball.position)
		_land_ball()
		return
	power_bar.value = maxf(0.0, 1.0 - roll_time / roll_duration) * 100.0
	power_label.text = "%s +%d G" % ["СОБРАНО" if flight_owner == 0 else "СОПЕРНИК СОБРАЛ", roll_bonus]
	target_text.text = "КАТАНИЕ: %.1f С   ·   МАКСИМУМ +120 G" % maxf(0.0, roll_duration - roll_time)
	if roll_motion.is_finished():
		_land_ball()

func _gate_on_segment(from: Vector3, to: Vector3, magnet: float = -1.0) -> int:
	var first_slot: int = -1
	var first_fraction: float = INF
	var margin: float = ds_sphere.magnet_margin() if rules_profile=="ds" and magnet<0 else maxf(0.0,magnet)
	for value: Variant in rules.gates:
		var fraction: float = BoardLayout.gate_contact_fraction(from,to,arena.slot_position(int(value)),margin,rules_profile)
		if fraction < first_fraction:
			first_fraction = fraction
			first_slot = int(value)
	return first_slot

func _collect_pickups(from: Vector3, to: Vector3) -> void:
	if phase not in ["rolling","flying"] or paused:
		return
	for pickup in pickups:
		var distance: float = pickup.position.distance_to(Geometry3D.get_closest_point_to_segment(pickup.position,from,to)) if rules_profile == "ds" else RollMotion.segment_distance(pickup.position,from,to)
		if bool(pickup.collected) or distance > float(pickup.get("radius",0.64)):
			continue
		pickup.collected = true
		var previous_bonus: int = roll_bonus
		if rules_profile=="ds" and str(pickup.get("kind",""))=="field_card":
			_activate_field_card(FieldCards.IDS[rng.randi_range(0,FieldCards.IDS.size()-1)])
		elif rules_profile=="ds" and str(pickup.get("kind","g_power"))=="experience":
			if flight_owner==0:
				experience_gained+=int(pickup.amount)
				_log("Опыт: +%d очков развития%s." % [int(pickup.amount)," после матча" if match_mode=="campaign" else " · развитие доступно в кампании"])
			_play_sound("s_pickup")
		elif rules_profile=="ds" and str(pickup.get("kind","g_power")) in ["s_power","s_power_small"]:
			s_power[flight_owner] = mini(100,s_power[flight_owner]+maxi(0,int(pickup.amount)))
			_refresh_s_power()
			_play_sound("s_pickup")
		else:
			roll_bonus = mini(120, roll_bonus + maxi(0, int(pickup.amount)))
		if bool(pickup.get("native",false)) and is_instance_valid(arena.field_objects):
			arena.field_objects.collect(int(pickup.id))
		elif is_instance_valid(pickup.node):
			pickup.node.queue_free()
		if roll_bonus > previous_bonus:
			_play_sound("g_pickup")

func _clear_pickups() -> void:
	for pickup in pickups:
		if not bool(pickup.get("native",false)) and is_instance_valid(pickup.node):
			pickup.node.queue_free()
	pickups.clear()

func _nearest_slot(point: Vector3, radius: float) -> int:
	var best: int = -1
	var distance: float = radius
	for i in range(arena.slot_count()):
		var p: Vector3 = arena.slot_position(i)
		var d: float = Vector2(point.x - p.x, point.z - p.z).length()
		if d < distance:
			distance = d
			best = i
	return best

func _land_ball() -> void:
	if not is_instance_valid(flight_ball):
		return
	arena.restore_board_view()
	var slot: int = _gate_on_segment(flight_ball.position,flight_ball.position) if rules_profile == "ds" else _nearest_slot(flight_ball.position, 0.85)
	var ball: Node3D = flight_ball
	flight_ball = null
	_clear_pickups()
	ball.queue_free()
	if rules_profile=="ds":
		slot = _field_card_landing_slot(slot)
		if _special_landing(slot): return
	if flight_powered and (rules_profile!="ds" or flight_special in ["","Pyrus"]) and sphere_collision_slot == slot and rules.gates.has(slot):
		var occupants: Array = rules.gates[slot].bakugan
		if occupants.size() == 1 and int(occupants[0].owner) != flight_owner:
			# The mechanic is Wii-derived; this damage curve is PC prototype balance.
			var damage: int = roundi(160.0 + flight_charge * 140.0 + float(int(rules.teams[flight_owner][flight_unit].g) - int(occupants[0].g)) * 0.15)
			if rules_profile=="ds":
				var defense: Dictionary = DSProfiles.resolve(occupants[0])
				damage = roundi(float(damage)/(0.8+float(defense.defense)*0.2))
			var attack: Dictionary = rules.apply_sphere_attack(flight_owner, slot, maxi(1, damage))
			_log("Sphere Attack: −%d G." % int(attack.get("damage", 0)))
			if str(attack.get("event", "")) == "critical_ko":
				rules.consume_throw(flight_owner, flight_unit, true)
				match_stats.record_throw(flight_owner, true, 0)
				_complete_capture(slot, flight_owner, false, "CRITICAL K.O.!")
				return
	var event: Dictionary = rules.land(flight_owner, flight_unit, slot, roll_bonus,field_damage if rules_profile=="ds" else 0,field_effects if rules_profile=="ds" else {})
	match_stats.record_throw(flight_owner, str(event.event) in ["stand", "battle", "double_stand", "double_choice"], roll_bonus)
	if str(event.event) in ["miss", "invalid"]:
		_log("%s промахнулся: собранный G потерян." % ("Ты" if flight_owner == 0 else "Соперник"))
		_play_sound("miss")
		_announce_then_advance("МИМО КАРТЫ", MUTED)
		return
	if rules_profile=="ds" and field_effects.get("early",false) and str(event.event)!="invalid":
		_complete_capture(slot,flight_owner,false,"EARLY VICTORY!")
		return
	_sync_units()
	if roll_bonus > 0:
		_log("%s сохранил +%d G." % [str(rules.teams[flight_owner][flight_unit].name), roll_bonus])
	arena.landing_flash(arena.slot_position(slot), ORANGE if flight_owner == 0 else CYAN)
	audio.event("land")
	_handle_landing_event(event, slot, flight_owner)

func _handle_landing_event(event: Dictionary, slot: int, owner: int) -> void:
	match str(event.get("event", "invalid")):
		"battle":
			_begin_battle(slot)
		"double_choice":
			pending_double_slot = slot
			if owner == 1:
				_resolve_double(-1)
			else:
				phase = "double"
				phase_text.text = "ДВОЙНОЕ ПОПАДАНИЕ — ТВОЙ ВЫБОР"
				instruction.text = "ПРОБЕЛ — забрать карту. Или нажми на соседние ворота, чтобы переместить последнего бакугана."
				arena.highlight_legal_slots(rules.legal_double_destinations(slot))
				_update_cards()
		"double_stand":
			_complete_capture(slot, owner, true, "ДВОЙНОЕ ПОПАДАНИЕ!")
		_:
			_log("Бакуган стоит на воротах %d." % (slot + 1))
			_announce_then_advance("БАКУГАН НА КАРТЕ", ORANGE if owner == 0 else CYAN)

func _resolve_double(destination: int = -1) -> void:
	if pending_double_slot < 0 or paused:
		return
	var source: int = pending_double_slot
	var owner: int = int(rules.gates[source].bakugan[-1].owner) if rules.gates.has(source) else flight_owner
	var event: Dictionary = rules.resolve_double(source, destination)
	if str(event.get("event", "invalid")) == "invalid":
		return
	pending_double_slot = -1
	arena.clear_highlights()
	_sync_units()
	_handle_landing_event(event, int(event.get("slot", source)), owner)

func _complete_capture(slot: int, owner: int, double_stand: bool, banner: String) -> void:
	match_stats.record_capture(owner, double_stand)
	arena.capture_effect(arena.slot_position(slot), ORANGE if owner == 0 else CYAN)
	arena.remove_gate(slot)
	_sync_units()
	_refresh_hud()
	_log("%s забирает ворота %d." % ["Ты" if owner == 0 else "Соперник", slot + 1])
	_announce_then_advance(banner, ORANGE if owner == 0 else CYAN)

func _unit_key(owner: int, index: int) -> String:
	return "%d:%d" % [owner, index]

func _sync_units() -> void:
	var keep: Dictionary = {}
	for slot in rules.gates:
		var occupants: Array = rules.gates[slot].bakugan
		for occupant_index in range(occupants.size()):
			var unit: Dictionary = occupants[occupant_index]
			var key: String = _unit_key(int(unit.owner), int(unit.index))
			keep[key] = true
			if not unit_nodes.has(key):
				var stand: Node3D = Node3D.new()
				arena.add_child(stand)
				var creature: Node3D = arena.make_creature(str(unit.name), str(unit.attribute))
				creature.reparent(stand, false)
				# DoC toy scale already comes from its closed sphere. Applying
				# the legacy decorative-board scale would shrink it on landing.
				var paired_doc_toy: bool = str(creature.get_meta("source", {}).get("origin", "")) == "user_doc_nitrofs" and not bool(creature.get_meta("missing_toy_fallback", false))
				stand.scale = Vector3.ONE * (1.0 if paired_doc_toy else 0.43)
				unit_nodes[key] = stand
			var offset: float = (-0.32 if occupant_index == 0 else 0.32) if occupants.size() == 2 else (-0.32 if int(unit.owner) == 0 else 0.32)
			unit_nodes[key].position = arena.slot_position(int(slot)) + Vector3(offset, 0.13, 0)
	for key in unit_nodes.keys():
		if not keep.has(key):
			if is_instance_valid(unit_nodes[key]):
				unit_nodes[key].queue_free()
			unit_nodes.erase(key)

func _announce_then_advance(text: String, color: Color) -> void:
	phase = "result"
	var generation: int = match_id
	result_banner.text = text
	result_banner.add_theme_color_override("font_color", color)
	result_banner.visible = not ds_battle.is_presenting()
	# Let the native DS result frames finish before returning to the board.
	pending_action="advance"
	pending_timer=get_tree().create_timer(2.85 if rules_profile=="ds" and ds_battle.is_presenting() else 1.65 if ds_battle.is_presenting() else 1.1, false)
	await pending_timer.timeout
	if generation != match_id:
		return
	pending_timer=null; pending_action=""
	result_banner.visible = false
	_advance_turn()

func _advance_turn() -> void:
	if rules.winner >= 0:
		_end_match()
		return
	if extra_throw_owner==rules.turn and not rules.available_units(rules.turn).is_empty():
		extra_throw_owner=-1
		rules.turn_action_taken=false
		_log("Another Throw: дополнительный бросок.")
		if rules.turn==0:
			selected_unit=int(rules.available_units(0)[0]); _begin_aim()
		else: _ai_turn()
		return
	extra_throw_owner=-1
	if not rules.finish_turn():
		return
	ds_battle.reset()
	_refresh_hud()
	if rules.turn == 1:
		_ai_turn()
	else:
		_begin_player_turn()

func _ai_turn() -> void:
	phase = "ai"
	pending_action="ai_choose"
	pending_timer=get_tree().create_timer(0.65,false)
	_resume_pending_action()

func _resume_pending_action() -> void:
	var generation: int = match_id
	if pending_action.begins_with("ai"):
		phase_text.text = "ХОД СОПЕРНИКА"
		instruction.text = "Соперник выбирает ворота и бакугана."
		_update_cards()
	if pending_timer!=null: await pending_timer.timeout
	if generation != match_id:
		return
	var action: String=pending_action
	pending_timer=null; pending_action=""
	if action=="advance":
		result_banner.hide(); _advance_turn(); return
	if action=="ai_throw":
		charge=float(ai_choice.get("power",0.7))
		var jitter: Vector3=Vector3(rng.randf_range(-0.12,0.12),0,rng.randf_range(-0.12,0.12))
		if enemy_tactic=="precision": jitter*=0.25
		if tutorial.active: jitter=Vector3.ZERO
		_launch_ball(1,int(ai_choice.unit),arena.slot_position(int(ai_choice.slot))+jitter)
		return
	if action!="ai_choose" or not _prepare_turn(1): return
	if rules.gates.is_empty():
		_begin_opening()
		return
	var free: Array[int] = rules.legal_gate_slots()
	# Placement is optional: keep a gate for later when a good target exists.
	if rules.can_place_gate(1) and not free.is_empty() and (rng.randf() < 0.55 or rules.gates.size() < 2):
		var gate_index: int = TacticalAI.choose_gate(rules, 1)
		var slot: int = free[rng.randi_range(0, free.size() - 1)]
		if gate_index >= 0 and rules.place_gate(1, gate_index, slot):
			_draw_gate(slot)
			_log("Соперник добавляет закрытые ворота %d." % (slot + 1))
	ai_choice = TacticalAI.choose_throw(rules, 1, enemy_tactic)
	if ai_choice.is_empty():
		_advance_turn()
		return
	if tutorial.active and rules_profile=="ds": ai_choice=_lesson_throw_plan(ai_choice)
	_refresh_hud()
	pending_action="ai_throw"
	pending_timer=get_tree().create_timer(0.5,false)
	_resume_pending_action()

func _lesson_throw_plan(choice: Dictionary) -> Dictionary:
	# Test real motion without collecting/destroying field objects. The live
	# sphere still handles all contacts and can fail; there is no forced land.
	var slot: int=int(choice.slot)
	var unit: Dictionary=rules.teams[1][int(choice.unit)]
	var target: Vector3=arena.aim_ground_point(arena.slot_position(slot))
	for style: String in ["straight","lob"]:
		for fraction: float in [0.7,0.5,0.9,0.3,1.0]:
			var motion=DSSphere.new()
			motion.configure_field(arena); motion.configure_unit(unit)
			motion.launch(arena.launch_position(1),target,fraction,style,false)
			for sample: int in 150:
				var direction: Vector3=target-motion.position
				motion.step(1.0/30.0,arena,Vector2(direction.x,direction.z).limit_length(0.45),false,false)
				var hit: int=-1
				for segment: Dictionary in motion.travel_segments:
					hit=_gate_on_segment(segment.from,segment.to,motion.magnet_margin())
					if hit>=0: break
				if hit==slot:
					var planned: Dictionary=choice.duplicate()
					planned.power=fraction; planned.style=style
					return planned
				if hit>=0 or motion.is_finished(): break
	return choice

func _begin_battle(slot: int) -> void:
	audio.set_context("battle")
	phase = "battle_ready"
	battle_slot = slot
	battle_time = 0.0
	battle_points = 0
	ability_points = 0
	ai_points = 0
	battle_effects.reset()
	ai_target_points = rng.randi_range(enemy_power_range.x, enemy_power_range.y)
	ai_ability_used = false
	used_battle_abilities = false
	hit_cooldown = 0.0
	last_shake_key = 0
	feedback_time = 0.0
	battle_feedback.text = ""
	arena.clear_highlights()
	var gate: Dictionary = rules.gates[slot]
	battle_type = rules.minigame_type(slot)
	ds_sequence.clear()
	ds_sequence_stage = ""
	ds_selected_ability = ""
	ds_selected_chain.clear()
	ds_ai_ability = ""
	ds_ai_opportunities=0; ds_enemy_progress=0.0; ds_skip_pending=false
	if rules_profile=="ds":
		battle_type = practice_kind if match_mode=="practice" and DSMiniCatalog.MODES.has(practice_kind) else DSMiniCatalog.choose("scratch" if tutorial.active else str(preferences.ds_minigame),int(rules.scores[0])+int(rules.scores[1]))
		if field_effects.get("surprise",false):
			battle_type=DSMiniCatalog.MODES[rng.randi_range(0,DSMiniCatalog.MODES.size()-1)]
			_log("Surprise Attack: случайная мини-игра "+battle_type+".")
		battle_duration = 10.0
	else:
		battle_duration = 8.0
	battle_level = clampi(maxi(int(rules.scores[0]), int(rules.scores[1])) + 1, 1, 3)
	battle_streak = 0
	bonus_mode = false
	timing_sequence = 0
	timing_window_active = false
	timing_window_hit = false
	circle_sequence = 0
	_clear_dragons()
	for node in unit_nodes.values():
		if is_instance_valid(node):
			node.visible = false
	_draw_gate(slot, true)
	phase_text.text = "ВОРОТА ОТКРЫТЫ"
	instruction.text = "Прочитай эффект ворот, сыграй подходящие способности 1–3. ПРОБЕЛ или ENTER — начать миниигру."
	_configure_minigame()
	battle_panel.visible = true
	_log("Открыты ворота %s: %s" % [str(gate.title), str(gate.description)])
	_update_cards()
	_refresh_battle_scores()
	_sync_ds_battle({"event": "gate_opened"})
	if rules_profile=="ds":
		scratch.configure(str(_battle_unit(0).attribute),battle_type)
		_start_ds_sequence([
			{"stage":"battle_banner","event":"battle","title":"БАКУГАНЫ — В БОЙ!","duration":0.7},
			{"stage":"entry_player","event":"entry","owner":0,"duration":0.8},
			{"stage":"entry_enemy","event":"entry","owner":1,"duration":0.8},
			{"stage":"gate_reveal","event":"gate_scene","source_key":str(gate.get("source_key","")),"title":str(gate.title),"description":str(gate.description),"duration":1.5},
		],"battle_ready")

func _start_ds_sequence(steps: Array, resume: String) -> void:
	ds_sequence.assign(steps)
	ds_sequence_time = 0.0
	ds_resume_phase = resume
	phase = "ds_scene"
	scratch.set_running(false)
	scratch.visible = false
	battle_panel.visible = false
	_update_cards()
	_step_ds_sequence(0.0)

func _step_ds_sequence(delta: float) -> void:
	ds_sequence_time -= maxf(0.0,delta)
	if ds_sequence_time>0.0: return
	if not ds_sequence.is_empty():
		var event: Dictionary = ds_sequence.pop_front()
		ds_current_event=event.duplicate(true)
		ds_sequence_stage = str(event.stage)
		phase_text.text = {"battle_banner":"БАКУГАНЫ — В БОЙ!","entry_player":"ТВОЙ БАКУГАН","entry_enemy":"БАКУГАН СОПЕРНИКА","gate_reveal":"РАСКРЫТИЕ ВОРОТ","countdown":"ПРИГОТОВЬСЯ","ability":"СПОСОБНОСТЬ АКТИВИРОВАНА"}.get(ds_sequence_stage,"БОЙ")
		instruction.text = "Выбери способность после раскрытия ворот." if ds_resume_phase=="battle_ready" else "Мини-игра продолжится после этой сцены."
		ds_sequence_time = float(event.duration)*(0.20 if bool(preferences.reduced_motion) else 1.0)
		_sync_ds_battle(event)
		return
	ds_sequence_stage = ""
	phase = ds_resume_phase
	phase_text.text = "ВОРОТА ОТКРЫТЫ" if phase=="battle_ready" else str(DSMiniCatalog.NAMES[battle_type])
	if phase=="battle" and ds_skip_pending:
		ds_skip_pending=false
		_finish_battle()
		return
	battle_panel.visible = true
	scratch.set_running(phase=="battle")
	_configure_minigame()
	_update_cards()
	_sync_ds_battle()
	instruction.text = "1–3 — добавить/убрать карту в цепи. Активируй по очереди во время боя; Backspace — пропустить. ПРОБЕЛ — начать." if phase=="battle_ready" else str(DSMiniCatalog.HINTS.get(battle_type,""))+" 1–3 — следующая карта; Backspace — пропустить."

func _ability_index(owner: int, identity: String) -> int:
	for index: int in rules.abilities[owner].size():
		if str(rules.abilities[owner][index].id)==identity: return index
	return -1

func _start_battle_game() -> void:
	if tutorial.active and not tutorial.permits_battle(): return
	controls.virtual_active=false
	if phase != "battle_ready" or paused:
		return
	audio.event("battle")
	if rules_profile=="ds":
		var choice: int = TacticalAI.choose_ability(rules.abilities[1],1,battle_effects,ai_target_points,battle_points,_battle_unit(1),_battle_unit(0),battle_type,true,_battle_card_context(1))
		ds_ai_ability = str(rules.abilities[1][choice].id) if choice>=0 else ""
		ds_ai_ability_at = battle_duration*float({"offense":0.15,"pressure":0.20,"control":0.45,"precision":0.35,"counter":0.60}.get(enemy_tactic,0.30))
		_start_ds_sequence([
			{"stage":"countdown","event":"countdown","title":"3","duration":0.45},
			{"stage":"countdown","event":"countdown","title":"2","duration":0.45},
			{"stage":"countdown","event":"countdown","title":"1","duration":0.45},
		],"battle")
		return
	# Each remaining card can be considered once, with its printed conditions.
	for opportunity in range(3):
		if rules.gate_effect(battle_slot).get("type", "") == "no_abilities":
			break
		var index: int = TacticalAI.choose_ability(rules.abilities[1], 1, battle_effects, ai_target_points, battle_points, _battle_unit(1), _battle_unit(0), battle_type, true, _battle_card_context(1))
		if match_mode == "practice" and index >= 0 and str(rules.abilities[1][index].type) == "battle_type":
			break
		if index < 0 or not _play_ability(1, index):
			break
	phase = "battle"
	_configure_minigame()
	phase_text.text = "БОЙ · УРОВЕНЬ %d" % battle_level
	instruction.text = "Способности с бонусом G доступны и во время боя, если выполняются их условия."
	_update_cards()
	_update_battle(0.0)
	_sync_ds_battle({"event": "battle_started"})

func _configure_minigame() -> void:
	battle_title.text = "%s · УРОВЕНЬ %d" % [{"timing": "БОЙ НА ТОЧНОСТЬ", "shooting": "БОЙ НА МЕТКОСТЬ", "shaking": "БОЙ НА СКОРОСТЬ", "scratch":"SCRATCH — ТРИ СИМВОЛ"}.get(battle_type,"БОЙ"), battle_level]
	if rules_profile=="ds": battle_title.text=str(DSMiniCatalog.NAMES[battle_type])+" · УРОВЕНЬ %d" % battle_level
	scratch.visible = rules_profile=="ds" and phase in ["battle_ready","battle"]
	battle_panel.size.y = 340 if rules_profile=="ds" else 258
	battle_panel.position.y = 350 if rules_profile=="ds" else 432
	battle_progress.position.y = 334 if rules_profile=="ds" else 252
	battle_feedback.position.y = 313 if rules_profile=="ds" else 229
	var gate: Dictionary = rules.gates[battle_slot]
	battle_hint.text = "%s: %s" % [str(gate.title), str(gate.description)]
	timing_track.position.y=181
	for target: Button in shooting_targets: target.position.y=181
	timing_track.visible = phase == "battle" and battle_type == "timing" and rules_profile!="ds"
	for target in shooting_targets:
		target.visible = phase == "battle" and battle_type == "shooting"
	if battle_type == "shooting":
		_move_shooting_target()
	battle_progress.value = 100

func _battle_base(owner: int) -> int:
	return rules.get_standing_power(battle_slot, owner)

func _battle_stage_position(owner: int) -> Vector3:
	return _screen_stage_position(0.4 if owner == 0 else 0.65, 0.69)

func _screen_stage_position(x_fraction: float, y_fraction: float) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var screen = Vector2(viewport_size.x * x_fraction, viewport_size.y * y_fraction)
	var hit = Plane(Vector3.UP, 0.13).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit != null:
		return hit
	return Vector3((x_fraction - 0.5) * 12.0, 0.13, 3.4)

func _update_battle(delta: float) -> void:
	if rules_profile=="ds":
		_update_ds_minigame(delta)
		return
	battle_time += delta
	feedback_time = maxf(0.0, feedback_time - delta)
	battle_feedback.modulate.a = 1.0 if bool(preferences.reduced_motion) and feedback_time > 0.0 else clampf(feedback_time * 2.0, 0.0, 1.0)
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	rhythm_phase = (sin(battle_time * (5.8 + float(battle_level - 1) * 1.2) - PI / 2) + 1.0) / 2.0
	if battle_type == "timing":
		_update_timing_window(rhythm_phase >= 0.415 and rhythm_phase <= 0.6)
	timing_cursor.position.x = rhythm_phase * 607.0
	battle_progress.value = (1.0 - battle_time / battle_duration) * 100.0
	var combo: String = " · БОНУС ×2" if bonus_mode else " · серия %d/5" % battle_streak
	if battle_type == "timing":
		var keys: PackedStringArray = []
		for key in _timing_keys():
			keys.append(Controls.key_name(str({KEY_SPACE:"action",KEY_A:"left",KEY_D:"right",KEY_W:"up",KEY_S:"down"}.get(key,"action")),preferences)+" / "+str({KEY_SPACE:"A",KEY_A:"LB",KEY_D:"RB",KEY_W:"D-pad ↑",KEY_S:"D-pad ↓"}.get(key,"A")))
		battle_hint.text = "В зелёной зоне: %s%s\nПять правильных нажатий включают бонус до первой ошибки." % [" + ".join(keys), combo]
	elif battle_type == "shooting":
		battle_hint.text = "Твоя стихия: %s%s\nЧужая стихия сбрасывает серию. Золотая цель усиливает видимые стихии." % [str(_battle_unit(0).get("attribute", "")), combo]
		if not bool(preferences.reduced_motion):
			for index in range(shooting_targets.size()):
				if index < shooting_positions.size():
					shooting_targets[index].position = shooting_positions[index] + Vector2(sin(battle_time * 2.0 + index) * 24.0, sin(battle_time * 3.0 + index) * 3.0)
	elif battle_type=="shaking":
		battle_hint.text = "STOP — НЕ НАЖИМАЙ: ошибка отнимает G" if _shaking_stop() else {"horizontal": "Чередуй A и D", "vertical": "Чередуй W и S", "circle": "По кругу: W → D → S → A"}[_shaking_movement()]
	else:
		battle_hint.text = "Удерживай левую кнопку и быстро три знак стихии. Неподвижный курсор не даёт силы."
	_refresh_battle_scores()
	if battle_time >= battle_duration:
		_finish_battle()

func _update_ds_minigame(delta: float) -> void:
	if phase!="battle" or paused or not is_finite(delta) or delta<=0.0: return
	controls.move_pointer(scratch,preferences,delta)
	delta=minf(delta,maxf(0.0,battle_duration-battle_time))
	battle_time+=delta
	var block: float = float(battle_effects.states[1].input_block)
	var active: float = maxf(0.0,delta-block)
	battle_effects.states[1].input_block=maxf(0.0,block-delta)
	ds_enemy_progress=minf(DSScratch.MAX_POINTS,ds_enemy_progress+float(ai_target_points)/maxf(battle_duration,0.001)*active*float(battle_effects.states[1].input_multiplier))
	var previous_mini: int=battle_points
	battle_points=scratch.step(delta)
	ds_mini_sound_clock=maxf(0.0,ds_mini_sound_clock-delta)
	if battle_points>previous_mini and ds_mini_sound_clock<=0.0:
		_play_sound("hit"); ds_mini_sound_clock=0.2
	battle_effects.states[0].input_block=scratch.blocked
	if not ds_ai_ability.is_empty() and battle_time>=ds_ai_ability_at:
		var index: int = _ability_index(1,ds_ai_ability)
		ds_ai_ability=""
		ds_ai_opportunities+=1
		var played: bool = index>=0 and _play_ability(1,index)
		if ds_ai_opportunities<3 and not ds_skip_pending:
			var next: int = TacticalAI.choose_ability(rules.abilities[1],1,battle_effects,int(ds_enemy_progress),battle_points,_battle_unit(1),_battle_unit(0),battle_type,false,_battle_card_context(1))
			if next>=0: ds_ai_ability=str(rules.abilities[1][next].id)
			ds_ai_ability_at=battle_time+battle_duration*0.25
		if played: return
	battle_progress.value=maxf(0.0,1.0-battle_time/battle_duration)*100.0
	var chain: PackedStringArray = []
	for identity: String in ds_selected_chain:
		var index: int = _ability_index(0,identity)
		if index>=0: chain.append(str(rules.abilities[0][index].title))
	battle_hint.text=str(DSMiniCatalog.HINTS[battle_type])+" · Стик + A/RT или движение + %s" % Controls.key_name("action",preferences)+"\nЦепь: "+(" → ".join(chain) if not chain.is_empty() else "нет выбранных карт")
	_refresh_battle_scores()
	if battle_time>=battle_duration: _finish_battle()

func _refresh_battle_scores() -> void:
	var enemy_mini: int = int(ds_enemy_progress) if rules_profile=="ds" else int(float(ai_target_points) * clampf(battle_time / maxf(battle_duration, 0.001), 0.0, 1.0))
	var player_total: int = _battle_base(0) + battle_effects.extra(0, battle_points)
	var enemy_total: int = _battle_base(1) + battle_effects.extra(1, enemy_mini)
	if rules_profile=="ds":
		scratch.set_meter(player_total,enemy_total)
	battle_scores.text = "ТВОЙ G-POWER                          G-POWER СОПЕРНИКА\n%d G                                          %d G" % [player_total, enemy_total]
	battle_effects_text.text = "ТЫ: %s    ·    СОПЕРНИК: %s" % [battle_effects.status(0), battle_effects.status(1)]
	var player: Dictionary = _battle_breakdown(0, battle_points)
	var enemy: Dictionary = _battle_breakdown(1, enemy_mini)
	power_label.text = "МИНИ-ИГРА: %d G" % int(player.mini)
	power_bar.value = float(battle_points) / 260.0 * 100.0
	target_text.text = "1–3 — ПОДХОДЯЩИЕ СПОСОБНОСТИ"
	battle_detail_text.text = "ТЫ: база %d + ворота %d + сбор %d − урон %d + способности %+d = %d G\nСОПЕРНИК: база %d + ворота %d + сбор %d − урон %d + способности %+d = %d G" % [player.base,player.gate,player.rolling,player.damage,player.ability,player.total,enemy.base,enemy.gate,enemy.rolling,enemy.damage,enemy.ability,enemy.total]
	if rules_profile=="ds":
		target_text.text="1–3 / D-PAD — ЦЕПЬ · %s / B — ПРОПУСТИТЬ" % Controls.key_name("skip",preferences)
		battle_scores.text = "ТВОЙ G-POWER                          G-POWER СОПЕРНИКА\n%d G                                          %d G" % [player.total,enemy.total]
		power_label.text = "ШКАЛА ПРЕИМУЩЕСТВА · %d%%" % roundi(scratch.advantage*100)
		power_bar.value=scratch.advantage*100.0
	else:
		battle_detail_text.text+="\nМини-игра: +%d / +%d G → итог %d / %d G" % [player.mini,enemy.mini,player_total,enemy_total]
	_sync_ds_battle()

func _sync_ds_battle(event: Dictionary = {}) -> void:
	if not is_instance_valid(ds_battle) or phase not in ["battle_ready", "battle","ds_scene"] or not rules.gates.has(battle_slot):
		return
	var enemy_mini: int = int(float(ai_target_points) * clampf(battle_time / maxf(battle_duration, 0.001), 0.0, 1.0))
	var gate: Dictionary = rules.gates[battle_slot].duplicate(true)
	var snapshot: Dictionary = {
		"key": "classic:%d:%d" % [match_id, battle_slot],
		"arena_id": str(arena.theme_id),
		"gate": gate,
		"units": gate.bakugan.duplicate(true),
		"totals": [_battle_base(0) + battle_effects.extra(0, battle_points), _battle_base(1) + battle_effects.extra(1, enemy_mini)],
		"supports": [],
		"priority": -1,
		"sequence_stage":ds_sequence_stage,
		"native_scratch":rules_profile=="ds",
	}
	if rules_profile=="ds":
		snapshot.totals = [_battle_base(0)+battle_effects.extra(0,0),_battle_base(1)+battle_effects.extra(1,0)]
	ds_battle.set_suspended(false)
	ds_battle.sync_battle(snapshot, event)

func _battle_breakdown(owner: int, mini_points: int) -> Dictionary:
	var result: Dictionary = {"base": 0, "gate": 0, "rolling": 0, "damage": 0, "mini": 0,"ability":0,"total":0}
	if owner < 0 or owner > 1 or not rules.gates.has(battle_slot):
		return result
	for unit in rules.gates[battle_slot].bakugan:
		if int(unit.owner) == owner:
			result.base += rules.effective_printed_power(battle_slot, unit)
			result.gate += rules.gate_unit_bonus(battle_slot, unit)
			result.damage += int(unit.get("sphere_damage", 0)) + int(unit.get("field_damage", 0))
			result.rolling += int(unit.get("roll_bonus", 0))
	result.ability=battle_effects.extra(owner,0)
	result.total=_battle_base(owner)+result.ability
	result.mini = maxi(0,mini_points)
	return result

func _show_battle_feedback(text: String, gained: int) -> void:
	battle_feedback.text = "%s  %s%d G" % [text, "+" if gained >= 0 else "", gained]
	battle_feedback.modulate.a = 1.0
	feedback_time = 0.8
	_refresh_battle_scores()
	if gained > 0:
		_sync_ds_battle({"event": "minigame_hit", "owner": 0, "gained": gained, "title": text})

func _battle_hit(keycode: int = KEY_SPACE) -> void:
	if phase != "battle" or hit_cooldown > 0.0 or paused or (battle_type=="shooting" or rules_profile=="ds"):
		return
	var gained: int = 0
	var correct: bool = false
	if battle_type == "timing":
		var required: Array[int] = _timing_keys()
		if required.size()>1 and required.has(keycode):
			for key: int in required:
				if key!=keycode and not _battle_key_held(key): return
		if rhythm_phase >= 0.415 and rhythm_phase <= 0.6:
			timing_window_hit = true
		correct = required.has(keycode) and rhythm_phase >= 0.415 and rhythm_phase <= 0.6
		gained = (64 if bonus_mode else 32) if correct else 0
		_update_streak(correct)
		timing_sequence += 1
		hit_cooldown = 0.23
	else:
		var movement: String = _shaking_movement()
		var required: Array = [KEY_A, KEY_D] if movement == "horizontal" else ([KEY_W, KEY_S] if movement == "vertical" else [KEY_W, KEY_D, KEY_S, KEY_A])
		correct = required.has(keycode) and not _shaking_stop()
		if movement == "circle":
			correct = correct and keycode == required[circle_sequence % 4]
			if correct:
				circle_sequence += 1
		else:
			# Holding one direction is not a shake.
			if keycode == last_shake_key and required.has(keycode) and not _shaking_stop():
				return
		last_shake_key = keycode
		gained = 10 if correct else -10
		hit_cooldown = 0.055
	var before: int = battle_points
	battle_points = maxi(0, battle_points + gained)
	_show_battle_feedback("БОНУС!" if bonus_mode and correct else ("ВЕРНО!" if correct else "ОШИБКА"), battle_points - before)
	_play_sound("hit" if correct else "miss")

func _battle_key_held(key: int) -> bool:
	var action: String=str({KEY_A:"left",KEY_D:"right",KEY_W:"up",KEY_S:"down",KEY_SPACE:"action"}.get(key,""))
	if not action.is_empty() and Controls.held(action,preferences): return true
	for button: int in {KEY_A:[JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_LEFT_SHOULDER],KEY_D:[JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_RIGHT_SHOULDER],KEY_W:[JOY_BUTTON_DPAD_UP],KEY_S:[JOY_BUTTON_DPAD_DOWN],KEY_SPACE:[JOY_BUTTON_A]}.get(key,[]):
		if controls.pad_held(button): return true
	return false

func _timing_keys() -> Array[int]:
	if battle_level == 1:
		return [KEY_SPACE]
	if battle_level == 2:
		var patterns: Array = [[KEY_A], [KEY_D], [KEY_A, KEY_D]]
		var result: Array[int] = []
		result.assign(patterns[timing_sequence % patterns.size()])
		return result
	var keys: Array[int] = [KEY_A, KEY_W, KEY_D, KEY_S]
	return [keys[timing_sequence % 4]]

func _update_timing_window(in_zone: bool) -> void:
	if in_zone and not timing_window_active:
		timing_window_active = true
		timing_window_hit = false
	elif not in_zone and timing_window_active:
		timing_window_active = false
		if not timing_window_hit:
			_update_streak(false)
			timing_sequence += 1
			_show_battle_feedback("ПРОПУЩЕНО", 0)

func _shaking_stop() -> bool:
	return battle_level >= 2 and fmod(battle_time, 2.4) >= 1.7

func _shaking_movement() -> String:
	if battle_level < 3:
		return "horizontal"
	return ["horizontal", "vertical", "circle"][int(battle_time / 2.4) % 3]

func _update_streak(correct: bool) -> void:
	if correct:
		battle_streak += 1
		bonus_mode = battle_streak >= 5
	else:
		battle_streak = 0
		bonus_mode = false

func _shoot_target(index: int = 0) -> void:
	if phase != "battle" or battle_type != "shooting" or paused or index < 0 or index >= shooting_attributes.size():
		return
	var target_attribute: String = shooting_attributes[index]
	var own_attribute: String = str(_battle_unit(0).get("attribute", ""))
	var gained: int = 0
	if target_attribute == "gold" and battle_level >= 2:
		for attribute in shooting_attributes:
			if attribute != "gold":
				gained += 24
	else:
		var correct: bool = target_attribute == own_attribute
		if correct:
			gained = 48 if bonus_mode else 24
		_update_streak(correct)
	battle_points += gained
	_show_battle_feedback("ЗОЛОТАЯ ЦЕЛЬ" if target_attribute == "gold" else ("ТВОЯ СТИХИЯ!" if gained > 0 else "ЧУЖАЯ СТИХИЯ"), gained)
	_play_sound("hit" if gained > 0 else "miss")
	_move_shooting_target()

func _move_shooting_target() -> void:
	shooting_attributes.clear()
	shooting_positions.clear()
	var own: String = str(_battle_unit(0).get("attribute", "Pyrus"))
	var other: String = str(_battle_unit(1).get("attribute", "Aquos"))
	if other == own:
		other = Rules.ATTRIBUTES[(Rules.ATTRIBUTES.find(own) + 1) % Rules.ATTRIBUTES.size()]
	shooting_attributes.append(own)
	shooting_attributes.append(other)
	shooting_attributes.append("gold" if battle_level >= 2 and rng.randf() < 0.5 else str(Rules.ATTRIBUTES[rng.randi_range(0, 5)]))
	# Randomize positions so selecting the player's attribute requires aiming.
	var columns: Array = [80.0, 378.0, 676.0]
	for index in range(3):
		var column: int = rng.randi_range(0, columns.size() - 1)
		var at: Vector2 = Vector2(float(columns[column]) + rng.randf_range(-20, 20), rng.randf_range(182, 184))
		columns.remove_at(column)
		shooting_positions.append(at)
		shooting_targets[index].position = at
		shooting_targets[index].text = shooting_attributes[index].to_upper()
		var color: Color = {"Pyrus": ORANGE, "Aquos": CYAN, "Subterra": Color("dca969"), "Haos": WHITE, "Darkus": Color("b397ff"), "Ventus": Color("8be0ad"), "gold": Color("ffe183")}.get(shooting_attributes[index], ORANGE)
		shooting_targets[index].add_theme_color_override("font_color", color)

func _finish_battle() -> void:
	# resolve_battle removes the gate; synchronize its units before that mutation.
	_sync_ds_battle()
	var shown_powers: Array = ds_battle.snapshot.get("totals",[]).duplicate()
	phase = "result"
	scratch.set_running(false)
	battle_panel.visible = false
	var result: Dictionary = rules.resolve_battle(battle_slot, battle_effects.extra(0, battle_points), battle_effects.extra(1, int(ds_enemy_progress) if rules_profile=="ds" else ai_target_points))
	if str(result.get("event", "invalid")) != "capture":
		ds_battle.reset()
		_clear_dragons()
		_sync_units()
		_log("Бой отменён: на воротах нет двух соперников.")
		_announce_then_advance("БОЙ НЕДОСТУПЕН", MUTED)
		return
	var owner: int = int(result.get("owner", 0))
	ds_battle.finish_battle(owner,shown_powers if rules_profile=="ds" and shown_powers.size()==2 else [int(result.get("player_g", 0)), int(result.get("enemy_g", 0))])
	last_battle_result = result.duplicate(true)
	for side in range(2):
		match_stats.record_battle(side, battle_points if side==0 else int(ds_enemy_progress) if rules_profile=="ds" else ai_target_points, int(battle_effects.counts[side]))
	match_stats.record_capture(owner, false)
	if rules_profile=="ds":
		result["display_powers"] = shown_powers
		result["mini_scores"]=[battle_points,int(ds_enemy_progress)]
		last_battle_result = result.duplicate(true)
		_log("%s забирает ворота. G: %d / %d; очки мини-игры: %d / %d." % ["Ты" if owner==0 else "Соперник",shown_powers[0],shown_powers[1],battle_points,int(ds_enemy_progress)])
	else:
		_log("%s забирает карту: %d G против %d G." % ["Ты" if owner == 0 else "Соперник", int(result.get("player_g", 0)), int(result.get("enemy_g", 0))])
	arena.capture_effect(arena.slot_position(battle_slot), ORANGE if owner == 0 else CYAN)
	arena.remove_gate(battle_slot)
	_sync_units()
	_clear_dragons()
	_refresh_hud()
	_play_sound("win")
	audio.voice_event("win" if owner==0 else "lose")
	if match_mode == "practice":
		_show_practice_result(result)
		return
	_announce_then_advance("КАРТА ТВОЯ!" if owner == 0 else "КАРТА СОПЕРНИКА", ORANGE if owner == 0 else CYAN)

func _clear_dragons() -> void:
	for dragon in dragons:
		if is_instance_valid(dragon):
			dragon.queue_free()
	dragons.clear()
	for node in unit_nodes.values():
		if is_instance_valid(node):
			node.visible = true

func _sync_ready_ball() -> void:
	if phase != "aim" or rules_profile != "ds":
		if is_instance_valid(ds_ready_ball):
			ds_ready_ball.queue_free()
		ds_ready_ball = null
		return
	var unit: Dictionary = rules.teams[0][selected_unit]
	var signature: String = str(unit.name)+str(unit.attribute)
	if is_instance_valid(ds_ready_ball) and ds_ready_ball.get_meta("ready_unit","") != signature:
		ds_ready_ball.queue_free()
		ds_ready_ball = null
	if not is_instance_valid(ds_ready_ball):
		ds_ready_ball = arena.make_ball(str(unit.attribute),0,str(unit.name))
		ds_ready_ball.set_meta("ready_unit",signature)
		ds_ready_ball.name = "ReadyBakugan"
	ds_ready_ball.position = arena.launch_position(0)

func _update_cards() -> void:
	_sync_ready_ball()
	var map_shown: bool = rules_profile=="ds" and arena.uses_large_ds_field()
	log_text.position.y = 252 if map_shown else 69
	log_text.size.y = 200 if map_shown else 385
	log_text.max_lines_visible = 8 if map_shown else 16
	charge_zone.visible = phase == "aim"
	action_button.visible = phase in ["place", "battle_ready", "double"]
	action_button.text = {"place": "БРОСИТЬ БЕЗ КАРТЫ", "battle_ready": "НАЧАТЬ БОЙ", "double": "ЗАБРАТЬ КАРТУ"}.get(phase, "")
	action_button.disabled = false
	throw_mode_button.visible = phase == "aim"
	throw_mode_button.text = "%s · P" % ("СИЛОВОЙ БРОСОК" if powered_throw else "БЕЗ УСИЛЕНИЯ")
	throw_mode_button.disabled = rules_profile=="ds" and not powered_throw and not _special_ready(0,selected_unit)
	if rules_profile=="ds":
		var unit: Dictionary=rules.teams[0][selected_unit] if rules.teams.size()==2 else {}
		var title: String=SpecialShots.title(str(unit.get("attribute","")))
		throw_mode_button.text = title+" · P" if _special_ready(0,selected_unit) else "НУЖЕН УР. 3 · P" if match_mode=="campaign" and int(unit.get("level",1))<3 else "НУЖНО 100 S · P"
		if powered_throw: throw_mode_button.text="✓ "+title+" · P"
		throw_mode_button.tooltip_text=SpecialShots.description(str(unit.get("attribute","")))+"\nЦена: 100 S. В кампании нужен уровень 3; в свободном бою броски открыты."
	_refresh_s_power()
	throw_style_button.visible = phase == "aim"
	throw_style_button.text = "%s · T" % ("ПРЯМОЙ БРОСОК" if ThrowMotion.normalize_style(throw_style) == "straight" else "ВЫСОКИЙ БРОСОК")
	if phase not in ["aim", "flying", "rolling", "battle", "battle_ready"]:
		power_bar.value = 0
		power_label.text = {"opening": "НАЧАЛЬНЫЕ ВОРОТА", "place": "КАРТА ПО ЖЕЛАНИЮ", "stay": "ВЫБЕРИ STAY", "double": "ЗАХВАТ ИЛИ ПЕРЕХОД", "finished": "МАТЧ ЗАВЕРШЁН", "result": "РЕЗУЛЬТАТ", "ai": "ХОД СОПЕРНИКА"}.get(phase, "ГОТОВЬСЯ К МАТЧУ")
		target_text.text = ""
	for i in range(3):
		var b: Button = card_buttons[i]
		b.visible = phase != "campaign"
		b.disabled = true
		b.text = "—"
		b.tooltip_text = ""
		b.icon = null
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 47)
		var selected: bool = false
		var accent: Color = Color("343b58")
		if phase in ["place", "opening"] and i < rules.hands[0].size():
			var gate: Dictionary = rules.hands[0][i]
			var kind: String = str(gate.color_type)
			accent = {"gold": Color("dbb567"), "silver": Color("a3c4d6"), "copper": Color("c78d60")}.get(kind, ORANGE)
			b.text = "%d  %s\nКарта ворот · %s" % [i + 1, str(gate.title), _card_type_ru(kind)]
			b.tooltip_text = _gate_description(gate)
			b.icon = _profile_card_texture(gate, "gate")
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = false
			selected = i == selected_gate
		elif phase in ["battle", "battle_ready"] and i < rules.abilities[0].size():
			var card: Dictionary = rules.abilities[0][i]
			var can_play: bool = _ability_allowed(0, card)
			if rules_profile=="ds":
				can_play = can_play and (phase=="battle_ready" or str(card.id)==ds_selected_ability)
			b.text = "%d  %s\n%s" % [i + 1, str(card.title), "СЫГРАТЬ КАРТУ" if can_play else "НЕДОСТУПНА"]
			if rules_profile=="ds" and phase=="battle_ready":
				b.text = "%d  %s\n%s" % [i+1,str(card.title),"ЦЕПЬ %d" % (ds_selected_chain.find(str(card.id))+1) if ds_selected_chain.has(str(card.id)) else "ВЫБРАТЬ ПЕРЕД БОЕМ" if can_play else "НЕДОСТУПНА"]
			b.tooltip_text = str(card.description)
			b.icon = _profile_card_texture(card, "ability")
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			accent = {"red": ORANGE, "green": Color("8be0ad"), "blue": CYAN}.get(str(card.color_type), ORANGE)
			b.disabled = not can_play
			if b.disabled:
				b.tooltip_text += "\n\nНедоступно: " + _ability_unavailable_reason(0, card)
		elif phase in ["battle", "battle_ready"]:
			var spent_index: int = i - rules.abilities[0].size()
			if spent_index >= 0 and spent_index < rules.spent_abilities[0].size():
				var spent: Dictionary = rules.spent_abilities[0][spent_index]
				b.text = "%s\nСПОСОБНОСТЬ СЫГРАНА" % str(spent.title)
				b.tooltip_text = "Карта уже сыграна в этом матче.\n" + str(spent.description)
				b.icon = _profile_card_texture(spent, "ability")
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		elif rules.teams.size() == 2:
			var unit: Dictionary = rules.teams[0][i]
			var status: String = ""
			if bool(unit.used):
				status = "\nНА ПОЛЕ / ИСПОЛЬЗОВАН" if bool(unit.get("landed_cycle", false)) else "\nИСПОЛЬЗОВАН"
			b.text = "%d  %s\n%s · %d G%s" % [i + 1, str(unit.name), str(unit.attribute), int(unit.g), status]
			b.disabled = not (phase == "stay" or (phase == "aim" and rules.available_units(0).has(i)))
			selected = phase == "aim" and i == selected_unit
		b.add_theme_stylebox_override("normal", _style(Color(0.15, 0.1, 0.1, 0.98) if selected else Color(0.07, 0.08, 0.14, 0.98), ORANGE if selected else accent, 2 if selected else 1))

	for button: Button in [action_button,throw_mode_button,throw_style_button]:
		Controls.hint_control(button,preferences)
	for index: int in card_buttons.size():
		var prefix: String=str(index+1)+"  "
		if card_buttons[index].text.begins_with(prefix): card_buttons[index].text=Controls.key_name("unit%d" % (index+1),preferences)+"  "+card_buttons[index].text.substr(prefix.length())
	Controls.hint_control(instruction,preferences)

func _unit_roll_bonus(owner: int, index: int) -> int:
	for gate in rules.gates.values():
		for unit in gate.bakugan:
			if int(unit.owner) == owner and int(unit.index) == index:
				return int(unit.get("roll_bonus", 0))
	return 0

func _card_type_ru(card_type: String) -> String:
	if card_type.to_lower().contains("silver"):
		return "серебро"
	if card_type.to_lower().contains("bronze") or card_type.to_lower().contains("copper"):
		return "медь"
	return "золото"

func _refresh_hud() -> void:
	_refresh_s_power()
	rules_tip.text = "Соперники на карте — бой.\nДва своих — захват или переход.\n\nТри своих на поле — STAY."
	score_text.text = "ТЫ   %d / 3     —     %d / 3   СОПЕРНИК" % [int(rules.scores[0]), int(rules.scores[1])]
	turn_text.text = "Твой ход" if rules.turn == 0 else "Соперник"
	turn_text.add_theme_color_override("font_color", ORANGE if rules.turn == 0 else CYAN)
	deck_text.text = "ТВОЙ РЕЗЕРВ\nВорота: %d   Способности: %d\nСыграно: %d\n\nСОПЕРНИК\nВорота: %d   Способности: %d\nСыграно: %d" % [rules.hands[0].size(), rules.abilities[0].size(), rules.spent_abilities[0].size(), rules.hands[1].size(), rules.abilities[1].size(), rules.spent_abilities[1].size()]
	var difficulty_name: String = {"easy": "ЛЁГКАЯ", "normal": "ОБЫЧНАЯ", "hard": "СЛОЖНАЯ"}.get(str(preferences.difficulty), "ОБЫЧНАЯ")
	var mode_name: String = {"quick": "БЫСТРЫЙ МАТЧ", "tournament": "ТУРНИР", "training": "ТРЕНИРОВКА", "practice": "ПРАКТИКА МИНИ-ИГРЫ"}.get(match_mode, "БЫСТРЫЙ МАТЧ")
	if match_mode=="campaign": mode_name="КАМПАНИЯ %d/7 · %s" % [campaign_chapter+1,str(Campaign.STAGES[campaign_chapter].opponent)]
	arena_text.text = "%s  ·  %s  ·  %s  ·  %s" % [str(ArenaCatalog.get_entry(str(arena.theme_id)).title).to_upper(), difficulty_name, mode_name, rules_profile.to_upper()]

func _refresh_s_power() -> void:
	if s_power_label==null:
		return
	s_power_label.visible = rules_profile=="ds"
	s_power_label.text = "S: %d/100  ·  Враг: %d/100" % [s_power[0],s_power[1]]

func _match_summary_text() -> String:
	var stats: Dictionary = match_stats.summary(0)
	return "Броски: %d · Попадания: %d · Промахи: %d\nСбор: +%d G · Мини-игры: +%d G\nБои: %d · Способности: %d · Двойные захваты: %d" % [stats.throws, stats.hits, stats.misses, stats.collected_g, stats.mini_g, stats.battles, stats.abilities, stats.double_stands]

func _log(message: String) -> void:
	journal.push_front(message)
	if journal.size() > 6:
		journal.resize(6)
	log_text.text = "\n\n".join(journal)

func _end_match() -> void:
	if rules.winner < 0 or last_recorded_match_id == match_id:
		return
	last_recorded_match_id = match_id
	ds_battle.set_suspended(true)
	phase = "finished"
	audio.voice_event("win" if rules.winner==0 else "lose")
	charging = false
	target_marker.visible = false
	trajectory.visible = false
	battle_panel.visible = false
	var new_result: bool=not settled_matches.has(match_token) and str(slot_settled.get(Checkpoint.active_slot,""))!=match_token
	if match_mode not in ["training", "practice"] and new_result:
		if rules.winner == 0:
			wins += 1
		else:
			losses += 1
		settled_matches.append(match_token)
		slot_settled[Checkpoint.active_slot]=match_token
		if settled_matches.size()>128: settled_matches.pop_front()
	var played_stage: Dictionary = tournament.get_stage()
	if match_mode == "tournament" and tournament.active and new_result:
		tournament.record_result(rules.winner == 0)
	var campaign_reward: Dictionary={}
	if match_mode=="campaign" and new_result:
		campaign_reward=campaign.record_result(rules.winner==0,campaign_chapter)
		campaign.coins+=experience_gained
	_save_profile()
	if profile_error==OK:
		checkpoint_error=Slots.write(Checkpoint.active_slot,{},campaign.to_dict() if match_mode=="campaign" else {"tournament":tournament.to_dict()})
		saved_match.clear()
	overlay.visible = true
	_set_overlay_menu_layout(false)
	overlay_title.text = "ТЫ ПОБЕДИЛ!" if rules.winner == 0 else "МАТЧ ОКОНЧЕН"
	overlay_body.text = "Счёт по картам: %d — %d\n\n%s\n\nТвои результаты: %d побед, %d поражений." % [int(rules.scores[0]), int(rules.scores[1]), "Три карты захвачены. Отличная игра!" if rules.winner == 0 else "Соперник первым захватил три карты. Попробуй другую тактику и используй способности в бою.", wins, losses]
	overlay_start.text = "СЫГРАТЬ ЕЩЁ"
	if match_mode=="campaign":
		var chapter_data: Dictionary=Campaign.STAGES[campaign_chapter]
		overlay_body.text="%s: %d — %d\n\n%s" % [str(chapter_data.title),rules.scores[0],rules.scores[1],str(chapter_data.after) if rules.winner==0 else "Поражение не закрывает главу. Измени команду или улучши её и повтори бой."]
		if not campaign_reward.is_empty():
			overlay_body.text+="\n\nНаграды: %d очков · %s · арена %s · %d карт." % [campaign_reward.coins,Campaign.species_name(str(campaign_reward.species)),str(campaign_reward.arena).trim_prefix("ds_").to_upper(),campaign_reward.cards.size()]
		elif rules.winner==0: overlay_body.text+="\n\nНаграды этой главы уже получены."
		overlay_start.text="РАЗВИТИЕ / СЛЕДУЮЩАЯ ГЛАВА"
		overlay_start.add_theme_font_size_override("font_size",15)
	if match_mode == "tournament":
		if tournament.completed:
			overlay_title.text = "КУБОК ТВОЙ!"
			overlay_body.text = "Ты прошёл квалификацию, полуфинал и финал.\n\nКоманда и результаты сохранены. В меню можно начать новый турнир или сыграть быстрый матч."
			overlay_start.text = "В ГЛАВНОЕ МЕНЮ"
		elif rules.winner == 0:
			overlay_title.text = "РАУНД ПРОЙДЕН!"
			overlay_body.text = "%s: победа %d — %d.\n\nСледующий этап: %s. Соперник станет сильнее.\n\nПрогресс сохранён — можно продолжить сейчас или позже." % [str(played_stage.title), int(rules.scores[0]), int(rules.scores[1]), str(tournament.get_stage().title)]
			overlay_start.text = "СЛЕДУЮЩИЙ РАУНД"
		else:
			overlay_title.text = "ПОПРОБУЙ ЕЩЁ!"
			overlay_body.text = "%s: поражение %d — %d.\n\nЭтап сохранён. Повтори матч или вернись в меню, чтобы выбрать другой состав команды." % [str(played_stage.title), int(rules.scores[0]), int(rules.scores[1])]
			overlay_start.text = "ПОВТОРИТЬ РАУНД"
	if match_mode == "training":
		overlay_title.text = "ТРЕНИРОВКА ЗАВЕРШЕНА"
		overlay_body.text = "Счёт по картам: %d — %d\n\nТренировочный матч не меняет победы, поражения и этап турнира." % [int(rules.scores[0]), int(rules.scores[1])]
	overlay_body.text += "\n\n" + _match_summary_text()
	_refresh_hud()
	_update_cards()

func _toggle_pause() -> void:
	_cancel_throw_input()
	if phase in ["menu", "finished", "roster", "deck", "gates", "settings", "help", "training_setup", "model", "card_view", "campaign", "saves"]:
		return
	paused = not paused
	scratch.set_running(not paused and phase=="battle" and rules_profile=="ds")
	get_tree().paused = paused
	audio.set_suspended(paused)
	ds_battle.set_suspended(paused)
	if paused:
		_save_checkpoint()
		_set_overlay_menu_layout(false)
		charging = false
		overlay.visible = true
		overlay_title.text = "ПАУЗА"
		overlay_body.text = "Матч сохранён: счёт, поле, карты, сфера и текущий бой.\nВ меню кнопка «Продолжить» вернёт к этому моменту.\n\nWASD — коррекция · Shift — тормоз\n1–3 — команда / способности\n\nESC — вернуться к матчу."
		if checkpoint_error!=OK: overlay_body.text="Не удалось записать матч (ошибка %d).\nПродолжение доступно в этой сессии.\n\nESC — вернуться к матчу." % checkpoint_error
		overlay_start.text = "ПРОДОЛЖИТЬ"
	else:
		overlay.visible = false

func _sync_audio_context() -> void:
	if not is_instance_valid(audio): return
	audio.set_suspended(paused)
	var context: String = phase
	if phase in ["battle_ready","battle","ds_scene"]:
		context = "battle"
	elif phase in ["opening","place","aim","ai","stay","double","flying","rolling"]:
		context = "training" if match_mode in ["training","practice"] else "field"
	elif phase == "result":
		context = "win" if int(last_battle_result.get("owner",1))==0 else "lose"
	elif phase == "finished":
		context = "win" if (int(last_battle_result.get("owner",1))==0 if match_mode=="practice" else rules.winner==0) else "lose"
	audio.set_context(context,str(arena.theme_id))

func _play_sound(name: String) -> void:
	if is_instance_valid(audio): audio.effect(name)

func _load_profile(path: String = "user://profile.cfg") -> void:
	path=preload("res://scripts/save_files.gd").resolve(path)
	var config = ConfigFile.new()
	var has_profile: bool = config.load(path) == OK
	if not has_profile and FileAccess.file_exists(path+".bak"): has_profile=config.load(path+".bak")==OK
	profile_decks = {"wii": {"abilities": [], "gates": []}, "ds": {"abilities": [], "gates": []}}
	var loaded_profile: String = "ds" if _ds_profile_available() else "wii"
	campaign_profiles.clear()
	slot_settled.clear()
	profile_rosters = {"wii":{"selection":[0,1,2],"attributes":["Pyrus","Pyrus","Ventus"]},"ds":{"selection":DSProfiles.starter_indices(Roster.CREATURES),"attributes":["Pyrus","Ventus","Aquos"]}}
	if has_profile:
		wins = int(config.get_value("results", "wins", 0))
		losses = int(config.get_value("results", "losses", 0))
		var settled: Variant=config.get_value("results","settled",[])
		if settled is Array:
			settled_matches.clear()
			for token: Variant in settled:
				if token is String and token.length()<100: settled_matches.append(token)
			while settled_matches.size()>128: settled_matches.pop_front()
		muted = bool(config.get_value("settings", "muted", false))
		var saved_throw_style: Variant = config.get_value("controls", "throw_style", "lob")
		throw_style = ThrowMotion.normalize_style(saved_throw_style if saved_throw_style is String else "lob")
		var selection: Variant = config.get_value("team", "selection", [])
		var attributes: Variant = config.get_value("team", "attributes", [])
		var schema: int = int(config.get_value("profile", "schema", 0))
		var deck_selection: Variant = config.get_value("deck", "selection", [])
		var gate_selection: Variant = config.get_value("gates", "selection", [])
		var saved_preferences: Variant = config.get_value("settings", "preferences", {})
		var progress: Variant = config.get_value("tournament", "progress", {})
		selected_roster = Roster.normalize_selection(selection if selection is Array else [])
		selected_attributes = Roster.normalize_selection_attributes(selected_roster, attributes if attributes is Array else [])
		# Schema 6 selections are Wii catalog indices. Preserve them before any
		# profile switch; they must never be interpreted as DS source cards.
		profile_decks.wii = {
			"abilities": AbilityCatalog.normalize_selection(deck_selection if schema >= 6 and deck_selection is Array else []),
			"gates": GateCatalog.normalize_selection(gate_selection if schema >= 6 and gate_selection is Array else []),
		}
		if schema >= 7:
			for profile: String in ["wii", "ds"]:
				for kind: String in ["ability", "gate"]:
					var key: String = "abilities" if kind == "ability" else "gates"
					var saved: Variant = config.get_value("decks_" + profile, key, profile_decks.get(profile, {}).get(key, []))
					profile_decks[profile][key] = _normalize_deck(kind, saved if saved is Array else [], profile)
					if profile == "ds":
						var stable_keys: Variant = config.get_value("decks_ds", kind + "_keys", [])
						if stable_keys is Array and not stable_keys.is_empty():
							profile_decks.ds[key] = _ds_selection_from_keys(kind, stable_keys)
			loaded_profile = "ds" if str(config.get_value("profile", "rules", "wii")) == "ds" and _ds_profile_available() else "wii"
		else:
			loaded_profile = "wii"
		profile_rosters[loaded_profile] = {"selection":selected_roster.duplicate(),"attributes":selected_attributes.duplicate()}
		if schema>=8:
			for profile: String in ["wii","ds"]:
				var saved_team: Variant = config.get_value("teams_"+profile,"selection",profile_rosters[profile].selection)
				var saved_attributes: Variant = config.get_value("teams_"+profile,"attributes",profile_rosters[profile].attributes)
				profile_rosters[profile] = {"selection":Roster.normalize_selection(saved_team if saved_team is Array else []),"attributes":Roster.normalize_attributes(saved_attributes if saved_attributes is Array else [])}
		selected_roster = profile_rosters[loaded_profile].selection.duplicate()
		selected_attributes = Roster.normalize_selection_attributes(selected_roster,profile_rosters[loaded_profile].attributes)
		selected_arena = ArenaCatalog.normalize_id(config.get_value("environment", "id", "stadium"))
		selected_field_layout = clampi(int(config.get_value("environment","ds_layout",0)),0,3)
		preferences = GameSettings.normalize(saved_preferences if saved_preferences is Dictionary else {})
		tournament.load_dict(progress if progress is Dictionary else {})
		var campaign_data: Variant=config.get_value("campaign","progress",{})
		campaign=Campaign.new()
		campaign.load_dict(campaign_data if campaign_data is Dictionary else {})
		for slot: String in Slots.ids("campaign"):
			var item: Variant=config.get_value("save_slots",slot,{})
			if item is Dictionary and item.get("schema",0)==1:
				var clean=Campaign.new(); clean.load_dict(item); campaign_profiles[slot]=clean.to_dict()
		campaign_slot=str(config.get_value("save_slots","campaign_active","campaign_1"))
		if not Slots.ids("campaign").has(campaign_slot): campaign_slot="campaign_1"
		free_slot=str(config.get_value("save_slots","free_active","free_1"))
		if not Slots.ids("free").has(free_slot): free_slot="free_1"
		anime_slot=str(config.get_value("save_slots","anime_active","anime_1"))
		if not Slots.ids("anime").has(anime_slot): anime_slot="anime_1"
		if campaign_profiles.has(campaign_slot):
			campaign=Campaign.new(); campaign.load_dict(campaign_profiles[campaign_slot])
		var active: String=str(config.get_value("save_slots","resume_active",free_slot))
		Checkpoint.active_slot=active if Checkpoint.valid_slot(active) else free_slot
		var ledger: Variant=config.get_value("save_slots","settled",{})
		if ledger is Dictionary:
			for id: Variant in ledger:
				if id is String and Checkpoint.valid_slot(id) and ledger[id] is String and ledger[id].length()<100: slot_settled[id]=ledger[id]
	for profile: String in ["wii", "ds"]:
		profile_decks[profile]["abilities"] = _normalize_deck("ability", profile_decks[profile].get("abilities", []), profile)
		profile_decks[profile]["gates"] = _normalize_deck("gate", profile_decks[profile].get("gates", []), profile)
	rules_profile = loaded_profile
	selected_roster = profile_rosters[rules_profile].selection.duplicate()
	selected_attributes = Roster.normalize_selection_attributes(selected_roster,profile_rosters[rules_profile].attributes)
	if rules_profile=="ds" and not selected_arena.begins_with("ds_"): selected_arena = "ds_toy"
	if rules_profile=="ds" and (not has_profile or not config.has_section_key("controls","throw_style")): throw_style = "straight"
	selected_deck = profile_decks[rules_profile].abilities.duplicate()
	selected_gate_deck = profile_decks[rules_profile].gates.duplicate()
	_rebuild_card_selectors()
	_refresh_deck_ui()
	_refresh_gate_ui()
	_apply_settings()

func _save_profile(path: String = "user://profile.cfg") -> void:
	path=preload("res://scripts/save_files.gd").resolve(path)
	selected_roster = Roster.normalize_selection(selected_roster)
	selected_attributes = Roster.normalize_selection_attributes(selected_roster, selected_attributes)
	_store_current_decks()
	var config = ConfigFile.new()
	config.set_value("profile", "schema", 10)
	config.set_value("profile", "rules", rules_profile)
	config.set_value("results", "wins", wins)
	config.set_value("results", "losses", losses)
	config.set_value("results","settled",settled_matches)
	config.set_value("settings", "muted", muted)
	config.set_value("controls", "throw_style", ThrowMotion.normalize_style(throw_style))
	config.set_value("settings", "preferences", GameSettings.normalize(preferences))
	config.set_value("team", "selection", Roster.normalize_selection(selected_roster))
	config.set_value("team", "attributes", selected_attributes)
	for profile: String in ["wii", "ds"]:
		config.set_value("teams_"+profile,"selection",profile_rosters[profile].selection)
		config.set_value("teams_"+profile,"attributes",profile_rosters[profile].attributes)
		for kind: String in ["ability", "gate"]:
			var key: String = "abilities" if kind == "ability" else "gates"
			config.set_value("decks_" + profile, key, _normalize_deck(kind, profile_decks[profile].get(key, []), profile))
			if profile == "ds":
				config.set_value("decks_ds", kind + "_keys", _ds_selection_keys(kind, profile_decks.ds.get(key, [])))
	# Retain compatibility keys for older builds; always write Wii indices here.
	config.set_value("deck", "selection", profile_decks.wii.abilities)
	config.set_value("gates", "selection", profile_decks.wii.gates)
	config.set_value("environment", "id", ArenaCatalog.normalize_id(selected_arena))
	config.set_value("environment","ds_layout",selected_field_layout)
	config.set_value("tournament", "progress", tournament.to_dict())
	config.set_value("campaign","progress",campaign.to_dict())
	campaign_profiles[campaign_slot]=campaign.to_dict()
	for slot: String in Slots.ids("campaign"):
		if campaign_profiles.has(slot): config.set_value("save_slots",slot,campaign_profiles[slot])
	config.set_value("save_slots","campaign_active",campaign_slot)
	config.set_value("save_slots","free_active",free_slot)
	config.set_value("save_slots","anime_active",anime_slot)
	config.set_value("save_slots","resume_active",Checkpoint.active_slot)
	config.set_value("save_slots","settled",slot_settled)
	profile_error=preload("res://scripts/save_files.gd").write_config(config,path)

func _open_saves() -> void:
	_open_preparation("saves",save_slot_panel)
	save_slot_panel.open(Slots.kind(Checkpoint.active_slot))

func _select_campaign_slot(id: String) -> void:
	campaign_profiles[campaign_slot]=campaign.to_dict()
	campaign_slot=id
	var value: Dictionary=campaign_profiles.get(id,Slots.record(id).get("progress",{}))
	campaign=Campaign.new()
	campaign.load_dict(value)
	campaign_profiles[id]=campaign.to_dict()
	Checkpoint.active_slot=id
	_save_profile()

func _new_slot_game(id: String) -> void:
	match Slots.kind(id):
		"campaign":
			_select_campaign_slot(id)
			_close_preparation()
			_open_campaign()
		"anime": _request_slot_start("anime",id)
		"free": _request_slot_start("quick",id)

func _request_slot_start(mode: String, requested: String="") -> void:
	var kind: String="anime" if mode=="anime" else "free"
	var preferred: String=anime_slot if kind=="anime" else free_slot
	var id: String=requested if not requested.is_empty() else Slots.first_empty(kind,preferred)
	if id.is_empty(): id=preferred
	if Slots.kind(id)!=kind: return
	pending_new_slot=id; pending_new_mode=mode
	if not Slots.occupied(id):
		_confirm_slot_start(); return
	var dialog: ConfirmationDialog=get_node_or_null("ReplaceSlotDialog") as ConfirmationDialog
	if dialog==null:
		dialog=ConfirmationDialog.new(); dialog.name="ReplaceSlotDialog"
		dialog.process_mode=Node.PROCESS_MODE_ALWAYS
		dialog.title="Заменить сохранённый бой?"
		dialog.ok_button_text="Заменить бой"; dialog.cancel_button_text="Отмена"
		dialog.confirmed.connect(_confirm_slot_start)
		dialog.canceled.connect(func(): pending_new_slot=""; pending_new_mode="")
		add_child(dialog)
	dialog.dialog_text="В слоте %s есть незаконченный бой. Новый матч заменит только его. Остальные слоты сохранятся." % id.get_slice("_",1)
	dialog.popup_centered(Vector2i(590,190))

func _confirm_slot_start() -> void:
	var id: String=pending_new_slot; var mode: String=pending_new_mode
	pending_new_slot=""; pending_new_mode=""
	if not Checkpoint.valid_slot(id): return
	Checkpoint.active_slot=id
	if mode=="anime":
		anime_slot=id; _save_profile(); _launch_anime_slot()
	else:
		free_slot=id; match_mode="tournament" if mode=="tournament_continue" else mode
		if mode=="tournament": tournament.start_new()
		_save_profile(); start_match()

func _resume_slot(id: String) -> void:
	var record: Dictionary=Slots.record(id)
	var data: Dictionary=record.get("match",{})
	if data.is_empty():
		save_slot_panel.message.text="В этом слоте нет незаконченного боя."
		return
	if Slots.kind(id)=="campaign":
		_select_campaign_slot(id)
	elif Slots.kind(id)=="free":
		free_slot=id
		var progress: Dictionary=record.get("progress",{}).get("tournament",{})
		tournament.load_dict(progress)
	else: anime_slot=id
	Checkpoint.active_slot=id
	if data.get("mode","")!="anime" and (settled_matches.has(str(data.main.match_token)) or str(slot_settled.get(id,""))==str(data.main.match_token)):
		checkpoint_error=Slots.write(id,{},campaign.to_dict() if Slots.kind(id)=="campaign" else {"tournament":tournament.to_dict()})
		save_slot_panel.refresh()
		save_slot_panel.message.text="Этот бой уже завершён. Прогресс сохранён; можно начать следующий."
		return
	saved_match=data.duplicate(true)
	_save_profile()
	_resume_match()

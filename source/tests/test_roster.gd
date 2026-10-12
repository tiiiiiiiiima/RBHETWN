extends SceneTree
## Compatibility and native-source roster coverage for the 0.8 expansion.
## Run: godot --headless --path . --script tests/test_roster.gd

const Roster = preload("res://scripts/roster.gd")
# Species verified in Steam Workshop 2480698294, not copied power statistics.
const SOURCE_KEYS = [
	"alpha_hydranoid",
	"apollonir",
	"battle_ax_vladitor",
	"bee_striker",
	"blade_tigrerra",
	"centipoid",
	"centorrior",
	"clayf",
	"cycloid",
	"delta_dragonoid",
	"dragonoid",
	"druman",
	"dual_hydranoid",
	"el_condor",
	"exedra",
	"falconeer",
	"fear_ripper",
	"fifth_paladin",
	"fourtress",
	"frosch",
	"gargonoid",
	"gorem",
	"griffon",
	"hairadee",
	"hammer_gorem",
	"harpus",
	"hydranoid",
	"hynoid",
	"infinity_dragonoid",
	"juggernoid",
	"lars_lion",
	"laserman",
	"leonidas",
	"limulus",
	"manion",
	"mantris",
	"mecha_chamelia",
	"mock_dragonoid",
	"monarus",
	"naga",
	"oberus",
	"omega_leonidas",
	"preyas",
	"preyas_ii_angelo",
	"preyas_ii_diablo",
	"rabeeder",
	"rattleoid",
	"ravenoid",
	"reaper",
	"robotallion",
	"saurus",
	"serpenoid",
	"siege",
	"silent_naga",
	"sirenoid",
	"skyress",
	"stinglash",
	"storm_skyress",
	"tayghen",
	"tentaclear",
	"terrorclaw",
	"tigrerra",
	"tricloid",
	"tuskor",
	"ultimate_dragonoid",
	"vladitor",
	"warius",
	"wavern",
	"wormquake",
]
const ADDED_SOURCE_KEYS = [
	"abis_omega", "altair", "aluze", "boriates", "cross_dragonoid",
	"cyborg_helios", "dryoid", "elfin", "elico", "farbros", "goblin_ball",
	"hades", "hyper_dragonoid", "ingram", "jelldon", "knight_percival",
	"mac_spider", "macubass", "magma_wilda", "master_ingram", "mega_brontes",
	"mega_nemus", "minx_elfin", "neo_dragonoid", "percival", "premo_vulcan",
	"saint_nemus", "thunder_wilda", "vexos_dragonoid", "viper_helios",
]
const LEGACY_ENTRIES = [
	{"id": "leonidas", "name": "Leonidas", "g": 340},
	{"id": "dragonoid", "name": "Dragonoid", "g": 320},
	{"id": "griffon", "name": "Griffon", "g": 300},
	{"id": "hydranoid", "name": "Hydranoid", "g": 350},
	{"id": "preyas", "name": "Preyas", "g": 310},
	{"id": "gorem", "name": "Gorem", "g": 330},
]
var failures: Array[String] = []
var checks: int = 0


func _init() -> void:
	_legacy_compatibility()
	_source_coverage()
	_all_species_attributes()
	_save_normalization()
	print("ROSTER 0.8 CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _legacy_compatibility() -> void:
	for index: int in range(LEGACY_ENTRIES.size()):
		_check(Roster.CREATURES[index] == LEGACY_ENTRIES[index],
			"Legacy index %d keeps its ID, name and G power" % index)
	_check(Roster.make_team([], []) == [
		{"id": "p0_leonidas", "name": "Leonidas", "attribute": "Pyrus", "g": 340, "used": false},
		{"id": "p0_dragonoid", "name": "Dragonoid", "attribute": "Pyrus", "g": 320, "used": false},
		{"id": "p0_griffon", "name": "Griffon", "attribute": "Ventus", "g": 300, "used": false},
	], "A legacy profile without a selected roster retains its original team")
	var saved_selection: Array = [5, 3, 4]
	var saved_attributes: Array = ["Haos", "Darkus", "Aquos"]
	var team: Array[Dictionary] = Roster.make_team(saved_selection, saved_attributes)
	_check(team[0].name == "Gorem" and team[1].name == "Hydranoid" and team[2].name == "Preyas"
		and team[0].attribute == "Haos" and team[1].attribute == "Darkus" and team[2].attribute == "Aquos",
		"An existing nondefault save retains team order and per-slot attributes")
	_check(Roster.make_opponent(0)[0].name == "Hydranoid"
		and Roster.make_opponent(1)[1].name == "Dragonoid"
		and Roster.make_opponent(2)[1].name == "Leonidas",
		"Appending species preserves the tournament opponent selections")
	var old_indices: Array = []
	for creature: Dictionary in LEGACY_ENTRIES:
		old_indices.append(creature.id)
	for key: String in SOURCE_KEYS:
		if not old_indices.has(key):
			old_indices.append(key)
	for index: int in range(old_indices.size()):
		_check(Roster.CREATURES[index].id == old_indices[index],
			"Every 0.7 source species keeps its save index: " + str(old_indices[index]))
		if index >= LEGACY_ENTRIES.size():
			_check(Roster.CREATURES[index].g == 300 + ((index - 6) % 7) * 10,
				"Every 0.7 source species keeps its prototype power: " + str(old_indices[index]))


func _source_coverage() -> void:
	var ids: Array[String] = []
	var names: Array[String] = []
	var balanced: bool = true
	for index: int in range(Roster.CREATURES.size()):
		var creature: Dictionary = Roster.CREATURES[index]
		ids.append(str(creature.id))
		names.append(str(creature.name))
		if index >= LEGACY_ENTRIES.size():
			balanced = balanced and creature.g >= 300 and creature.g <= 360 and creature.g % 10 == 0
	ids.sort()
	var expected_keys: Array = SOURCE_KEYS.duplicate()
	expected_keys.append_array(ADDED_SOURCE_KEYS)
	expected_keys.sort()
	_check(ids == expected_keys, "The playable roster covers 69 existing and 30 missing Workshop species exactly once")
	var unique_names: Dictionary = {}
	for species_name: String in names:
		unique_names[species_name] = true
	_check(unique_names.size() == SOURCE_KEYS.size() + ADDED_SOURCE_KEYS.size(), "Every species has a unique selectable display name")
	_check(names.count("Griffon") == 1 and not names.has("Griffin"),
		"The source Griffon name maps to the existing save identity without a duplicate alias")
	_check(balanced, "New species use bounded prototype G balance rather than Workshop statistics")
	var appended_ids: Array[String] = []
	for index: int in range(6, SOURCE_KEYS.size()):
		appended_ids.append(str(Roster.CREATURES[index].id))
	var sorted_append: Array[String] = appended_ids.duplicate()
	sorted_append.sort()
	_check(appended_ids == sorted_append, "0.7 save indices retain their canonical-key order")
	appended_ids.clear()
	for index: int in range(SOURCE_KEYS.size(), Roster.CREATURES.size()):
		appended_ids.append(str(Roster.CREATURES[index].id))
	_check(appended_ids == ADDED_SOURCE_KEYS, "0.8 appends missing species in canonical-key order")
	for key: String in ["hylash", "scorpion", "shadow_wing", "fortress", "metalfencer"]:
		_check(not ids.has(key), "A support or trap cannot occupy a three-Bakugan team slot: " + key)


func _all_species_attributes() -> void:
	_check(Roster.ATTRIBUTES == ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"],
		"The expansion retains the six attribute identifiers and their save order")
	for attribute: String in Roster.ATTRIBUTES:
		var all_valid: bool = true
		for index: int in range(Roster.CREATURES.size()):
			var selection: Array = [index, (index + 1) % Roster.CREATURES.size(), (index + 2) % Roster.CREATURES.size()]
			var attributes: Array = [attribute, attribute, attribute]
			for owner: int in [0, 1]:
				var team: Array[Dictionary] = Roster.make_team(selection, attributes, owner)
				all_valid = all_valid and team.size() == 3
				for slot: int in range(team.size()):
					var creature: Dictionary = Roster.CREATURES[selection[slot]]
					all_valid = all_valid and team[slot].name == creature.name
					all_valid = all_valid and team[slot].id == "p%d_%s" % [owner, creature.id]
					all_valid = all_valid and team[slot].attribute == attribute
					all_valid = all_valid and team[slot].g == creature.g and not team[slot].used
		_check(all_valid, "All playable species can be selected with attribute %s for either player" % attribute)


func _save_normalization() -> void:
	for selection: Array in [[0, 1, 2], [5, 3, 4], [6, 34, 68], [69, 83, 98]]:
		var json_selection: Array = JSON.parse_string(JSON.stringify(selection))
		_check(Roster.normalize_selection(json_selection) == selection,
			"JSON round trip preserves legacy and appended indices: %s" % str(selection))
	for invalid: Array in [[0, 1, Roster.CREATURES.size()], [6, 6, 68], [68, 6, -1], [6.5, 34, 68], [NAN, 34, 68], [INF, 34, 68], ["6", 34, 68], [true, 34, 68]]:
		_check(Roster.normalize_selection(invalid) == [0, 1, 2],
			"Invalid expanded save falls back to a complete default team: %s" % str(invalid))
	var first: Array[Dictionary] = Roster.make_team([6, 34, 68], ["Aquos", "Haos", "Darkus"])
	first[0].g = 999
	first[0].used = true
	first[1].attribute = "Pyrus"
	var restored: Array[Dictionary] = Roster.make_team([6, 34, 68], ["Aquos", "Haos", "Darkus"])
	_check(restored[0].g == Roster.CREATURES[6].g and not restored[0].used and restored[1].attribute == "Haos",
		"Expanded teams keep match mutations separate from saved roster defaults")

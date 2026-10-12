extends RefCounted
## Selectable teams for the prototype. The G values and opponent lineups
## are demo balance, not a transcription of the Wii game's character data.
## The first six entries are save-compatible with versions 0.3–0.6.
## Version 0.7 appends the other Steam Workshop species in canonical-key order;
## new G values cycle through 300–360 as prototype balance, not source stats.

const CanonicalCatalog = preload("res://scripts/canonical_catalog.gd")

const CREATURES = [
	{"id": "leonidas", "name": "Leonidas", "g": 340},
	{"id": "dragonoid", "name": "Dragonoid", "g": 320},
	{"id": "griffon", "name": "Griffon", "g": 300},
	{"id": "hydranoid", "name": "Hydranoid", "g": 350},
	{"id": "preyas", "name": "Preyas", "g": 310},
	{"id": "gorem", "name": "Gorem", "g": 330},
	{"id": "alpha_hydranoid", "name": "Alpha Hydranoid", "g": 300},
	{"id": "apollonir", "name": "Apollonir", "g": 310},
	{"id": "battle_ax_vladitor", "name": "Battle Ax Vladitor", "g": 320},
	{"id": "bee_striker", "name": "Bee Striker", "g": 330},
	{"id": "blade_tigrerra", "name": "Blade Tigrerra", "g": 340},
	{"id": "centipoid", "name": "Centipoid", "g": 350},
	{"id": "centorrior", "name": "Centorrior", "g": 360},
	{"id": "clayf", "name": "Clayf", "g": 300},
	{"id": "cycloid", "name": "Cycloid", "g": 310},
	{"id": "delta_dragonoid", "name": "Delta Dragonoid", "g": 320},
	{"id": "druman", "name": "Druman", "g": 330},
	{"id": "dual_hydranoid", "name": "Dual Hydranoid", "g": 340},
	{"id": "el_condor", "name": "El Condor", "g": 350},
	{"id": "exedra", "name": "Exedra", "g": 360},
	{"id": "falconeer", "name": "Falconeer", "g": 300},
	{"id": "fear_ripper", "name": "Fear Ripper", "g": 310},
	{"id": "fifth_paladin", "name": "Fifth Paladin", "g": 320},
	{"id": "fourtress", "name": "Fourtress", "g": 330},
	{"id": "frosch", "name": "Frosch", "g": 340},
	{"id": "gargonoid", "name": "Gargonoid", "g": 350},
	{"id": "hairadee", "name": "Hairadee", "g": 360},
	{"id": "hammer_gorem", "name": "Hammer Gorem", "g": 300},
	{"id": "harpus", "name": "Harpus", "g": 310},
	{"id": "hynoid", "name": "Hynoid", "g": 320},
	{"id": "infinity_dragonoid", "name": "Infinity Dragonoid", "g": 330},
	{"id": "juggernoid", "name": "Juggernoid", "g": 340},
	{"id": "lars_lion", "name": "Lars Lion", "g": 350},
	{"id": "laserman", "name": "Laserman", "g": 360},
	{"id": "limulus", "name": "Limulus", "g": 300},
	{"id": "manion", "name": "Manion", "g": 310},
	{"id": "mantris", "name": "Mantris", "g": 320},
	{"id": "mecha_chamelia", "name": "Mecha Chamelia", "g": 330},
	{"id": "mock_dragonoid", "name": "Mock Dragonoid", "g": 340},
	{"id": "monarus", "name": "Monarus", "g": 350},
	{"id": "naga", "name": "Naga", "g": 360},
	{"id": "oberus", "name": "Oberus", "g": 300},
	{"id": "omega_leonidas", "name": "Omega Leonidas", "g": 310},
	{"id": "preyas_ii_angelo", "name": "Preyas II Angelo", "g": 320},
	{"id": "preyas_ii_diablo", "name": "Preyas II Diablo", "g": 330},
	{"id": "rabeeder", "name": "Rabeeder", "g": 340},
	{"id": "rattleoid", "name": "Rattleoid", "g": 350},
	{"id": "ravenoid", "name": "Ravenoid", "g": 360},
	{"id": "reaper", "name": "Reaper", "g": 300},
	{"id": "robotallion", "name": "Robotallion", "g": 310},
	{"id": "saurus", "name": "Saurus", "g": 320},
	{"id": "serpenoid", "name": "Serpenoid", "g": 330},
	{"id": "siege", "name": "Siege", "g": 340},
	{"id": "silent_naga", "name": "Silent Naga", "g": 350},
	{"id": "sirenoid", "name": "Sirenoid", "g": 360},
	{"id": "skyress", "name": "Skyress", "g": 300},
	{"id": "stinglash", "name": "Stinglash", "g": 310},
	{"id": "storm_skyress", "name": "Storm Skyress", "g": 320},
	{"id": "tayghen", "name": "Tayghen", "g": 330},
	{"id": "tentaclear", "name": "Tentaclear", "g": 340},
	{"id": "terrorclaw", "name": "Terrorclaw", "g": 350},
	{"id": "tigrerra", "name": "Tigrerra", "g": 360},
	{"id": "tricloid", "name": "Tricloid", "g": 300},
	{"id": "tuskor", "name": "Tuskor", "g": 310},
	{"id": "ultimate_dragonoid", "name": "Ultimate Dragonoid", "g": 320},
	{"id": "vladitor", "name": "Vladitor", "g": 330},
	{"id": "warius", "name": "Warius", "g": 340},
	{"id": "wavern", "name": "Wavern", "g": 350},
	{"id": "wormquake", "name": "Wormquake", "g": 360},
	# 0.8 additions; native source skins only, demo G balance.
	{"id": "abis_omega", "name": "Abis Omega", "g": 300},
	{"id": "altair", "name": "Altair", "g": 310},
	{"id": "aluze", "name": "Aluze", "g": 320},
	{"id": "boriates", "name": "Boriates", "g": 330},
	{"id": "cross_dragonoid", "name": "Cross Dragonoid", "g": 340},
	{"id": "cyborg_helios", "name": "Cyborg Helios", "g": 350},
	{"id": "dryoid", "name": "Dryoid", "g": 360},
	{"id": "elfin", "name": "Elfin", "g": 300},
	{"id": "elico", "name": "Elico", "g": 310},
	{"id": "farbros", "name": "Farbros", "g": 320},
	{"id": "goblin_ball", "name": "Goblin Ball", "g": 330},
	{"id": "hades", "name": "Hades", "g": 340},
	{"id": "hyper_dragonoid", "name": "Hyper Dragonoid", "g": 350},
	{"id": "ingram", "name": "Ingram", "g": 360},
	{"id": "jelldon", "name": "Jelldon", "g": 300},
	{"id": "knight_percival", "name": "Knight Percival", "g": 310},
	{"id": "mac_spider", "name": "MAC Spider", "g": 320},
	{"id": "macubass", "name": "Macubass", "g": 330},
	{"id": "magma_wilda", "name": "Magma Wilda", "g": 340},
	{"id": "master_ingram", "name": "Master Ingram", "g": 350},
	{"id": "mega_brontes", "name": "Mega Brontes", "g": 360},
	{"id": "mega_nemus", "name": "Mega Nemus", "g": 300},
	{"id": "minx_elfin", "name": "Minx Elfin", "g": 310},
	{"id": "neo_dragonoid", "name": "Neo Dragonoid", "g": 320},
	{"id": "percival", "name": "Percival", "g": 330},
	{"id": "premo_vulcan", "name": "Premo Vulcan", "g": 340},
	{"id": "saint_nemus", "name": "Saint Nemus", "g": 350},
	{"id": "thunder_wilda", "name": "Thunder Wilda", "g": 360},
	{"id": "vexos_dragonoid", "name": "Vexos Dragonoid", "g": 300},
	{"id": "viper_helios", "name": "Viper Helios", "g": 310},
]
const ATTRIBUTES = ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]
const DEFAULT_SELECTION = [0, 1, 2]
const DEFAULT_ATTRIBUTES = ["Pyrus", "Pyrus", "Ventus"]
const OPPONENT_SELECTIONS = [[3, 4, 5], [3, 1, 5], [3, 0, 5]]
const OPPONENT_ATTRIBUTES = [
	["Darkus", "Aquos", "Subterra"],
	["Darkus", "Pyrus", "Subterra"],
	["Darkus", "Haos", "Subterra"],
]


static func normalize_selection(selection: Array) -> Array[int]:
	var result: Array[int] = []
	if selection.size() == 3:
		for value: Variant in selection:
			# JSON numbers arrive as floats; only whole indices are accepted.
			var valid_number: bool = typeof(value) == TYPE_INT or (
				typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value)
			)
			if not valid_number or value < 0 or value >= CREATURES.size():
				result.clear()
				break
			var index: int = int(value)
			if result.has(index):
				result.clear()
				break
			result.append(index)
	if result.size() != 3:
		result.assign(DEFAULT_SELECTION)
	return result


static func normalize_attributes(attributes: Array) -> Array[String]:
	var result: Array[String] = []
	if attributes.size() == 3:
		for value: Variant in attributes:
			if typeof(value) != TYPE_STRING or not ATTRIBUTES.has(value):
				result.clear()
				break
			result.append(value)
	if result.size() != 3:
		result.assign(DEFAULT_ATTRIBUTES)
	return result


static func make_team(selection: Array, attributes: Array, owner: int = 0, canonical: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if owner != 0 and owner != 1:
		return result
	var selected: Array[int] = normalize_selection(selection)
	var selected_attributes: Array[String] = normalize_attributes(attributes)
	for position in range(3):
		var creature: Dictionary = CREATURES[selected[position]]
		result.append({
			"id": "p%d_%s" % [owner, creature["id"]],
			"name": creature["name"],
			"attribute": selected_attributes[position],
			"g": creature["g"],
			"used": false,
		})
	return canonicalize_team(result) if canonical else result


static func make_opponent(stage: int, canonical: bool = false) -> Array[Dictionary]:
	if canonical:
		return make_anime_opponent(stage)
	var safe_stage: int = clampi(stage, 0, OPPONENT_SELECTIONS.size() - 1)
	var result: Array[Dictionary] = make_team(
		OPPONENT_SELECTIONS[safe_stage], OPPONENT_ATTRIBUTES[safe_stage], 1
	)
	for creature: Dictionary in result:
		creature["g"] = int(creature["g"]) + safe_stage * 20
	return result


static func normalize_anime_attributes(selection: Array, attributes: Array) -> Array[String]:
	var selected: Array[int] = normalize_selection(selection)
	var requested: Array[String] = normalize_attributes(attributes)
	var result: Array[String] = []
	for position in range(3):
		var creature: Dictionary = CREATURES[selected[position]]
		var native_profile: Dictionary = CanonicalCatalog.resolve(str(creature.id), requested[position], int(creature.g))
		result.append(str(native_profile.attribute))
	return result


static func normalize_selection_attributes(selection: Array, attributes: Array) -> Array[String]:
	return normalize_anime_attributes(selection, attributes)


static func make_anime_team(selection: Array, attributes: Array, owner: int = 0) -> Array[Dictionary]:
	return canonicalize_team(make_team(selection, attributes, owner))


static func make_anime_opponent(stage: int = 0) -> Array[Dictionary]:
	# Source-recorded powers must not acquire the Wii tournament's +20 G scaling.
	var safe_stage: int = clampi(stage, 0, OPPONENT_SELECTIONS.size() - 1)
	return make_anime_team(OPPONENT_SELECTIONS[safe_stage], OPPONENT_ATTRIBUTES[safe_stage], 1)


static func canonicalize_team(team: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate: Variant in team:
		if not candidate is Dictionary:
			continue
		var unit: Dictionary = candidate.duplicate(true)
		var species_id: String = str(unit.get("species_id", unit.get("id", "")))
		if species_id.begins_with("p0_") or species_id.begins_with("p1_"):
			species_id = species_id.substr(3)
		var fallback_g: int = int(unit.get("g", 0))
		for creature: Dictionary in CREATURES:
			if str(creature.id) == species_id:
				# Recanonicalizing a runtime team must restore its conditional base,
				# not convert earlier ability bonuses into a new starting value.
				fallback_g = int(creature.g)
				break
		var native_profile: Dictionary = CanonicalCatalog.resolve(species_id, str(unit.get("attribute", "Pyrus")), fallback_g)
		unit["species_id"] = species_id
		unit["attribute"] = native_profile.attribute
		unit["g"] = native_profile.g
		for field: String in ["canonical_g", "g_verified", "g_note", "g_source_confidence", "attribute_locked", "attribute_verified", "native_attribute", "unsupported_native_attribute", "variant_label", "display_identity", "brawler"]:
			unit[field] = native_profile[field]
		unit["canonical_source_url"] = native_profile.source_url
		unit["canonical_excerpt"] = native_profile.excerpt
		result.append(unit)
	return result

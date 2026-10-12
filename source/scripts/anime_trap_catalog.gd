extends RefCounted
## Trap cards come from the independent Anime Style source, rather than the
## Bloxugan ability catalog. Battle-only deployment is a local 0.9 adaptation.

const PROFILE_PATH: String = "res://assets/imported/trap_profiles.json"
const ATTRIBUTES: Array[String] = ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]

# Each operator must execute the complete printed effect before it is enabled.
# Exact source descriptions and provenance remain attached to the profile.
const EFFECTS: Dictionary = {
	"fortress_rain": {"type": "owner_highest"},
	"metalfencer_valkyrie": {"type": "permanent_gain", "amount": 50, "special_amount": 100, "species": "ViperHelios"},
	"fly_enemy": {"type": "double_losses"},
	"wired_hybrid": {"type": "double_gains", "permanent_species": "Altair"},
	"zoack_blinding": {"type": "block_gains"},
	"piercian_bunker": {"type": "permanent_battle_changes"},
	"baliton_roller": {"type": "copy_open_gate"},
	"el_condor_mysticism": {"type": "coin_repeat_gate"},
	"dynamo_dimension": {"type": "opposite_attributes"},
	"flash_fly_arrow": {"type": "forced_swap"},
	"hexados_drill": {"type": "drill_move", "amount": 50},
	"hexstar_booster": {"type": "extra_roll_return"},
	"hylash_thunder": {"type": "transfer_resolved_changes"},
	"pythantus_lash": {"type": "activation_drain", "amount": 100},
	"scorpion_reflector": {"type": "reflect_first"},
	"epsilon_snail": {"type": "additional_attributes", "from": "Aquos", "attributes": ["Subterra", "Haos", "Pyrus"]},
	"theta_ripple": {"type": "defeated_copy", "amount": 100, "attributes": ["Darkus", "Ventus"]},
}


static func supports() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(PROFILE_PATH):
		return result
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if not parsed is Dictionary or not parsed.get("entries", []) is Array:
		return result
	for value: Variant in parsed.entries:
		if not value is Dictionary:
			continue
		var profile: Dictionary = value.duplicate(true)
		var source_effect: Dictionary = profile.get("effect", {})
		var effect_id: String = str(source_effect.get("id", ""))
		profile["source_effect"] = source_effect.duplicate(true)
		profile["effect"] = EFFECTS.get(effect_id, {}).duplicate(true)
		profile["supported"] = bool(source_effect.get("verified", false)) and not profile.effect.is_empty()
		profile["title"] = str(source_effect.get("title", source_effect.get("name", profile.get("name", ""))))
		profile["description"] = str(source_effect.get("text", ""))
		profile["description_ru"] = str(source_effect.get("text_ru", profile.get("description_ru", "")))
		profile["own_g_status"] = str(profile.get("own_g_status", "unknown"))
		result.append(profile)
	return result


static func get_support(identity: String) -> Dictionary:
	for profile: Dictionary in supports():
		if str(profile.get("id", "")) == identity:
			return profile.duplicate(true)
	return {}


static func normalize_selection(selection: Variant) -> Dictionary:
	if selection == null or (selection is Dictionary and selection.is_empty()):
		return {}
	if not selection is Dictionary:
		return {}
	var profile: Dictionary = get_support(str(selection.get("id", "")))
	if profile.is_empty() or str(profile.get("category", "")) != "trap" or not bool(profile.get("supported", false)):
		return {}
	var native: Array = profile.get("playable_attributes", profile.get("attributes", []))
	var attribute: String = str(selection.get("attribute", profile.get("attribute", "")))
	if not ATTRIBUTES.has(attribute) or not native.has(attribute):
		return {}
	profile["attribute"] = attribute
	return profile


static func valid_selection(selection: Variant) -> bool:
	if selection == null or (selection is Dictionary and selection.is_empty()):
		return true
	return not normalize_selection(selection).is_empty()


static func compatible_caster(support: Dictionary, unit: Dictionary) -> bool:
	return str(support.get("attribute", "")) == str(unit.get("attribute", ""))

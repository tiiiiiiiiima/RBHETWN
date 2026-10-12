extends SceneTree
## Source-backed card data and valid local anime-duel loadout selection.

const Catalog = preload("res://scripts/anime_card_catalog.gd")
var checks: int = 0
var failures: Array[String] = []


func _init() -> void:
	_source_checks()
	_effect_checks()
	_command_gate_checks()
	_loadout_checks()
	_default_checks()
	print("ANIME CARD CATALOG CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _source_checks() -> void:
	_check(Catalog.GATES.size() == 70 and Catalog.ABILITIES.size() == 20, "Supported subset contains sixty Attribute Gates, ten Command Gates and twenty abilities")
	var identities: Dictionary = {}
	for card: Dictionary in Catalog.GATES + Catalog.ABILITIES:
		_check(not identities.has(card.id) and card.key == card.id, "Source cards have unique stable identities")
		identities[card.id] = true
		_check(card.source.verified and card.source.url == "https://bloxugan.info/json/cards.json?=v14" and str(card.source.path).begins_with("$[0]."), "Every playable descriptor records its verified source and structural path")
		_check(not str(card.description).is_empty() and not str(card.description_ru).is_empty(), "Every card retains source English and a Russian explanation")
		_check(card.limit == card.source.raw_stats.limit and not card.has("cost") and not card.has("mana"), "Source copy limits are retained without inventing meanings for source statistics")
	var attribute_gate_count: int = 0
	var attributes_found: Dictionary = {}
	var source_hsp: Dictionary = {30: 50, 50: 75, 70: 100, 80: 150, 100: 200, 120: 250, 150: 400, 180: 800, 200: 1250, 250: 3000}
	for gate: Dictionary in Catalog.GATES:
		if gate.type != "agc":
			continue
		attribute_gate_count += 1
		attributes_found[gate.attribute] = int(attributes_found.get(gate.attribute, 0)) + 1
		var amount: int = gate.effect.amount
		var source_limit: int = 1 if amount == 250 else 2
		_check(gate.limit == source_limit and gate.source.raw_stats == {"gcp": 0, "hsp": source_hsp.get(amount, -1), "limit": source_limit}, "Every attribute gate retains the exact source tier, hsp and copy limit")
		_check(gate.boosts.size() == 1 and int(gate.boosts.get(gate.attribute, 0)) == amount and gate.title == "%s %d" % [gate.attribute, amount], "Attribute gate title, printed amount and matching-only bonus agree")
	_check(attribute_gate_count == 60 and attributes_found == {"Aquos": 10, "Darkus": 10, "Haos": 10, "Pyrus": 10, "Subterra": 10, "Ventus": 10}, "All ten printed bonus tiers exist for each of the six attributes")
	var alpha: Dictionary = Catalog.get_ability("alpha_blaster")
	_check(alpha.description == "If Leonidas is in battle, it gains +200 G's; if that battle is on an opposing Gate Card, Leonidas gains +250 G's instead.", "Alpha Blaster uses current English source rather than the stale two-hundred-only translation")
	_check(alpha.description_ru.contains("250") and alpha.source.raw_stats.gpd == "+30" and alpha.source.raw_stats.masteryLevel == ["27"], "Opposing gate translation and unmodified mastery/gpd are present")
	var fire_storm: Dictionary = Catalog.get_ability("fire_storm")
	_check(fire_storm.source.raw_stats.gpd == "60" and fire_storm.source.raw_stats.masteryLevel == ["35", "45"], "Source strings and mastery arrays remain unchanged")
	_check(Catalog.get_ability("super_shard").source.raw_stats["ace-gpd"] == "+35", "Additional source statistics are preserved rather than discarded")
	var copy: Dictionary = Catalog.get_ability("alpha_blaster")
	copy.effect.amount = 1
	copy.source.raw_stats.gpd = "changed"
	_check(Catalog.get_ability("alpha_blaster").effect.amount == 200 and Catalog.get_ability("alpha_blaster").source.raw_stats.gpd == "+30", "Retrieving a card returns an independent deep copy")
	_check(Catalog.get_gate("unknown").is_empty() and Catalog.get_ability("unknown").is_empty(), "Unknown identifiers cannot silently substitute a different card")


func _effect_checks() -> void:
	var counts: Dictionary = {}
	for card: Dictionary in Catalog.ABILITIES:
		var kind: String = card.effect.type
		counts[kind] = int(counts.get(kind, 0)) + 1
	_check(counts == {"correlation": 6, "counter": 4, "nullify": 4, "transfer": 3, "gain": 2, "enemy_loss": 1}, "The supported effect families cover all twenty chosen abilities")
	for card: Dictionary in Catalog.ABILITIES:
		if card.effect.type == "correlation":
			_check(card.effect.amount == 50 and card.effect.opposing_amount == 150 and card.effect.allied_amount == 100 and card.effect.pair == card.attribute and card.limit == 3, "Correlation retains default, opposing-pair and allied-pair amounts")
		elif card.effect.type == "counter":
			_check(card.effect.cannot_counter_immediate and card.description.contains("cannot be activated in response to an immediate Ability Card"), "All four counters preserve their immediate-card restriction")
		elif card.effect.type == "nullify" and card.id != "face_of_joy":
			_check(card.effect.cannot_open_in_response, "The printed attribute nullifiers disallow opening the gate in response")
	for id: String in ["face_of_grief", "face_of_joy", "face_of_rage"]:
		var face: Dictionary = Catalog.get_ability(id)
		_check(face.immediate and face.species == "Fourtress" and face.source.path.contains(".fourtress["), "Immediate faces recover Fourtress from the source's enclosing species path")
	_check(Catalog.get_ability("face_of_rage").effect.amount == 50 and Catalog.get_ability("fire_tornado").effect.amount == 100 and Catalog.get_ability("lightning_tornado").effect.amount == 100, "Transfers use their printed amounts")
	_check(Catalog.get_ability("fire_storm").species == "Skyress" and Catalog.get_ability("fire_storm").effect.amount == 125, "Fire Storm is restricted to Skyress with the printed one-hundred-twenty-five gain")
	_check(Catalog.get_ability("alpha_blaster").effect.amount == 200 and Catalog.get_ability("alpha_blaster").effect.opposing_amount == 250 and Catalog.get_ability("alpha_blaster").effect.requires_battle, "Alpha Blaster distinguishes own and opposing gates in battle")
	_check(Catalog.get_ability("super_shard").species == "Juggernoid" and Catalog.get_ability("super_shard").effect.amount == 75, "Super Shard has its recovered caster and printed enemy loss")


func _loadout_checks() -> void:
	var gates: Array[String] = Catalog.default_gate_loadout()
	var abilities: Array[String] = Catalog.default_ability_loadout()
	_check(Catalog.valid_gate_loadout(gates) and Catalog.valid_ability_loadout(abilities), "Default loadouts have exact required sizes and legal source copy counts")
	_check(not Catalog.valid_gate_loadout([]) and not Catalog.valid_ability_loadout([]), "Empty loadouts are rejected")
	_check(not Catalog.valid_gate_loadout(["pyrus_50", "pyrus_50", "pyrus_50", "aquos_50", "aquos_50", "haos_50"]), "A third attribute gate violates its source limit of two")
	_check(not Catalog.valid_gate_loadout(["pyrus_250", "pyrus_250", "aquos_50", "darkus_50", "haos_50", "ventus_50"]), "The strongest attribute gate obeys its lower single-copy source limit")
	_check(not Catalog.valid_gate_loadout(["energy_merge", "energy_merge", "aquos_50", "darkus_50", "haos_50", "ventus_50"]), "Automatic Energy Merge obeys its single-copy source limit")
	var invalid: Array = []
	for id: String in abilities:
		invalid.append(id)
	invalid[0] = "unknown"
	_check(not Catalog.valid_ability_loadout(invalid), "Unknown card IDs cannot enter an otherwise valid deck")
	invalid[0] = null
	_check(not Catalog.valid_ability_loadout(invalid), "Nonstring saved entries cannot enter a deck")
	invalid = abilities.duplicate()
	invalid[0] = "aqua_guardian"
	invalid[1] = "aqua_guardian"
	_check(not Catalog.valid_ability_loadout(invalid), "A second single-copy counter violates its source limit")
	abilities.pop_back()
	_check(not Catalog.valid_ability_loadout(abilities), "Nine cards cannot silently satisfy the required ten-card loadout")
	gates.append("pyrus_50")
	_check(not Catalog.valid_gate_loadout(gates), "Seven cards cannot silently satisfy the required six-card gate loadout")


func _default_checks() -> void:
	var team: Array = [
		{"name": "Leonidas", "attribute": "pyrus"},
		{"name": "Preyas", "attribute": "Aquos"},
		{"name": "Skyress", "attribute": "VENTUS"}
	]
	var gates: Array[String] = Catalog.default_gate_loadout(team)
	_check(Catalog.valid_gate_loadout(gates), "A three-attribute team receives a valid six-gate deck")
	var matching_gates: bool = true
	var command_count: int = 0
	var command_types: Array[String] = []
	for id: String in gates:
		var card: Dictionary = Catalog.get_gate(id)
		if card.type == "agc":
			matching_gates = matching_gates and card.attribute in ["Pyrus", "Aquos", "Ventus"] and card.effect.amount in [50, 70]
		else:
			command_count += 1
			command_types.append(str(card.effect.type))
	_check(matching_gates and command_count == 4, "Default gates mix moderate matching Attribute Gates with four strategic Command Gates")
	_check(command_types.has("energy_merge") and command_types.has("peacemaker") and command_types.has("hazard") and command_types.has("delta"), "Default gate selection exposes automatic transfer, attribute change, conditional loss and recall")
	var abilities: Array[String] = Catalog.default_ability_loadout(team)
	var compatible: bool = true
	for id: String in abilities:
		var allowed: bool = false
		for unit: Dictionary in team:
			allowed = allowed or Catalog.compatible_caster(Catalog.get_ability(id), unit)
		compatible = compatible and allowed
	_check(Catalog.valid_ability_loadout(abilities) and compatible, "Defaults prefer legal cards that the selected team can cast")
	_check(abilities.has("alpha_blaster") and abilities.has("fire_storm"), "Default abilities include compatible Leonidas and Skyress special cards")
	_check(not Catalog.compatible_caster(Catalog.get_ability("face_of_rage"), {"name": "Dragonoid", "attribute": "Pyrus"}) and Catalog.compatible_caster(Catalog.get_ability("face_of_rage"), {"species": "FOURTRESS", "attribute": "Darkus"}), "Species restrictions cannot be bypassed by matching an unrelated attribute")
	_check(Catalog.compatible_caster(Catalog.get_ability("correlation_pyrus_subterra"), {"name": "Gorem", "attribute": "Subterra"}) and not Catalog.compatible_caster(Catalog.get_ability("correlation_pyrus_subterra"), {"name": "Gorem", "attribute": "Haos"}), "Either printed correlation attribute can cast it, other attributes cannot")
	for sparse_team: Array in [[], [{"name": "Gorem", "attribute": "Subterra"}], [null, {"attribute": "invalid"}]]:
		_check(Catalog.valid_gate_loadout(Catalog.default_gate_loadout(sparse_team)) and Catalog.valid_ability_loadout(Catalog.default_ability_loadout(sparse_team)), "Sparse or invalid teams still receive structurally legal source-limited defaults")
	_check(Catalog.normalize_attribute("  dArKuS  ") == "Darkus" and Catalog.normalize_attribute("unknown") == "" and Catalog.normalize_attribute(null) == "", "Attribute normalization accepts valid case variants and rejects invalid input")


func _command_gate_checks() -> void:
	var ids: Array[String] = ["energy_merge", "aquos_hazard", "darkus_hazard", "haos_hazard", "pyrus_hazard", "subterra_hazard", "ventus_hazard", "positive_delta", "negative_delta", "peacemaker"]
	for id: String in ids:
		var card: Dictionary = Catalog.get_gate(id)
		var is_delta: bool = id in ["positive_delta", "negative_delta"]
		var is_energy: bool = id == "energy_merge"
		var source_limit: int = 1 if is_delta or is_energy else 2
		var hsp: int = 675 if is_energy else (250 if id == "peacemaker" else 300)
		_check(card.type == "cogc" and card.boosts.is_empty() and card.source.raw_stats == {"gcp": 2 if is_delta else 1, "hsp": hsp, "limit": source_limit}, "Command gates retain exact source statistics and do not invent elemental bonuses")
	var energy: Dictionary = Catalog.get_gate("energy_merge")
	_check(energy.effect == {"type": "energy_merge", "amount": 125, "auto_open": true}, "Energy Merge automatically transfers the printed one-hundred-twenty-five amount")
	_check(energy.description == "Automatically opens once a Bakugan from each side is on the Gate Card, transferring 125 G's from the last Bakugan thrown onto it to the first Bakugan that was on it.", "Energy Merge keeps the source activation and first/last ordering")
	for attribute: String in Catalog.ATTRIBUTES:
		var hazard: Dictionary = Catalog.get_gate(attribute.to_lower() + "_hazard")
		_check(hazard.effect == {"type": "hazard", "attribute": attribute} and hazard.description == "All Bakugan on the Gate Card are changed to %s." % attribute, "Each Hazard changes all standing creatures to its exact printed attribute")
	_check(Catalog.get_gate("positive_delta").effect == {"type": "delta", "amount": 200, "pair": ["Pyrus", "Aquos", "Haos"]}, "Positive Delta targets the three printed opposing attributes")
	_check(Catalog.get_gate("negative_delta").effect == {"type": "delta", "amount": 200, "pair": ["Darkus", "Subterra", "Ventus"]}, "Negative Delta targets the complementary three printed opposing attributes")
	_check(Catalog.get_gate("positive_delta").description_ru.contains("Иначе 200 G теряет твой бакуган") and Catalog.get_gate("negative_delta").description_ru.contains("Иначе 200 G теряет твой бакуган"), "Both Delta translations preserve the owner's loss when the opponent does not match")
	_check(Catalog.get_gate("peacemaker").effect == {"type": "peacemaker"} and Catalog.get_gate("peacemaker").description == "All Bakugan on the Gate Card are returned to their owners' hands.", "Peacemaker returns all standing creatures without inventing capture or elimination")

extends SceneTree
## Trap identity, scoped G metadata, source-face provenance and safe selection.
## Combat operators are exercised separately by test_trap_duel_rules.gd.

const Traps = preload("res://scripts/anime_trap_catalog.gd")
const Assets = preload("res://scripts/asset_catalog.gd")
const Cards = preload("res://scripts/source_card_library.gd")
const EXPECTED_ANIME: Dictionary = {
	"dynamo": "Haos", "falcon_fly": "Darkus", "fortress": "Darkus",
	"hylash": "Ventus", "wired": "Ventus",
	"tripod_epsilon": "Aquos", "tripod_theta": "Aquos",
}

var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profiles: Array[Dictionary] = Traps.supports()
	_check(profiles.size() == 18, "The model collection retains all eighteen support profiles")
	var identities: Dictionary = {}
	var trap_count: int = 0
	var support_count: int = 0
	var verified_anime_count: int = 0
	for profile: Dictionary in profiles:
		var identity: String = str(profile.get("id", ""))
		var name: String = str(profile.get("name", ""))
		_check(not identity.is_empty() and not identities.has(identity), "Support identities are unique and stable")
		identities[identity] = true
		_check(not Assets.get_entry(name).is_empty(), "Every support profile has a real imported model identity")
		var native: Array = profile.get("native_attributes", [])
		var available: Array[String] = Assets.available_attributes(name, "toy")
		_check(not native.is_empty(), "Imported support textures retain their native attribute inventory")
		for attribute: Variant in native:
			_check(available.has(str(attribute)), "Profile colors correspond to actual native model textures")
		var canonical: Array = profile.get("canonical_attributes", [])
		if EXPECTED_ANIME.has(identity):
			verified_anime_count += 1
			_check(canonical == [EXPECTED_ANIME[identity]], "Named anime traps retain only the attribute established by the accessible reference")
			_check(profile.get("anime_attributes", []) == canonical, "Canonical selection agrees with the verified anime metadata")
			_check(str(profile.get("attribute", "")) == str(EXPECTED_ANIME[identity]), "The default trap attribute is the verified named anime variant")
		else:
			_check(canonical.is_empty(), "Unverified anime trap attributes are not inferred from toy textures")
		_check(profile.get("anime_g", 0) == null and profile.get("own_g", 0) == null and profile.get("g", 0) == null, "Unknown numerical anime G remains null rather than an invented zero")
		_check(str(profile.get("anime_g_status", "")) == "unknown", "Missing anime G is explicitly marked unknown")
		if str(profile.get("category", "")) == "trap":
			trap_count += 1
			_check(str(profile.get("own_g_status", "")) == "no_g_in_tts" and profile.get("source_format_has_own_g", true) == false, "G-less support is scoped to the source community rules")
			_check(bool(profile.get("supported", false)), "Every visually verified Trap Ability has an enabled complete runtime operator")
			var source_effect: Dictionary = profile.get("source_effect", {})
			_check(bool(source_effect.get("verified", false)) and not str(source_effect.get("id", "")).is_empty(), "A playable trap retains the verified source-card identity")
			_check(str(profile.get("description", "")) == str(source_effect.get("text", "")), "The complete original printed effect survives runtime normalization")
			_check(str(profile.get("description", "")) == str(profile.get("source_excerpt", "")), "Runtime descriptions agree with the auditable source excerpt")
			var card: Dictionary = Cards.metadata(str(source_effect.get("card_key", "")))
			_check(not card.is_empty(), "Each trap refers to a real collected card face")
			_check(str(source_effect.get("image_path", "")) == str(card.get("path", "")) and ResourceLoader.exists(str(card.get("path", ""))), "Each trap face is packaged as the matching offline texture")
			_check(str(source_effect.get("source_sha256", "")).length() == 64 and source_effect.get("source_sha256") == card.get("source_sha256"), "The trap retains the original downloaded-source hash")
			_check(str(source_effect.get("source_pixel_sha256", "")).length() == 64 and source_effect.get("source_pixel_sha256") == card.get("pixel_sha256"), "The trap retains its exact extracted-face pixel hash")
			var selection: Dictionary = {"id": identity, "attribute": str(profile.get("attribute", ""))}
			_check(Traps.valid_selection(selection), "The documented native/anime default is a valid battle trap selection")
			var normalized: Dictionary = Traps.normalize_selection(selection)
			_check(str(normalized.get("category", "")) == "trap" and bool(normalized.get("supported", false)), "Normalized battle selections remain real supported traps")
			_check(Traps.compatible_caster(normalized, {"attribute": str(selection.attribute)}), "A selected trap can be cast by its matching attribute")
			_check(not Traps.compatible_caster(normalized, {"attribute": "invalid"}), "Invalid caster attributes cannot activate a trap")
		else:
			support_count += 1
			_check(identity == "shadow_wing" and not bool(profile.get("supported", true)), "Shadow Wing remains paired collection support rather than a Trap Ability")
			_check(str(profile.get("own_g_status", "")) == "unknown", "Unverified paired support does not inherit the source trap G rule")
			_check(not Traps.valid_selection({"id": identity, "attribute": "Ventus"}), "Paired support cannot enter the battle trap slot")
	_check(trap_count == 17 and support_count == 1 and verified_anime_count == 7, "The catalog distinguishes seventeen traps, one paired support and seven verified anime attributes")
	_check(Traps.valid_selection(null) and Traps.valid_selection({}), "A team may intentionally leave its optional trap slot empty")
	_check(not Traps.valid_selection([]) and not Traps.valid_selection("fortress"), "Malformed saved selections cannot become playable profiles")
	_check(not Traps.valid_selection({"id": "missing", "attribute": "Darkus"}), "Unknown identities are rejected")
	_check(not Traps.valid_selection({"id": "fortress", "attribute": "Pyrus"}), "Pyrus texture does not replace the named Darkus mechanical anime Fortress")
	_check(not Traps.valid_selection({"id": "dynamo", "attribute": "Darkus"}), "A confirmed named trap cannot use an unverified recolor in anime combat")
	var forged: Dictionary = Traps.normalize_selection({"id": "fortress", "attribute": "Darkus", "own_g": 9999, "supported": false})
	_check(forged.get("own_g", 0) == null and bool(forged.get("supported", false)), "Saved data cannot forge trap G or override supported source metadata")
	var changed: Dictionary = Traps.get_support("fortress")
	changed["canonical_attributes"] = ["Pyrus"]
	_check(Traps.get_support("fortress").get("canonical_attributes", []) == ["Darkus"], "Callers cannot mutate the catalog's canonical identity")
	if failures == 0:
		print("PASS: %d anime trap catalog checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d anime trap catalog checks failed" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

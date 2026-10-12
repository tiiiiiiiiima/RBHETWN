extends SceneTree
## Selection, provenance and unknown-stat safety for native anime profiles.
const CanonicalCatalog = preload("res://scripts/canonical_catalog.gd")
const Roster = preload("res://scripts/roster.gd")
var checks: int = 0
var failures: Array[String] = []


func _init() -> void:
	_resolver_rules()
	_roster_and_manifest()
	print("CANONICAL 0.9 CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _record(attribute: String, power: Variant, baseline: bool = false) -> Dictionary:
	# These synthetic values exercise ambiguity handling; they are not source
	# assertions and are never written into the shipping anime manifest.
	return {"attribute": attribute, "initial_g": power, "is_baseline": baseline,
		"source_url": "https://example.test/fixture", "excerpt": "test fixture", "confidence": "verified"}


func _resolver_rules() -> void:
	var bound: Dictionary = {"id": "fixture_partner", "name": "Fixture partner", "character_bound": true,
		"primary_attribute": "Pyrus", "attributes": ["Pyrus"], "initial_g": 450,
		"source_url": "https://example.test/fixture", "excerpt": "test fixture", "confidence": "verified"}
	var partner: Dictionary = CanonicalCatalog.describe_profile(bound, "Aquos", 320)
	_check(partner.attribute == "Pyrus" and partner.attribute_locked, "A character-bound partner's saved cosmetic attribute becomes its native starting attribute")
	_check(partner.g == 450 and partner.canonical_g == 450 and partner.g_verified, "A source-recorded partner power replaces conditional balance")
	_check(partner.source_url == bound.source_url and partner.excerpt == bound.excerpt, "A displayed canonical value retains its actual provenance")
	var switching: Dictionary = bound.duplicate(true)
	switching.attributes = ["Pyrus", "Aquos", "Darkus"]
	switching.attribute_changer = true
	var changer: Dictionary = CanonicalCatalog.describe_profile(switching, "Darkus", 320)
	_check(changer.attribute == "Darkus" and not changer.attribute_locked, "A documented attribute-changing partner retains its source-recorded attribute choices")
	_check(not changer.g_verified, "An attribute changer's secondary form does not inherit an unrecorded power from its primary form")
	var generic: Dictionary = {"id": "fixture_generic", "character_bound": false,
		"attributes": CanonicalCatalog.ATTRIBUTES.duplicate(), "initial_g": null,
		"per_attribute_variants": [_record("Aquos", 350, true), _record("Pyrus", 250, true)]}
	var aquos: Dictionary = CanonicalCatalog.describe_profile(generic, "Aquos", 340)
	var pyrus: Dictionary = CanonicalCatalog.describe_profile(generic, "Pyrus", 340)
	_check(aquos.attribute == "Aquos" and pyrus.attribute == "Pyrus" and not aquos.attribute_locked, "A generic species retains individual attribute choices")
	_check(aquos.g == 350 and pyrus.g == 250 and aquos.g_verified and pyrus.g_verified, "Generic individuals use the selected attribute's recorded power")
	var physical_generic: Dictionary = generic.duplicate(true)
	physical_generic.attributes = ["Aquos"]
	physical_generic.physical_attributes = CanonicalCatalog.ATTRIBUTES.duplicate()
	physical_generic.attribute_confidence = "verified"
	var physical_pyrus: Dictionary = CanonicalCatalog.describe_profile(physical_generic, "Haos", 340)
	_check(physical_pyrus.attribute == "Haos" and not physical_pyrus.attribute_verified, "Generic imported colours remain available without being labelled anime-confirmed")
	var missing: Dictionary = CanonicalCatalog.describe_profile(generic, "Ventus", 340)
	_check(missing.g == 340 and missing.canonical_g == null and not missing.g_verified and "условная" in missing.g_note, "Missing statistics remain explicitly conditional rather than inheriting another attribute's value")
	var conflicting: Dictionary = generic.duplicate(true)
	conflicting.per_attribute_variants = [_record("Aquos", 350), _record("Aquos", 450)]
	var ambiguous: Dictionary = CanonicalCatalog.describe_profile(conflicting, "Aquos", 340)
	_check(not ambiguous.g_verified and ambiguous.g == 340, "Different individuals with no selected baseline do not become a random species-wide power")
	conflicting.per_attribute_variants[1].is_baseline = true
	_check(CanonicalCatalog.describe_profile(conflicting, "Aquos", 340).g == 450, "A explicitly documented baseline selects a specific individual among varying powers")
	var duplicate: Dictionary = generic.duplicate(true)
	duplicate.per_attribute_variants = [_record("Aquos", 350), _record("Aquos", 350)]
	_check(CanonicalCatalog.describe_profile(duplicate, "Aquos", 340).g == 350, "Matching references to one starting power are not falsely marked ambiguous")
	var unsupported: Dictionary = {"character_bound": true, "primary_attribute": "White", "attributes": ["White"],
		"initial_g": 800, "source_url": "https://example.test/fixture", "confidence": "verified"}
	var white: Dictionary = CanonicalCatalog.describe_profile(unsupported, "Haos", 340)
	_check(white.unsupported_native_attribute and not white.attribute_locked and not white.g_verified, "An unsupported anime attribute is disclosed rather than relabelled as a verified six-attribute form")
	var unverified: Dictionary = bound.duplicate(true)
	unverified.confidence = "unknown"
	_check(not CanonicalCatalog.describe_profile(unverified, "Aquos", 320).g_verified, "A numeric guess without recorded confidence cannot appear as verified G")
	unverified = bound.duplicate(true)
	unverified.g_confidence = "unknown"
	var attribute_only: Dictionary = CanonicalCatalog.describe_profile(unverified, "Aquos", 320)
	_check(attribute_only.attribute_verified and not attribute_only.g_verified, "Independently confirmed native attributes do not turn unknown G into verified power")
	unverified = bound.duplicate(true)
	unverified.source_url = ""
	_check(not CanonicalCatalog.describe_profile(unverified, "Aquos", 320).g_verified, "A number without a source cannot appear as verified G")
	unverified.source_url = null
	_check(not CanonicalCatalog.describe_profile(unverified, "Aquos", 320).g_verified, "A null source is not converted to a printable fake URL")
	unverified = bound.duplicate(true)
	unverified.initial_g = 450.5
	_check(not CanonicalCatalog.describe_profile(unverified, "Aquos", 320).g_verified, "Noninteger source values are rejected rather than rounded into G")
	var copy: Dictionary = partner.profile
	copy.primary_attribute = "Darkus"
	_check(bound.primary_attribute == "Pyrus", "Resolver descriptions isolate metadata mutations")


func _roster_and_manifest() -> void:
	CanonicalCatalog.reload()
	_check(CanonicalCatalog.issues().is_empty(), "The shipped source manifest loads without structural errors")
	_check(CanonicalCatalog.profiles().size() == Roster.CREATURES.size(), "Every selectable species has an explicit source profile, including unknown cases")
	var valid: bool = true
	var unknown_is_conditional: bool = true
	var partners_corrected: bool = true
	var generic_choices_preserved: bool = true
	for index: int in range(Roster.CREATURES.size()):
		var creature: Dictionary = Roster.CREATURES[index]
		var native_profile: Dictionary = CanonicalCatalog.profile(str(creature.id))
		valid = valid and not native_profile.is_empty() and str(native_profile.id) == str(creature.id)
		for attribute: String in Roster.ATTRIBUTES:
			var described: Dictionary = CanonicalCatalog.resolve(str(creature.id), attribute, int(creature.g))
			valid = valid and Roster.ATTRIBUTES.has(described.attribute) and described.g >= 0
			if not described.g_verified:
				unknown_is_conditional = unknown_is_conditional and described.canonical_g == null and "условная" in described.g_note
			if described.attribute_locked:
				partners_corrected = partners_corrected and described.attribute == described.native_attribute
			elif CanonicalCatalog.allowed_attributes(str(creature.id)).has(attribute):
				generic_choices_preserved = generic_choices_preserved and described.attribute == attribute
	_check(valid, "All source profiles resolve to playable attributes and nonnegative power")
	_check(unknown_is_conditional, "Every unsourced shipping value is explicitly conditional")
	_check(partners_corrected, "All bound shipping characters correct incompatible saved colours")
	_check(generic_choices_preserved, "Unbound shipping species retain all recorded selectable attributes")
	var drago: Dictionary = CanonicalCatalog.resolve("dragonoid", "Aquos", 320)
	var ingram: Dictionary = CanonicalCatalog.resolve("ingram", "Pyrus", 360)
	_check(drago.attribute == "Pyrus" and drago.attribute_locked and drago.attribute_verified, "The shipped original Drago is the source-recorded Pyrus partner")
	_check(ingram.attribute == "Ventus" and ingram.attribute_locked and ingram.attribute_verified, "The shipped Ingram is the source-recorded Ventus partner")
	_check(not drago.g_verified and drago.canonical_g == null and not ingram.g_verified, "Unverified starting G for Drago and Ingram remains conditional, even when their attributes are known")
	_check(not CanonicalCatalog.attribute_locked("juggernoid") and CanonicalCatalog.allowed_attributes("juggernoid").size() == 6, "Juggernoid remains a general species with all imported selectable variants")
	_check(CanonicalCatalog.allowed_attributes("preyas") == ["Aquos", "Darkus", "Subterra"], "Preyas preserves its three documented changing attributes")
	_check(not CanonicalCatalog.attribute_locked("preyas_ii_angelo") and CanonicalCatalog.allowed_attributes("preyas_ii_angelo").has("Haos") and CanonicalCatalog.allowed_attributes("preyas_ii_angelo").has("Aquos"), "The Angelo hybrid is selectable in both documented identities")
	var delta: Dictionary = CanonicalCatalog.resolve("delta_dragonoid", "Aquos", 320)
	_check(delta.g == 450 and delta.g_verified and delta.g_source_confidence == "indexed" and "выдержке" in delta.g_note, "Delta uses 450G with indexed-source confidence disclosed")
	var lars: Dictionary = CanonicalCatalog.resolve("lars_lion", "Darkus", 350)
	_check(lars.attribute == "Haos" and lars.g == 500 and lars.g_source_confidence == "verified", "Lars Lion uses the directly recorded Haos 500G profile")
	var white: Dictionary = CanonicalCatalog.resolve("wavern", "Haos", 350)
	_check(white.native_attribute == "White" and white.unsupported_native_attribute and not white.attribute_verified and not white.g_verified, "Wavern is explicitly White with conditional gameplay values, never a claimed native Haos form")
	var selection: Array = [1, 31, 82]
	var attributes: Array = ["Aquos", "Darkus", "Pyrus"]
	var migrated: Array[String] = Roster.normalize_selection_attributes(selection, attributes)
	var anime: Array[Dictionary] = Roster.make_anime_team(selection, attributes)
	var explicit: Array[Dictionary] = Roster.make_team(selection, attributes, 0, true)
	_check(anime == explicit and anime.size() == 3, "Explicit canonical team selection and the anime helper agree")
	_check([anime[0].attribute, anime[1].attribute, anime[2].attribute] == migrated, "Saved-selection normalization agrees with actual team attributes")
	_check(anime[0].id == "p0_dragonoid" and anime[1].id == "p0_juggernoid" and anime[2].id == "p0_ingram", "Canonical profile migration preserves save indices and player identities")
	for unit: Dictionary in anime:
		unit.g = 9999
		unit.used = true
	var restored: Array[Dictionary] = Roster.make_anime_team(selection, attributes)
	_check(not restored[0].used and restored[0].g != 9999, "Combat mutations cannot corrupt source starting powers")
	_check(Roster.canonicalize_team(anime)[0].g == restored[0].g, "Recanonicalizing known species restores source or conditional starting G")
	_check(Roster.make_team(selection, attributes)[0].attribute == "Aquos" and Roster.make_team(selection, attributes)[0].g == 320, "The legacy helper remains explicitly available for existing rule fixtures")
	_check(Roster.make_team(selection, attributes, 2, true).is_empty(), "Invalid owner cannot construct a canonical team")
	_check(Roster.make_opponent(0, true) == Roster.make_anime_opponent(0), "Canonical opponent construction uses the same source profile path")
	var first: Dictionary = CanonicalCatalog.profile("dragonoid")
	first.initial_g = 9999
	_check(CanonicalCatalog.profile("dragonoid").get("initial_g") != 9999, "Returned canonical profiles are independent copies")

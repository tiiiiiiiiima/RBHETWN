extends SceneTree
## Outcome tests for all printed trap operators, choices and battle lifecycle.
const Duel = preload("res://scripts/anime_duel_rules.gd")
const Cards = preload("res://scripts/anime_card_catalog.gd")
const Traps = preload("res://scripts/anime_trap_catalog.gd")
var checks: int = 0
var failures: Array[String] = []

func _init() -> void:
	_atomicity()
	_basic_effects()
	_choices_and_actions()
	_persistent_move()
	_activation_and_reflection()
	_clone_lifecycle()
	print("TRAP DUEL 0.9 CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _team(owner: int, attribute: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(3):
		result.append({"id": "p%d_test%d" % [owner, i], "name": "Dragonoid" if i == 0 else "Juggernoid%d" % i,
			"attribute": attribute, "g": [300,500,400][i] if owner == 0 else [400,350,250][i]})
	return result

func _fight(identity: String):
	var profile: Dictionary = Traps.get_support(identity)
	var duel = Duel.new()
	_check(duel.new_match(_team(0, str(profile.attribute)), _team(1, "Pyrus"), 444, [], [],
		[{"id": identity, "attribute": str(profile.attribute)}, null]).ok, "A valid independent trap slot starts " + identity)
	duel.gate_hands[0] = [Cards.get_gate("pyrus_50")]
	duel.gate_hands[1] = [Cards.get_gate("aquos_50")]
	duel.place_gate(0,0,5)
	duel.place_gate(1,0,6)
	duel.throw_unit(0,0,5)
	duel.finish_turn(0)
	duel.throw_unit(1,0,5)
	return duel

func _passes(duel) -> Dictionary:
	var first: Dictionary = duel.pass_response(int(duel.battle.priority))
	_check(first.ok, "Current priority may pass")
	return duel.pass_response(int(duel.battle.priority))

func _deploy(duel, options: Dictionary = {}) -> Dictionary:
	var played: Dictionary = duel.deploy_trap(0,0,-1,options)
	_check(played.ok, "Trap deploys with matching battle caster and own priority")
	var result: Dictionary = _passes(duel)
	_check(result.ok, "Trap chain resolves after both responses")
	return result

func _atomicity() -> void:
	var duel = _fight("fortress")
	_check(duel.teams[0].size() == 3 and duel.available_units(0) == [1,2], "Trap never occupies or changes the three main team slots")
	var before: String = JSON.stringify(duel.state_snapshot())
	_check(not duel.deploy_trap(1).ok and before == JSON.stringify(duel.state_snapshot()), "Wrong owner cannot spend another trap")
	_check(not duel.deploy_trap(0,2).ok and before == JSON.stringify(duel.state_snapshot()), "Reserve unit cannot act as trap caster")
	_check(not duel.new_match(_team(0,"Darkus"),_team(1,"Pyrus"),1,[],[],[{"id":"shadow_wing","attribute":"Ventus"},null]).ok and before == JSON.stringify(duel.state_snapshot()), "Paired Shadow Wing cannot enter a trap battle slot")
	_check(not duel.deploy_trap(0,0,-1,{"amount":9999}).ok and before == JSON.stringify(duel.state_snapshot()), "Forged effect values do not mutate match state")
	duel.deploy_trap(0,0)
	duel.ability_hands[1] = [Cards.get_ability("aqua_guardian")]
	duel.teams[1][0].attribute = "Aquos"
	_check(duel.play_ability(1,0,0).ok, "The standard ability counter can target a pending trap ability")
	_passes(duel)
	_check(duel.support_slots[0].status == "spent" and duel.support_slots[0].stats.countered == 1 and duel.battle_totals() == [300,400], "Countering consumes the once-only trap without applying G effects")
	_check(not duel.deploy_trap(0,0).ok, "A cancelled trap cannot be redeployed")

func _basic_effects() -> void:
	var fortress = _fight("fortress")
	_deploy(fortress)
	_check(fortress.battle_totals() == [500,400], "Fortress sets participants to each owner's highest living power")
	var metal = _fight("metalfencer")
	metal.teams[0][0].name = "Viper Helios"
	_deploy(metal)
	_check(metal.battle_totals()[0] == 400 and metal.teams[0][0].permanent_support_g == 100, "Metalfencer applies the complete permanent Viper Helios bonus")
	var wired = _fight("wired")
	wired.teams[0][0].name = "Altair"
	_deploy(wired)
	wired.gates[5].boosts = {"Ventus":50}
	wired.open_gate(0)
	_check(wired.battle_totals()[0] == 400 and wired.teams[0][0].permanent_double_gains, "Wired doubles gate gains and marks Altair's multiplier persistent")
	var fly = _fight("falcon_fly")
	_deploy(fly)
	_check(fly.teams[1][0].double_losses, "Falcon Fly activates enemy loss doubling")
	var loss: int = fly._alter_power(1,-100,0)
	_check(loss == -200 and fly.battle_totals()[1] == 200, "Falcon Fly doubles actual ability loss")
	_check(fly._alter_power(1,-50,0,"support") == -50, "The card-only loss multiplier does not amplify a separate trap effect")
	var zoack = _fight("zoack")
	_deploy(zoack)
	zoack.open_gate(0)
	_check(zoack.battle_totals() == [300,400], "Zoack suppresses positive gate changes for both sides")
	_check(zoack._alter_power(1,200,0) == 0 and zoack._alter_power(1,-50,0) == -50, "Zoack blocks card gains while allowing losses")
	var piercian = _fight("piercian")
	_deploy(piercian)
	piercian._alter_power(0,200,0)
	_passes(piercian)
	_check(piercian.teams[0][0].status == "reserve" and piercian.teams[0][0].current_g == 500, "Piercian preserves resolved battle G changes after the winner returns")
	var dynamo = _fight("dynamo")
	_deploy(dynamo)
	_check(dynamo.teams[0][0].attribute == "Darkus" and dynamo.teams[1][0].attribute == "Aquos", "Dynamo changes both sides to paired opposite attributes")
	var epsilon = _fight("tripod_epsilon")
	_deploy(epsilon)
	_check(epsilon.teams[0][0].attribute == "Aquos" and epsilon._unit_attributes(epsilon.teams[0][0]).size() == 4, "Epsilon retains Aquos plus all three printed secondary attributes")
	epsilon.open_gate(0)
	_check(epsilon.battle_totals()[0] == 350, "Epsilon's extra Pyrus identity receives the Pyrus gate bonus")
	_check(epsilon._compatible_ability(Cards.get_ability("lightning_tornado"),epsilon.teams[0][0]), "Epsilon's additional Haos identity can activate a Haos ability")
	var coin = _fight("triad_el_condor")
	_deploy(coin)
	_check(coin.support_slots[0].stats.successful == 1, "Triad El Condor completes the seeded two-tails coin sequence")
	var baliton = _fight("baliton")
	_check(not baliton.can_deploy_trap(0), "Baliton requires an open source gate")
	baliton.gates[6].revealed = true
	baliton.gates[6].boosts = {"Subterra":70}
	_deploy(baliton,{"source_slot":6})
	_check(baliton.battle_totals()[0] == 370, "Baliton applies the chosen open gate's complete boost on the current battle")

func _choices_and_actions() -> void:
	var flash = _fight("flash_falcon_fly")
	var result: Dictionary = _deploy(flash)
	_check(result.event == "trap_action_required" and flash.pending_trap_action().type == "swap", "Flash pauses the chain for a real forced reserve swap")
	_check(not flash.pass_response(0).ok, "Normal responses are blocked during a compulsory trap action")
	_check(flash.resolve_trap_action(0,{"unit_index":1,"outgoing_index":0}).ok and flash.pending_trap_action().owner == 1, "Flash requires a separate swap from the second involved player")
	_check(flash.resolve_trap_action(1,{"unit_index":1,"outgoing_index":0}).ok and flash.pending_trap_action().is_empty(), "Both forced swaps complete and resume the suspended chain")
	_check(flash.battle_units(0)[0].index == 1 and flash.teams[0][0].status == "reserve" and flash.battle_units(1)[0].index == 1, "The incoming reserves replace current battle units without adding team members")
	var hexstar = _fight("hexstar")
	_deploy(hexstar)
	_check(hexstar.pending_trap_action().type == "roll", "Hexstar exposes a real additional roll action")
	_check(hexstar.resolve_trap_action(0,{"unit_index":1,"slot":5}).event == "trap_roll_returned" and hexstar.teams[0][1].status == "reserve", "Hexstar returns a roll that stands on its own battle gate to hand")
	var miss = _fight("hexstar")
	_deploy(miss)
	_check(miss.resolve_trap_action(0,{"unit_index":1,"slot":-1}).event == "trap_roll_miss" and miss.pending_trap_action().is_empty(), "A physical Hexstar miss completes the mandatory roll without placing a unit")
	var stand = _fight("hexstar")
	_deploy(stand)
	_check(stand.resolve_trap_action(0,{"unit_index":1,"slot":6}).event == "trap_roll_stand" and stand.teams[0][1].slot == 6, "Hexstar can stand a real reserve unit on another available gate")
	var hylash = _fight("hylash")
	_check(not hylash.can_deploy_trap(0), "Hylash needs a real outside-battle resolved G change")
	hylash.teams[0][1].permanent_support_g = 120
	hylash.teams[0][1].current_g = 620
	_deploy(hylash,{"source_owner":0,"source_index":1,"target_owner":1,"target_index":0})
	_check(hylash.teams[0][1].current_g == 500 and hylash.battle_totals()[1] == 520, "Hylash removes all actual source changes and transfers them to the explicitly selected participant")

func _persistent_move() -> void:
	var drill = _fight("hexados")
	_deploy(drill,{"destination_slot":6})
	_check(drill.battle_totals()[1] == 350 and drill.support_slots[0].slot == 6 and drill.support_slots[0].moves == 1, "Hexados subtracts the first 50G and physically moves to an adjacent gate")
	_passes(drill)
	_check(drill.support_slots[0].status == "field", "A moved Hexados survives on its next gate without another deployment")
	drill.finish_turn(1)
	drill.throw_unit(0,1,6)
	drill.finish_turn(0)
	drill.throw_unit(1,1,6)
	_check(drill.battle.chain.size() == 1, "A later battle on Hexados's gate triggers its next effect automatically")
	_passes(drill)
	_check(drill.battle_totals()[1] == 250 and drill.support_slots[0].stats.deployments == 1, "The second Hexados trigger subtracts 100G while preserving the one-use deployment limit")

func _activation_and_reflection() -> void:
	var pyth = _fight("pythantus")
	var remote: Dictionary = pyth.teams[1][1]
	pyth._enter_support_unit(remote,6)
	_deploy(pyth)
	pyth.pass_response(0)
	pyth.teams[1][0].name = "Skyress"
	pyth.ability_hands[1] = [Cards.get_ability("fire_storm")]
	_check(pyth.play_ability(1,0,0).ok and pyth.battle_totals()[1] == 300, "Pythantus drains 100G when an opposing ability is activated before its resolution")
	_passes(pyth)
	_passes(pyth)
	_check(remote.current_g == 450, "Pythantus transfers the actual accumulated drain to another opposing field unit after battle")
	var scorpion = _fight("scorpion")
	_deploy(scorpion)
	scorpion.pass_response(0)
	scorpion.ability_hands[1] = [Cards.get_ability("fire_tornado")]
	_check(scorpion.play_ability(1,0,0,0).ok, "A targeted opposing ability may be activated against Scorpion's side")
	_passes(scorpion)
	_check(scorpion.battle_totals() == [400,300] and scorpion.support_slots[0].reflection_used, "Scorpion reflects the full first transfer back from its original caster")
	var before: Array[int] = [300,400]
	scorpion.pass_response(0)
	scorpion.ability_hands[1] = [Cards.get_ability("fire_tornado")]
	scorpion.play_ability(1,0,0,0)
	_passes(scorpion)
	_check(scorpion.battle_totals() == before, "Scorpion's second incoming transfer is not reflected again")
	var departed = _fight("scorpion")
	_deploy(departed)
	departed.pass_response(0)
	departed.ability_hands[1] = [Cards.get_ability("fire_tornado")]
	departed.play_ability(1,0,0,0)
	departed.gates[5].bakugan.erase(departed.teams[0][0])
	departed._return_unit(departed.teams[0][0])
	var outcome: Dictionary = _passes(departed)
	_check(outcome.outcomes[0].event == "ability_failed" and departed.battle_totals()[1] == 400, "A reflected transfer fails safely when the reflecting participant leaves before resolution")

func _clone_lifecycle() -> void:
	var theta = _fight("tripod_theta")
	_check(not theta.can_deploy_trap(0), "Theta requires a genuinely defeated teammate")
	theta.teams[0][2].status = "defeated"
	theta.teams[0][2].current_g = 0
	theta.defeated[0].append(2)
	_deploy(theta,{"unit_index":2})
	var copy: Dictionary = theta.battle_units(0)[1]
	_check(theta.teams[0].size() == 3 and copy.base_g == 100 and copy.temporary_clone and theta._unit_attributes(copy) == ["Darkus","Ventus"], "Theta adds a 100G dual-attribute clone only to battle occupants")
	_check(theta.battle_totals()[0] == 400, "Theta's temporary clone contributes its own 100G to its owner's battle total")
	_passes(theta)
	_check(copy.status == "removed" and theta.defeated[0] == [2] and theta.teams[0][2].status == "defeated", "A departing copy disappears without resurrecting or changing the three original defeat indices")

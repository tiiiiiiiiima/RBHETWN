# Anime duel API, 0.9

`anime_duel_rules.gd` preserves the 0.8 turn, gate, ability and battle interfaces. It adds an independent optional trap slot per player. Traps are available only in this anime duel engine; neither the three main team slots nor Wii rules acquire trap combat.

## Match and selection

`new_match(team0, team1, seed=1, gate_loadouts=[], ability_loadouts=[], support_loadouts=[])` accepts zero selections or exactly two optional selections. Each selection is `null`, `{}`, or `{id, attribute}`. The source catalog validates identity, actual Trap category, enabled printed effect and permitted playable attribute. Shadow Wing remains paired collection support and is rejected. Invalid input leaves a running match unchanged.

`support_slots[owner]` contains a source profile and runtime `owner`, `status`, `used`, `caster_index`, `slot`, and counters in `stats`. One invocation is allowed per match. `ready → pending → deployed → spent` is the usual lifecycle. Cancelled/failed traps are spent. Hexados may instead become `field` on its adjacent destination gate and trigger again in a later battle without another invocation. Source `own_g` and anime G remain nullable; traps contribute their printed effects rather than invented individual starting G.

## Deployment and response chains

- `trap_casters(owner) -> Array[int]` lists matching-attribute participants.
- `trap_choices(owner) -> Dictionary` lists only choices relevant to the selected trap.
- `trap_error(owner, caster_index=-1, target_index=-1, options={}) -> String` returns a Russian explanation or an empty string.
- `can_deploy_trap(...) -> bool` uses the same validation.
- `deploy_trap(...) -> Dictionary` queues a counterable trap ability and passes response priority.

Deployment requires the player's response priority in an active battle, a matching own participant and an unused slot. The source Anime Style format allows traps to be placed before battles. This game's battle-only timing, matching caster requirement, independent slot and once-per-match invocation are local adaptations to the requested standalone anime mode.

Options use integer values; malformed or irrelevant options are rejected before changing the match:

| Effect | `trap_choices` | Deployment options |
|---|---|---|
| Baliton | `source_slots: Array[int]` | `source_slot` |
| Hexados | `destination_slots: Array[int]` | `destination_slot` |
| Tripod Theta | `defeated_indices: Array[int]` | `unit_index` |
| Hylash | `history_sources: Array[{owner,index,name,change}]`, `target_units: Array[{owner,index,name}]` | `source_owner`, `source_index`, `target_owner`, `target_index` |

Defaults choose the first eligible source/defeated unit/destination and the caster as Hylash's target. Missing prerequisite sources prevent deployment. Required eligibility is checked again when a queued effect resolves.

## Mandatory actions and real rolls

`pending_trap_action() -> Dictionary` returns `{}` or an action with `type`, `owner`, `support_id`, `available_indices`, and `trap_slot`.

- A `roll` also supplies `slots`, the eligible gate slots. Call `resolve_trap_action(owner, {unit_index, slot})` after the UI's ordinary flight and ground-roll simulation. `slot=-1` is a miss. Hexstar returns a unit landing on its own trap gate to the reserve; another eligible gate receives the standing unit. To preserve the local engine's single active battle, an off-battle landing opposed by another player is returned to the reserve with `reason="off_battle_opposition"`. This safeguard is an explicit local limitation, not a printed Hexstar rule.
- A `swap` also supplies `outgoing_indices`. Call `resolve_trap_action(owner, {unit_index, outgoing_index})`. Incoming units must be alive reserves; outgoing units must be actual main-team participants. Flash Falcon Fly queues a choice for both involved players where replacement is possible. It never forces a nonexistent replacement or uses an already defeated unit.

Ordinary response actions are blocked while a mandatory action is pending. The LIFO chain is suspended and resumes after all compulsory actions. Action results use `trap_roll_returned`, `trap_roll_miss`, `trap_roll_stand` and `trap_swap`; the final action includes `chain_outcome`. The UI and AI use the same rules and real roll simulation.

## Complete printed effects and implementation choices

All seventeen visually verified Trap Ability faces have enabled runtime operators. Full English descriptions, source image paths, original file hashes and extracted-face hashes remain attached to `source_effect`.

| Trap | Runtime behavior |
|---|---|
| Fortress | Sets each battle participant to its owner's highest living Bakugan's current power. |
| Metalfencer | Permanently adds 50 G to own participants, or 100 G to Viper Helios. |
| Falcon Fly | Doubles opposing losses caused by ability/gate changes during the battle. |
| Wired | Doubles own ability/gate gains; Altair keeps the multiplier after the battle. |
| Zoack | Prevents both sides' positive ability/gate gains during the battle. |
| Piercian | Preserves battle power changes as permanent differences from each participant's base. |
| Baliton | Applies the chosen open, non-nullified gate effect to the battle, including command gates. |
| Triad El Condor | Uses the seeded RNG until two tails; repeats the current gate effect once per head. A battle-ending command stops further repetitions. |
| Dynamo | Maps Pyrus ↔ Aquos, Haos ↔ Darkus and Ventus ↔ Subterra for current participants. |
| Flash Falcon Fly | Requires both players' reserve swaps where possible. |
| Hexados | Subtracts 50 G plus 50 G per earlier move from each opponent, then moves to an adjacent existing gate if present. Its later battle triggers preserve the move count. |
| Hexstar | Requires a real additional roll if a reserve is available; applies its own-gate return condition. |
| Hylash | Moves all actual resolved current-minus-base G changes from a living Bakugan outside the battle to any chosen participant; removes the changes from the source. |
| Pythantus | Subtracts up to 100 G from an opposing participant whenever a standard ability is activated, including one later countered. After the battle it transfers the actually drained G to the first other opposing unit still on the field, if one exists. No outside-field recipient is invented and unused transfer amounts do not carry into a later battle. |
| Scorpion | Reflects the first ability targeting its own side back onto the original caster. Original activation eligibility is retained. A self-targeted gain consumes the first-reflection condition without changing its target. |
| Tripod Epsilon | Own Aquos participants count as Aquos, Subterra, Haos and Pyrus for gate bonuses and ability eligibility. |
| Tripod Theta | Adds a defeated ally's temporary 100 G copy with Darkus and Ventus identities to the battle; it disappears upon leaving and never resurrects the original. |

Card gain/loss multipliers apply to ability/gate changes, including copied gate effects, rather than multiplying unrelated trap changes. `battle_unit_breakdown` and `battle_breakdown` include a separate `support` component; all totals clamp at zero. Temporary copies live only in gate occupants and `battle_units(owner)`, have indices ≥1001, `temporary_clone=true` and an original `model_name`/`species`. They are excluded from `teams`, permanent defeat indices and elimination victory.

## Source profiles and native attributes

`roster.gd` supports `make_team(selection, attributes, owner=0, canonical=false)` and `make_opponent(stage, canonical=false)`, plus `make_anime_team`, `make_anime_opponent` and `normalize_selection_attributes` aliases. Canonical mode fixes only named single-element partners to their source-recorded identity. Generic species retain variants; documented hybrids and attribute changers remain exceptions. Opponents use the same source path without tournament G inflation.

Canonical metadata supplies nullable `canonical_g`, `g_verified`, `g_note`, `g_source_confidence`, native/source attributes and provenance. Unknown initial power uses the old playable balance explicitly labelled conditional. Indexed evidence is separately labelled. Original save indices and legacy fixtures remain available. White native identities are disclosed as unsupported; their conditional six-attribute gameplay representation is not labelled a native anime form.

## Verification

The focused suites are `tests/test_canonical_catalog.gd`, `tests/test_anime_trap_catalog.gd`, `tests/test_trap_duel_rules.gd` and the existing anime engine/scene suites. Trap outcomes cover all seventeen operators, wrong priority, malformed selections, countering, real-roll results, both forced swaps, persistent movement, remote power transfer, activation timing, first-only reflection and temporary-copy cleanup. These checks establish the local game's behavior; they do not establish an exact anime or Bloxugan rules transcription.

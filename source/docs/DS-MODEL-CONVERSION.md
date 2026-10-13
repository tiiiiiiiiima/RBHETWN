# Original DS battle forms

The user-supplied Nintendo DS source was converted into 39 battle forms, 121 available source attribute variants, and 259 distinct native joint-animation clips. The project contains 141 embedded GLBs (46,117,484 bytes). Each retains source geometry, skin, texture coordinates, per-material textures, and the converter's original material properties. The ROM, decompressed Nitro resources, original executable code, camera bundles and extraction staging are outside the game project.

`assets/ds/models/model_manifest.json` records source NitroFS paths, original file and decoded-part SHA256 hashes, attribute palette provenance, exported artifact hashes, actual form availability, conversion limitations, and normalized transforms. The source is `BAKUGAN W`, code `B6RE`, ROM SHA256 `7185fc031847a8bd84ab44e802dd3c0184bd27e59563cf1fb4ccf55b6d0084bb`. Conversion used apicula `0.1.1-dev`; its binary hash is recorded in the manifest.

## Geometry and original materials

LZ10-compressed NSBMD and NSBTX resources were decompressed and structurally validated. Joint BCA0 resources were carved from their source `_data.bin` bundles. The supplied RGB555 `Game/Realbaku/Tex/*.ntfp` files replace their matching named NSBTX palette for each available attribute. Apicula decodes those original indexed textures. Every texture is embedded in the GLB; runtime recoloring is unnecessary.

Available palette sets vary by species. Fixed partners keep their native source appearance. Requesting an unavailable attribute returns an explicit native appearance with `exact_attribute=false`. The importer does not invent absent palettes.

Visual review corrected Preyas's identity: base Preyas is `realb06`, Preyas II Angelo is `realb07`, and Preyas II Diablo is `realb08`. The former portrait suffix 008 association must not be used for base Preyas. Original English MES names are stored separately from canonical display names.

Siege's source portrait is present, but `realb49.nsbmd` is absent. This catalog does not claim a native Siege battle form. `realb83.nsbmd` remains unassigned because its armored club-bearing appearance does not establish a verified roster identity. Species from later games are not assigned unrelated DS geometry.

## Animation and normalization

All 39 models were inspected at the first, middle and last imported keyframes of their native `_M_11` clip. These show stable breathing, stance or hovering motion with a near-returning pose. Only the `idle` semantic role is assigned. Other joint clips keep their source names. `_99` is not labelled victory; Drago's `_99` visibly takes off and remains airborne.

Bounds use polygon-referenced, evaluated skinned vertices, excluding diagnostic helper geometry. A union of three idle poses supplies a uniform height of 2.5 Godot units and floor y=0. Original forward +Z is retained. This is a sampled idle fit, not an assertion that every frame of every charge or flight stays within the fitted bounds.

Ten byte-identical joint motions repeated by larger source bundles were collapsed. The duplicate native names and curve hashes are retained as provenance. All distinct joint motions remain available, including the additional `_M_20` clips for Leonidas and Battle Ax Vladitor.

## Converter limits and validation

Apicula does not export native material, pattern, visibility or BMA0 animations. Their source parts remain inventoried, while GLBs preserve supported joint animation. A static source texture matrix in Battle Ax Vladitor also produces an apicula unsupported-matrix warning; that material transform is not claimed exact.

Structural validation checks every recorded GLB hash, embedded image/buffer references, skin availability, unique native clip names and bound animation targets. All 141 GLBs pass. GDScript catalog/test parsing and Python importer compilation pass. After the project-wide import, `tests/test_ds_models.gd` passed: 141 imported native/variant scenes, 897 native clip playbacks, zero failures. This verifies available source materials, skeletons, animation tracks and explicit missing species/attribute behavior.

Godot scene imports use `gltf/embedded_image_handling=3` (Embed as Uncompressed). This retains the embedded source image pixels without duplicate extracted PNG assets. After reimporting, 877 generated model PNGs and their sidecars were moved outside the project. All 141 scenes were loaded and every imported texture's pixel image was checked again: zero failures. Future first-time model imports should use the same lossless embedded image mode.

## Desktop action selection

Eight native `_M_10` motions were visually reviewed: Dragonoid, Gorem, Tigrerra, Preyas, Skyress, Hydranoid, Robotallion and Leonidas. They show strikes, pounces, dives or forward lunges and are selected as an **observed desktop presentation action**. Their original DS semantic role remains unknown. Other species receive no inferred `_M_10` action.

The original clips remain unchanged. `ModelLibrary` creates a separate `ds_desktop/desktop_action` animation in each instance's animation library. Only the `Bip01` position track changes: X/Z stay at native idle; Y follows a floor lift computed from source skinned geometry. Every original limb, wing, rotation and other animation track remains intact. This avoids native camera trajectories that would move some creatures 6.6–48.9 normalized units away from the duel camera.

`assets/ds/models/desktop_action_floor.json` records the source GLB and native BCA hashes, ROM hash, normalization basis, sample curves and validation. Evaluated polygon-referenced vertices were sampled at 120 fps plus every exact animation key time. Interpolated midpoints were checked as well. A 0.025-unit floor margin keeps the fitted geometry above y=0; the lowest checked midpoint clearance is approximately 0.0101 units. The correction preserves the visible source pose instead of burying aerial feet or tails in the stage.

`tests/test_ds_desktop_action.gd` passes 113 checks: all eight actions retain their original source clips and every unaffected key, preserve horizontal placement, lift only Y, keep actual Godot CPU-skinned sampled geometry above the floor, freeze on pause and return to idle on completion. Original-game role uncertainty remains in runtime metadata. Validation totals and the floor curve artifact hash are recorded in `builds/ds-model-validation-0.10.json`.

Adapted actions cut directly to their validated first pose and directly back to idle. Mixing an unrelated idle pose during a crossfade can bend geometry outside the source pose's floor envelope. The focused test also checks eight early transition samples for each species; these remain above the floor with the direct transitions.

The runtime API is `scripts/ds_model_catalog.gd`: `resolve(species, attribute)`, `get_entry`, `available_attributes`, `species`, and `coverage`. Resolved definitions include `actual_form="battle"`, original source provenance, transform, exact palette status and the verified idle clip. The battle integration selects this catalog before explicit physical toy fallbacks.

Reconversion uses `tools/import_ds_models.py`, the supplied extraction inventory and portrait identity manifest, and an external staging directory. Optional `--catalog` keeps canonical display names; `--motion-evidence` applies the separately reviewed idle poses. No ROM path should be placed under the game project's `assets` or `builds` directories.

# Nintendo DS rules audit — 0.12

Later evidence: after release 0.18 the authorized original was played,
including completed tutorials 1/2 and a full ordinary match. See
[gameplay comparison](DS-GAMEPLAY-COMPARISON.md) for observed sequencing,
camera, statistics and remaining uncertainties. Statements below about
not executing the original describe this earlier 0.12 audit, not the
current verification status.

Audit date: 2026-10-06. This audit uses the English message tables in the **user-supplied Nintendo DS B6RE archive**, not a Wii manual, tabletop rules or Bloxugan. The raw source remains outside the project at `/workspace/bakugan-ds-import/raw/font/`. `tools/decode_ds_messages.py` decodes bounded LZ10 MES records; indices below are **zero-based**. Unknown control codes remain explicit. Reading an English tutorial is primary evidence for the described rule, but does not establish every edge case or the original executable's implementation.

## Confirmed original DS rules

| Topic | Original MES source and index | Confirmed behavior |
| --- | --- | --- |
| Deck | `mes_DeckSelect.mes` 9–17 | Three Bakugan; one Gold, one Silver and one Copper Gate Card; one Red, one Green and one Blue Ability Card. These are explicit editable deck slots. |
| Opening gate | `mes_T001_1.mes` 1 | Pick a Gate Card and set it on the field before throwing. |
| Opening arrangement | `mes_T001_ba.mes` 0 | “Your card is closest to your opponent and their card is set closest to you.” The tutorial confirms crossed opening placement. It does not give numeric coordinates or all legal slots. |
| Throw and steering | `mes_T001_ba.mes` 3–4 | Hold the sphere, make a quick upward stylus slash and lift it; short separate strokes steer the sphere after the throw. Mouse/keyboard charging and steering in the prototype are PC adaptations. |
| Opposed stand | `mes_T001_5.mes` 1 | A Bakugan standing on the same gate as an opponent starts a battle; the winner receives the gate. |
| Victory | `mes_T001_5.mes` 2 | Collect three Gate Cards to win. |
| Double Stand | `mes_T001_5.mes` 3 | Two own Bakugan on one gate capture it without a battle. This basic capture option **is confirmed DS**, not merely inherited from Wii. The tutorial does not prove that capture is mandatory or that the original game lacks a movement choice. |
| Double Stand interface | `mes_command.mes` 22–24 | Labels “Double Stand”, “Win Gate Card”, “Move Your Bakugan” exist. They support an original movement option, but alone do not prove adjacency, which unit moves, or valid destinations. |
| Reveal | `mes_T002_ba.mes` 3 | At battle start the gate is revealed and shows attribute-specific G-Power boosts. |
| Gold gate | `mes_Card.mes` 0 | The pictured Bakugan receives its gate G-Power boost doubled. This is not a doubling of base G or every gain in the battle. |
| Silver gate | `mes_Card.mes` 1 | Attribute G-Power boosts, without the additional special benefit of Gold/Copper. |
| Copper gate | `mes_Card.mes` 2 | Special effects can swap G-Power or disallow Ability Cards; exact effects must follow each card's source text. |
| STAY | `mes_tips_Dan.mes` 4 | With every Bakugan standing, another throw is unavailable. Select one to STAY; if it is still there after everyone else's turn, capture its gate. Basic trigger and response window are confirmed. |
| Critical K.O. | `mes_tips_Dan.mes` 3 | Knock an opponent off its gate to capture that gate. The numeric damage formula and a zero-G alternative are not established by this passage. |
| Ability timing | `mes_T004_ba.mes` 0–1; `mes_T004_1_f.mes` 0 | Select an Ability Card before battle, then activate it with L/R during battle. This source does not establish an unrestricted number of abilities per battle. |
| Battlefield cards | `mes_tips_Dan.mes` 6 | A collected battlefield Ability Card activates immediately after the collecting Bakugan stands on a gate. They are distinct from deck abilities. |
| Special Shot | `mes_tips_Dan.mes` 10 | Requires a full S-Power meter and a Bakugan reaching a certain level. The exact unlock level is not given here. |
| Turn sequence | `mes_command.mes` 27–28 | The UI has a “Deciding the turn sequence” step and displays the resulting order. The sequence-generation algorithm is not decoded. Fixed P1-first is not established as a DS rule. |

## Six original DS battle minigames

`mes_TIPS_sys.mes` 15–20 lists Scratch, Spin, Timing, Pop, Trace and Bound. The full descriptions are `mes_tips_Dan.mes` 18–23:

| Original DS game | Confirmed stylus action |
| --- | --- |
| Scratch | Rub the attribute symbol; faster rubbing earns more G. |
| Spin | Turn the symbol; faster turning earns more G. |
| Timing | Tap symbols arriving from both sides when they reach the center ring. |
| Pop | Tap symbols that appear briefly on the screen. |
| Trace | Trace a moving symbol; time touching it earns G. |
| Bound | Hold the stylus on a moving symbol until it slows and bursts. |

`mes_ControlBattle.mes` 0–5 independently supplies Rub / Touch / Pop / Turn / Trace / Trace prompts. The reviewed messages do **not** establish the gate-color-to-minigame assignment or numeric scoring. Wii's Gold→Shooting, Silver→Timing, Copper→Shake mapping cannot be represented as verified DS. In 0.12 the retained three PC battle games remain an explicit adaptation; the complete six-game DS implementation is planned separately.

## Remaining adaptations and uncertainties

The following details are **not confirmed as DS** by this audit: the four exact opening coordinates; one ordinary gate placement per turn; orthogonal adjacency; simultaneous re-opening setup when no gates remain; which unit can move after Double Stand and to which neighboring card; spent-Bakugan recycling; the treatment of missed throws; exact STAY cancellation edge cases; gate/ability selection timing edge cases; first-player selection; ties; the original numeric Critical K.O. formula; minigame duration/scoring/color assignment. Rules retained from the reviewed Wii flow or chosen for a playable two-player PC game must remain labeled as adaptations. They must not override any source-confirmed card effect.

The original DS executable has not been run or compared frame by frame in this audit. No full original battle footage was verified. Tutorial strings do not prove faithful cameras, sequencing, animation timing or all card effects. Native card G tables are documented below; a matching Wii card title alone does not verify DS values.

## Recovered native DS numeric parameters

`assets/ds/playable_cards.json` retains binary provenance and per-card offsets. The source is the decompressed ARM9 from the same authorized B6RE ROM (SHA256 `7cc01c584d2ecdd7166471f218f9fc3a58cf102b5fbe925287b9b95bae0c221e`). At **0xA10AC** there are 213 little-endian uint16 card IDs, matching the complete native artwork/MES sequence including the back. At **0xA15AC** there are 213 rows of six bytes. Attribute order is **Pyrus, Aquos, Subterra, Haos, Darkus, Ventus** and stored units are multiplied by **10**. The card-data investigation also identified the native parameter accessor at 0x65C08. This audit independently checked the recovered manifest against every native ID and numeric row available in the manifest; it did not execute DS code.

| Native ID / card | DS G values in attribute order | Effect/source |
| --- | --- | --- |
| 101 Dragonoid | 150 / 50 / 70 / 30 / 50 / 40 | Doubles gate bonus for Dragonoid; native `mes_CardText` index 1. |
| 136 Leonidas | 100 / 100 / 100 / 100 / 100 / 100 | Doubles gate bonus for Leonidas; index 36. |
| 217 Aquos Vortex | 60 / 150 / 120 / 50 / 20 / 20 | Silver gate; numeric row is present even though its description is only a control marker. |
| 220 The Cliffs | 120 / 100 / 150 / 50 / 100 / 50 | Silver gate. |
| 215 Sunrise | 20 / 20 / 60 / 140 / 120 / 80 | Silver gate. |
| 306 Stand Your Ground | 20 / 80 / 140 / 50 / 60 / 110 | “Both players regain all Ability Cards.” Native text does not itself state exact after-battle timing. |
| 602 G-Power Boost | 60 / 0 / 60 / 0 / 60 / 0 | Native blue ability, not a universal +60. |
| 605 Home Advantage | 0 / 50 / 110 / 0 / 0 / 0 | Applies only on an own Gate Card; native row differs from a generic bonus. |

The current DS default **prototype** deck is gates 136/217/306 and abilities 408/527/602. This is a valid color-composition selection, **not a verified reconstruction of the original new-save starter deck**. Counter Swap 408 swaps G when the battling attributes differ; Alpha Blaster 527 grants Leonidas +200 (explicit native text, rather than its zero numeric table row); G-Power Boost 602 uses its attribute row. In 0.12, the playable manifest contains **26 gates + 40 abilities = 66 cards**. The full 212-face browser does not imply all 212 effects are implemented. Recovering numeric rows does not recover every conditional effect or all engine timing.

## Source fingerprints

SHA256 values refer to the original compressed MES files:

| File | SHA256 |
| --- | --- |
| `mes_DeckSelect.mes` | `5ea9c46ae068e6df28baf61f3e720108f733b655287459be7dde073cc2760a76` |
| `mes_T001_1.mes` | `34753d597ba897484cca76e0f75cbb64ec36db680db1717063d979602b5e0157` |
| `mes_T001_ba.mes` | `975a217da7f27e07038df4e83bba425c705a6f297e78cb67cd998174b172ffd3` |
| `mes_T001_5.mes` | `ac94178f69486e69c1ec04aa30d1b6439b08be090190f28c43f25ed9964d3620` |
| `mes_T002_ba.mes` | `759cfa1a0c161b7b1e16c9749c601fbee3ba3dffd3de8f1af0d3bdd7f8e4b3b0` |
| `mes_Card.mes` | `32149a92aa170f012907f2616bb58e02ee7e99193516ca1c29f59642af96061a` |
| `mes_tips_Dan.mes` | `e143a9927234bd748683faa1eb617a6d4da1aaddc3e07eccc1b9c1dd9e4f3fa3` |
| `mes_command.mes` | `be5bc5d796a28758b706516857b5659febe531ac5526140951bba3b65e9f8f29` |
| `mes_T004_ba.mes` | `fd3be1c21a637dbac508658cff734dd79b662bd0e8ff3114e0042f766696e80b` |
| `mes_ControlBattle.mes` | `61206179d9371f7d9043fac6cb67507ce500d55e9aaab922a635653a394d84bb` |
| `mes_TIPS_sys.mes` | `129d2cad437514e5d25e198d6a8f3504303450ee252683729d0caab0a0c14e71` |

The raw ROM, BIOS and DS executable code are not included in the game release.

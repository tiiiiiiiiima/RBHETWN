# Wii 2009 rules: source audit for 0.6

Audit date: 2026-10-02. This document covers **Bakugan Battle Brawlers for Nintendo Wii (2009)**. It does not use Bakugan Battle Planet / the 2019 reboot as a rule source.

## Primary source

The Activision instruction booklet, mirrored by Games Database:

- [Bakugan Battle Brawlers — Nintendo Wii instruction booklet (PDF)](https://www.gamesdatabase.org/Media/SYSTEM/Nintendo_Wii//Manual/formated/Bakugan_Battle_Brawlers_-_2009_-_Activision.pdf)
- [Games Database entry](https://www.gamesdatabase.org/game/nintendo-wii/bakugan-battle-brawlers)

The booklet was downloaded and its scanned pages were read visually; OCR was used only to make searching easier. Page numbers below are the **printed booklet page numbers**, which also match the relevant PDF page numbers in this mirror. The mirror's PDF metadata creation date is 2026; that is an archive conversion date, not the game's release date.

## Official guide

A second source fills many of the booklet's omissions: **Bryan Dawson, Bakugan Battle Brawlers: Prima Official Game Guide, Prima Games, 2009**.

- [Public archive item](https://archive.org/details/bakuganbattlebrawlersprimaofficialguide)
- [Guide PDF](https://archive.org/download/bakuganbattlebrawlersprimaofficialguide/Bakugan%20Battle%20Brawlers%20Prima%20Official%20Guide.pdf)

This source explicitly distinguishes console rules from Nintendo DS differences. This audit uses its console rules, including the Wii-specific shooting clarification. The downloaded PDF contains selectable text, so table columns were checked from its layout rather than the archive's less reliable OCR. Its printed pages match PDF page numbers for the cited sections.

| Topic | Official-guide evidence | Consequence for the prototype |
| --- | --- | --- |
| Initial gates | Page 6: opening gates can only occupy one of four central positions. Page 9: each player selects one gate and puts it opposite their character's position. | Every player places one opening card before the first throw; do not allow arbitrary opening positions. The prototype's small board is an adaptation of the original battlefield. |
| Starting order | Page 9: after opening placement, turns proceed from player one to player four. | Fixed player order is documented. A dice roll or youngest-first rule would be a tabletop adaptation. |
| Optional placement | Page 10: each turn offers placement of **a single** gate before aiming and selecting a Bakugan. | Separate mandatory opening placement from the optional placement on an ordinary turn, and reject a second ordinary placement during the same turn. |
| Placement adjacency | Page 6: later gates must be directly right, left, above or below an existing gate. | Legal placement is orthogonal, never diagonal. |
| Empty field | Page 6: when no gates remain, every player must place a gate before the next turn. Page 122 explains that this repeats the beginning-of-match opportunity. | Reopen setup for both players before another throw, including when a capture removes the final gate. |
| Gate deck | Page 7: one Gold, one Silver and one Copper gate. | Normalize old saved selections and constrain new selections by color. |
| Ability deck | Page 7: one Red, one Green and one Blue ability. | An unrestricted three-card selection is not the documented Wii deck rule. |
| Spent Bakugan | Page 10: a Bakugan that lands on a card cannot be thrown again until all three have landed on a gate. | A capture should not silently make that Bakugan immediately reusable while unused Bakugan remain. The guide's wording does not explicitly address missed throws. |
| Double Stand choice | Pages 10–11: if another card is directly adjacent, choose between taking the card and moving **the last Bakugan thrown** to that adjacent card. | Direct capture remains valid, but offering relocation is also a documented Wii behavior. The simple booklet omits this choice. |
| Stay timing | Page 11: choose a Bakugan when the player's turn arrives with every Bakugan standing; if it remains there at their following turn, win the card. | Selection replaces a throw on that turn. The opponent receives a turn to challenge it. |
| Gate special effects | Page 6: Gold and Copper gates have special rules; a character gate can double the matching creature's **gate bonus**. | Double the attribute boost, not the creature's base G or all battle gains. |
| Gate reveal timing | Page 6: the attribute bonus is received “when the battle begins.” | Do not include an unrevealed gate boost in the standing creature's pre-battle Sphere Attack health. |
| Minigame colors | Page 6 table, confirmed again on pages 131–132: **Gold → Shooting; Silver → Timing; Copper → Shake**. | 0.5 had Gold and Silver reversed. Correct both game selection and explanatory card descriptions. |
| Minigame difficulty | Page 131: the leading player/team's captured gates determine the level: zero → level 1, one → level 2, two → level 3. | Difficulty progresses during the match; the settings difficulty can separately affect the CPU's skill. |
| Timing streak | Page 132: five correctly timed hits in succession activate extra G for subsequent hits until a miss. | Track successful timing streaks and reset them on a miss. Level 2 adds two-button / simultaneous prompts; level 3 adds shake prompts and rapid input sections. |
| Shooting streak | Page 132: five matching symbols in succession activate extra G until shooting the wrong attribute. | Reward sustained correct targeting, not indiscriminate clicks. |
| Shooting gold icon | Page 132: gold icons appear at levels 2–3 and award G for every attribute icon currently on-screen. | Gold is a screen-clear reward; its points depend on the available symbols. |
| Wii shooting | Page 133: Wii symbols move and the reticle aims freely; other consoles use stationary symbols in a ring. | Moving mouse targets are a suitable PC adaptation of Wii shooting; do not copy the other consoles' fixed ring as Wii behavior. |
| Shake level 2 | Page 131: random stop windows; shaking during those windows loses G. | Add stop prompts and penalties rather than increasing an unrestricted tapping rate. |
| Shake level 3 | Page 131: circle, horizontal or vertical shake instructions; incorrect movement loses G. | Distinct keyboard patterns can adapt these directional requirements. |
| Ability reuse | Page 7: abilities usually cannot be reused during a match; some gates return used abilities. | Keep a used-card area and support recovery as a card effect. Neither this page nor the booklet specifies a general one-ability-per-battle limit. |
| Sphere Attack | Page 11: damage depends on both Bakugan's stats; reducing G to zero **or knocking the defender off the gate** causes Critical K.O. and gives the attacker the gate. | The prototype's numeric damage formula must remain described as its own balance unless the original formula is verified. |

The Guide's page 123 advice to place a second gate yet stand on the original opening gate is **strategy advice**, not a prohibition on throwing onto a newly placed gate. Page 127 explicitly recommends placing a Quick Strike gate and immediately throwing onto it to guarantee the first-standing bonus.

## Rules explicitly confirmed by the Wii booklet

| Topic | Primary evidence | Consequence for the prototype |
| --- | --- | --- |
| Victory | Page 4: “The main goal of Bakugan is to win three Gate Cards.” | Keep the first-to-three-captured-gates objective. |
| Steering and landing | Page 4: a Bakugan stands when it rolls over a card “slowly”; after the throw players can steer and collect power-ups. | Slow contact / landing is meaningful; a fast crossing is not automatically a stand. |
| Battle and reveal | Page 4: “A battle begins when two Bakugan from different players stand on the same Gate Card. The Gate Card opens…” | Keep opponents on one card as the battle trigger; conceal an opponent's face-down gate bonuses until its reveal. |
| Gate effects | Page 4: the gate can add G-Power depending on the Bakugan's attribute “and they can also change the rules.” Page 6 likewise says cards can boost G-Power “or change rules to your favor.” | Attribute bonuses alone are incomplete; support printed / described card effects as well. Individual original card values are not listed in this booklet. |
| Battle result | Page 4: “The highest G-Power at the end of the battle wins!” | Add base, gate effects, retained roll items, abilities and battle-game gains before comparing. The booklet does not specify ties. |
| Double Stand | Page 7: “Get two of your Bakugan to stand on the same Gate Card and you can win the card without fighting!” | Direct Double Stand capture is an actual Wii rule; the Official Guide additionally confirms the optional adjacent relocation choice. |
| Stay | Page 7: “If you throw all of your Bakugan and they're all standing on cards, you need to pick a Bakugan to stay. If that Bakugan hasn't been Critical K.O.'d or battled by your next turn, you win the Gate Card!” | Replace the invented forced recall fallback with a selected Stay card, one opposing-turn response window, and capture on the owner's next turn if still uncontested. |
| Sphere Attack / Critical K.O. | Page 7: “Using a high-powered throw you can knock your opponent's G-Power down. If you knock it down to zero, you cause a Critical K.O. and win the card!” | High-power throws should have an explicit attack consequence rather than differing only in final position. The booklet does not give a numeric damage formula. |
| Pick-up retention | Page 7: “You've got to stand on a card to keep the item.” | Missed / off-board throws must discard acquired roll items. They should not count as retained G-Power. |
| Abilities | Page 6: abilities can “change rules before or during a battle” and “add additional G-Power or have other effects.” | The former battle-only universal +G implementation is too narrow. Exact playable windows must be stated per card. The booklet does not state a one-card-per-battle limit or color quota. |
| Shaking battle | Page 6: shake the Wii Remote to gain G-Power; three difficulty levels. | Keyboard repeated presses are a PC adaptation of the shaking game. |
| Timing battle | Page 6: “Press the correct buttons or shake the Wii Remote as the icons pass”; three difficulty levels. | Timing is a sequence of required inputs, not merely one universal click regardless of icon. |
| Shooting battle | Page 6: “Shoot the icons that match your Bakugan's Attribute (look at the color!). Hit gold icons for a big bonus!”; three difficulty levels. | Add attribute-matching targets and gold targets. Awarding every target equally contradicts the documented Wii game. |
| Normal / Power throw | Page 5: moving the selected ball up/down chooses Normal Shot; left/right chooses Power Shot; a faster Wii Remote swing makes a stronger throw. | Normal and Power are distinct choices. Keyboard charging substitutes for the remote gesture. |
| Special Shots | Page 6: unlock at Bakugan level 5; unique per attribute; require a full S-Power meter, which charges during other players' turns. | This is a separate progression mechanic. Do not describe ordinary Power Shot as the original level-5 Special Shot. |

## Remaining uncertainties

The booklet alone omits setup, adjacency, deck quotas, recycling, original card values and the color/minigame mapping; the Official Guide resolves most of these omissions. A Wii tie rule, exact treatment of missed throws in the reserve cycle, a general ability-per-battle limit, minigame duration / precise point values and numeric Sphere Attack formula remain unverified in the reviewed passages. Classic tabletop rules may fill a gap only when the Wii rule is unavailable; any such fallback must be labeled and must not silently override confirmed Wii behavior.

The booklet's screenshots do not provide a readable full card database. For the cards selected for 0.6, names, attribute boosts, printed conditions and serials were checked against the Guide's **console card database, pages 178–199**, separately from its Nintendo DS database. Card artwork was not copied into the project. Russian explanatory text is a new translation, not an extracted Wii interface asset.

## Verified console card subset

Attribute order in the numeric table is **Pyrus, Aquos, Subterra, Haos, Darkus, Ventus**. A character rule doubles only the matching creature's gate bonus. “None” means no additional printed rule, not the absence of attribute bonuses.

| Gate | Color | Attribute boosts | Printed-rule meaning | Guide page / serial |
| --- | --- | --- | --- | --- |
| Leonidas | Gold | 160 / 140 / 120 / 160 / 120 / 140 | Leonidas receives the gate bonus twice | 180 / VG025-GA-SM |
| Aquos Vortex | Silver | 60 / 150 / 120 / 50 / 20 / 20 | None | 183 / BA244-GA-SM |
| Ability Block | Copper | 20 / 0 / 20 / 0 / 20 / 0 | No Ability Cards may be played | 187 / BA154-GA-SM |
| Dragonoid | Gold | 170 / 110 / 80 / 130 / 100 / 140 | Dragonoid receives the gate bonus twice | 178 / VG001-GA-SM |
| The Cliffs | Silver | 120 / 100 / 150 / 50 / 100 / 50 | None | 183 / BA247-GA-SM |
| Quick Strike | Copper | 250 / 200 / 300 / 250 / 200 / 150 | First-standing Bakugan receives +100 G | 189 / BA266-GA-SM |
| Griffon | Gold | 110 / 40 / 120 / 80 / 120 / 120 | Griffon receives the gate bonus twice | 179 / VG020-GA-SM |
| Sunrise | Silver | 20 / 20 / 60 / 140 / 120 / 80 | None | 186 / BA202-GA-SM |
| Stand Your Ground | Copper | 20 / 80 / 140 / 50 / 60 / 110 | After the battle, all players regain all Ability Cards | 190 / BA156-GA-SM |

| Ability | Color | Printed condition and effect | Guide page / serial |
| --- | --- | --- | --- |
| Battle Gate | Red | +100 G if the two battling attributes differ | 191 / BA194-AB-SM |
| Alpha Blaster | Green | Leonidas receives +200 G | 193 / VG027-AB-SM |
| G-Power Boost | Blue | +60 G during battle; Pyrus, Subterra or Darkus | 197 / BA166-AB-SM |
| Quick Draw | Red | Selects a Shooting Battle | 192 / VG008-AB-SM |
| Boosted Dragon | Green | Dragonoid receives +200 G | 193 / VG011-AB-SM |
| G-Power Bump | Blue | +60 G during battle; Aquos, Haos or Ventus | 197 / BA167-AB-SM |
| Mega Impact | Green | Gorem receives +200 G | 195 / VG016-AB-SM |

Stand Your Ground specifies **after the battle**. Returning abilities on a Double Stand or STAY capture would add a trigger that is not printed on that card. Ability Block prohibits ability use for both participants. The two blue +60 G cards have complementary attribute restrictions and should not be merged into one universal boost.
The selected Mega Impact is the **green Gorem card VG016-AB-SM**, not the separate blue card of the same English title.

## 0.5 findings

The 0.5 rules already had three-gate victory, opposed landing battles and Double Stand capture. They also contained public gate bonuses immediately after placement, unrestricted color composition, challenger-wins ties, immediate ball recycling at turn end / capture, generic stat cards, a forced recall when all units stand and a single ability use per battle. Gold and Silver minigames were reversed. The source tables above separate verified corrections from remaining assumptions. Fixed player-one-first order is consistent with the Official Guide.

The audit checks whether the implemented state transitions follow the documented rule. Hundreds of assertion checks are not hundreds of different playtests and cannot prove an exact Wii recreation. Visual checks, complete-match playthroughs and operating-system launch checks remain different kinds of validation.

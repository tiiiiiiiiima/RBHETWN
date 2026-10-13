# Original Nintendo DS reference verification

## Additional gameplay after release 0.18

The running original was played beyond the earlier Throwing Controls
sample: tutorials 1 and 2 were completed, including a successful tutorial
Scratch, and a complete Battle Arena / Single Player / 1-vs-1 match on
the starting arena was played against Shuji (Easy). The ordinary match
ended in defeat. Captures verify throws and steering, native per-Bakugan
statistics, an opposed gate battle, Blaze activation during Scratch,
AI Double Stand captures and the final match statistics screen.

Evidence and timestamps: `builds/qa-reference-play/input.jsonl`,
`builds/qa-reference-play/visual/`, and
`builds/qa-reference-play/reference-summary.json`.
See [observed differences and priorities](DS-GAMEPLAY-COMPARISON.md).

This is not campaign progression to Pyrus. The original Pyrus hazards,
physics coefficients, timing, audio and full six-minigame set remain
unverified by this gameplay session. Pauses between tool calls and an
unmeasured emulation rate prevent treating wall-clock timestamps as
original animation or physics timing. This additional work changes
documentation and evidence only, not game scripts or the 0.18 ZIP.

## Update 2026-10-09 / release 0.18

The authorized B6RE ROM was successfully booted in the official Debian
DeSmuME 0.9.13 SDL2 frontend using HLE, without external BIOS. Tutorial
3, Throwing Controls, was reached and an upward stylus throw executed.
Recorded frames show the free rolling sphere, tracking camera and retry
after an unsuccessful throw. Tutorial messages confirm D-pad aiming
before launch and short separate stylus strokes for steering.

Evidence: `builds/qa-0.18/original-reference.json`, aim/steering screenshots,
and 28 post-launch images in `builds/qa-0.18/visual/original-throw/`.
This is qualitative verification only: emulated frame rate, original
physics coefficients, Pyrus damage, battle sequences and animation
timing were not measured. Emulator, ROM and save files stay outside
the project and releases. See [0.18 comparison](DS-PHYSICS-0.18.md).

## Earlier attempt

Status recorded 2026-10-05: no original battle footage or emulator frame capture was obtained in this session.

The user-authorized ROM archive was found at `/workspace/bakugan-ds-import/Bakugan-DS.zip`. It was not copied into the game project, release, or build. No ROM or BIOS was downloaded.

An official Debian DeSmuME package fetch was proposed to run the authorized ROM locally with HLE. The setup did not produce a downloaded emulator, footage, or captured frame. The final local setup attempt failed before a process could start with `exec-server transport disconnected`. Earlier calls were aborted when the session paused. On the last successful filesystem inspection, `/workspace/bakugan-ds-import/emulator` did not exist.

## Verification limits of the earlier attempt (historical)

- Original DS battle screen composition: unverified.
- Original DS camera placement and transition sequence: unverified.
- Original DS battle animation timing: unverified.
- A faithful sequence comparison against running DS gameplay: not performed.

The game's imported native DS resources and current implementation can be reviewed on their own, but they do not establish that its layout, camera, or sequence matches the original game. Any such claim requires actual DS gameplay frames or footage and a separate comparison.

This reference work made no game/runtime changes. Packaging may proceed independently of this blocked optional capture.

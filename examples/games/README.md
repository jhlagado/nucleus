# Small CP/M games

These standalone Nucleus sources use console input and output. Put the source
on a writable drive. With the compiler on A and source on B:

```text
B:
A:NUC GUESS.NU
GUESS
A:NUC MATCH23.NU
MATCH23
```

Input is a single key; Enter is optional. CP/M echoes keys, so these programs
do not echo them again. Keep each constant declaration on one physical line.

## Guess my number

`GUESS.NU` demonstrates strings, procedures, a loop, validation and comparisons.
The secret is currently fixed at 7. A seedable random-number library is the
next extension, not a feature of this version.

## 23 matches

`MATCH23.NU` follows the NIM routine in Debug80's TEC-1 MON1B ROM source:
`apps/debug80-vscode/resources/bundles/tec1/mon1b/v1/mon-1b.asm`,
from `NIM` at $03E0 through `NIMADJUST`.

There are 23 matches. The human goes first, taking 1, 2 or 3 each turn.
Taking the last match loses. As in MON1, requesting more than the remaining
matches also loses. Leaving exactly one match gives the human an immediate win.
Q exits to CP/M; rerun MATCH23 for another game.

After a human move, the computer takes `(matches - 1) mod 4` when nonzero.
This leaves 1, 5, 9, 13, 17 or 21 for the human. The ROM uses the low two bits
of the Z80 refresh register R when that remainder is zero, changing zero to
one. This portable version takes one in that case. It does not reproduce
the ROM's timing-dependent fallback, LED display or automatic restart.

## Verification

The development-only replay accepts an explicitly supplied Triptych checkout
with built `dist/wasm` and `dist/wasm-browser` artifacts:

```sh
node examples/games/check-cpm.cjs /path/to/triptych
```

It uses the pinned Nucleus compiler shipped with Triptych, compiles both
sources on writable B, then runs the generated Z80 programs under CP/M.
Checks cover guessing outcomes, invalid keys, both matches-game outcomes,
taking too many matches, and quitting. Each COM occupies 25,600 bytes under
that compiler's fixed-layout output profile. This is an emulated execution
proof, not a TEC-1 hardware measurement. Triptych is a development dependency
for this replay only; the game sources depend solely on Nucleus services.

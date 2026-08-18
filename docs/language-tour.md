# A small Nucleus program

This program builds and writes `OK!`. It also exercises the parts of Nucleus
that can look unrelated on first encounter: program-lifetime aggregate storage,
open views, nested arrays, signed arithmetic, and recoverable failure.

The complete source is [`language-tour.nu`](../examples/language-tour.nu).

## Storage first

```nucleus
var Message as string[3] = ""
var Letters as u8[2] = ['O', 'K']
var Grid as i16[3][2] = [[10, 20], [30, 40], [50, 60]]
var RecoveredCode as u8
```

Arrays and strings have program lifetime. Routines receive views of that
storage instead of allocating aggregate locals. `Grid` has three rows, each
containing two `i16` values; `Grid[2][1]` selects the second value in the third
row.

## Constructing bounded text

```nucleus
sub appendAll(values as u8[], text as string[]) fails
    var index as u16
    var position as u8

    for index = 0 until values.length
        if text.length = text.capacity
            fail 1
        end

        position = text.length
        text.length = position + 1
        text[position] = values[index]
    end
end
```

`string[]` is a parameter-only view of any complete `string[N]`. It retains the
concrete capacity and may change the string's length. `u8[]` similarly accepts
any complete `u8[N]` and retains its actual element count. Its `.length` is a
`u16`, so the loop uses a `u16` counter.

Appending checks the text capacity, extends the length, then writes the newly
valid position. The operation returns error code `1` when the string is full.
Text operations such as this belong in source libraries. The compiler supplies
checked length, capacity, and indexing operations rather than a separate family
of string-building intrinsics.

## Nested arrays and signed counters

```nucleus
sub main() fails
    var row as i8

    for row = -1 to 1
        Grid[u8(row + 1)][1] = Grid[u8(row + 1)][1] + row
    end
end
```

The signed `i8` counter visits `-1`, `0`, and `1`. Adding one produces the array
indexes `0`, `1`, and `2`; the explicit `u8` conversion records that those
values are valid non-negative indexes. The second index selects a value within
each row.

After the call, the second column of `Grid` is `19`, `40`, and `61`.

## Propagation and recovery

```nucleus
sub main() fails
    var code as u8

    appendAll(Letters, Message) else fail

    appendAll(Letters, Message) handle code
        RecoveredCode = code
    end
end
```

The first call fills the three-byte `Message` with `OK!`; `else fail` would
immediately return any failure from `main`. The second call fails because the
string is already full. `handle code` stores error code `1` in the existing
local `code`, runs the handler body, and then continues after `end`. The failed
append does not change `Message`, so the final output loop writes `OK!`.

`else fail` and `handle` are two consumers of a direct failable call. The first
passes failure to the caller; the second handles it at the call site. Safety
traps such as an out-of-bounds index are separate and cannot be handled this
way.

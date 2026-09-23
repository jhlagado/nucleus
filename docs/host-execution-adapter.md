# Nucleus compiler execution adapter

The compiler image is a Z80 program, but the Nucleus compiler host does not
own a particular emulator. `compileNucleus` accepts an optional
`NucleusExecutionAdapter` with this shape:

```ts
{
  parseImage(hexText): {
    memory: Uint8Array;
    startAddress: number;
    writeRanges?: readonly { start: number; end: number }[];
  };
  create({ image, entry, write }): {
    hardware: { memory: Uint8Array };
    cpu: {
      a: number; b: number; c: number; d: number; e: number;
      h: number; l: number; ix: number; iy: number; sp: number; pc: number;
      halted: boolean;
      flags: { C: number };
    };
    step(): { cycles?: number };
    isHalted(): boolean;
  };
}
```

The default `createDebug80ExecutionAdapter()` is the current development and
reference implementation. A Triptych native or WASM adapter may replace it
without changing Nucleus source preparation, diagnostics, NOBJ publication or
the compiler's target contract. The replacement must preserve the selected
image bytes, reset state, memory writes, port-write callback, register and flag
semantics, halt result and cycle accounting.

This is a host seam, not a claim that any arbitrary Z80 machine can run the
compiler image. The active compiler-image build still has its historical AZM
path until the ATOM reconciliation stage proves a replacement artifact.

## Triptych WASM adapter

`createTriptychWasmExecutionAdapter()` is an opt-in compiler-host adapter. It
receives Triptych's `TriptychCpu` constructor from the caller and implements
the existing Nucleus execution seam without importing Rust, Triptych or a
browser runtime into the compiler package. Compiler memory and the registers
needed by the seam remain ordinary host values; the adapter synchronises them
at each instruction boundary and translates Triptych's observed output-port
operations to the existing `write(port, value)` callback.

The boundary predicate is intentionally separate from the normal package
checks because it needs a built Triptych WASM module:

```sh
TRIPTYCH_WASM_MODULE=/path/to/triptych/dist/wasm/triptych_host_wasm.js \
  npm run verify:triptych-wasm
```

It compares a compiler run through Debug80 Runtime with the same run through
Triptych WASM, including NOBJ bytes, the materialised image and Intel HEX
identity. Debug80 remains a differential development oracle; this does not
make it a production dependency of Triptych.

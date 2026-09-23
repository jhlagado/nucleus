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

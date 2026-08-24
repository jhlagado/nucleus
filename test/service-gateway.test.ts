import path from "node:path";
import { fileURLToPath } from "node:url";

import { compile } from "@jhlagado/azm/compile";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

import {
  compileNucleus,
  defaultNucleusServices,
  type NucleusCompileSuccess,
} from "../src/compiler.js";
import { executeCommittedNobj } from "../src/proof.js";

const statusAddress = 0x7200;
const trapNumberAddress = statusAddress + 1;
const trapOffsetAddress = statusAddress + 2;
const invocationCountAddress = statusAddress + 4;
const services = {
  ...defaultNucleusServices,
  success: 0x7180,
  unhandledFailure: 0x7188,
  trap: 0x7190,
  packetService: 0x7021,
};

const terminal = (status: number): readonly number[] => [
  0x3e,
  status,
  0x32,
  statusAddress & 0xff,
  statusAddress >>> 8,
  0x76,
];

const trapService: readonly number[] = [
  0x32,
  trapNumberAddress & 0xff,
  trapNumberAddress >>> 8,
  0x22,
  trapOffsetAddress & 0xff,
  trapOffsetAddress >>> 8,
  ...terminal(3),
];

const echoProvider: readonly number[] = [
  0xfe, 0x00, 0x20, 22, 0x78, 0xb7, 0x20, 5, 0x79, 0xfe, 0x02, 0x38, 13,
  0x3a, invocationCountAddress & 0xff, invocationCountAddress >>> 8, 0x3c,
  0x32, invocationCountAddress & 0xff, invocationCountAddress >>> 8, 0x7e,
  0x3c, 0x23, 0x77, 0xb7, 0xc9, 0x3e, 0x07, 0x37, 0xc9,
];

const mon3ScanKeys = (
  key: number,
  state: "new" | "held" | "none",
): readonly number[] => [
  0x3a,
  invocationCountAddress & 0xff,
  invocationCountAddress >>> 8,
  0x3c,
  0x32,
  invocationCountAddress & 0xff,
  invocationCountAddress >>> 8,
  0x3e,
  key,
  ...(state === "new" ? [0xbf, 0x37] : state === "held" ? [0xbf] : [0xb7]),
  0xc9,
];

const providerBytes = async (): Promise<readonly number[]> => {
  const fixture = fileURLToPath(
    new URL("fixtures/mon3-packet-service-proof.asm", import.meta.url),
  );
  const assembled = await compile(fixture, {
    includeDirs: [path.dirname(fixture)],
    emitBin: false,
    emitHex: true,
    emitD8m: true,
    registerContracts: "strict",
  });
  const errors = assembled.diagnostics.filter(
    (diagnostic) => diagnostic.severity === "error",
  );
  expect(errors).toEqual([]);
  const hex = assembled.artifacts.find((artifact) => artifact.kind === "hex");
  const map = assembled.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || map?.kind !== "d8m") {
    throw new Error("MON-3 provider assembly omitted HEX or D8M");
  }
  const end = map.json.symbols.find(
    (symbol) => symbol.name === "PacketServiceEnd",
  );
  const endAddress = end?.address ?? end?.value;
  if (endAddress === undefined) throw new Error("provider end is unavailable");
  return Array.from(parseIntelHex(hex.text).memory.slice(0x7021, endAddress));
};

const execute = async (
  built: NucleusCompileSuccess,
  options: {
    readonly key?: number;
    readonly state?: "new" | "held" | "none";
    readonly packetProvider?: readonly number[];
    readonly bankSwitch?: {
      readonly port: number;
      readonly windowBase: number;
      readonly windowCapacity: number;
    };
  } = {},
) =>
  executeCommittedNobj(built.nobj, {
    maxInstructions: 100_000,
    maxCycles: 1_000_000,
    halted: true,
    initialSp: 0x6ff0,
    expectedSp: 0x6ff0,
    expectedIx: 0,
    expectedIy: 0,
    writes: [
      {
        at: 0x0010,
        bytes: mon3ScanKeys(options.key ?? 0x41, options.state ?? "new"),
      },
      {
        at: services.packetService,
        bytes: options.packetProvider ?? (await providerBytes()),
      },
      { at: services.success, bytes: terminal(1) },
      { at: services.unhandledFailure, bytes: terminal(2) },
      { at: services.trap, bytes: trapService },
    ],
  }, options.bankSwitch === undefined ? undefined : { bankSwitch: options.bankSwitch });

const position = (source: string, token: string, from = 0) => {
  const offset = source.indexOf(token, from);
  const prefix = source.slice(0, offset);
  const lines = prefix.split("\n");
  return {
    offset,
    line: lines.length,
    column: (lines.at(-1)?.length ?? 0) + 1,
  };
};

const stateBase = (built: NucleusCompileSuccess): number =>
  built.materialized.parsed.map.vectorBase +
  built.materialized.parsed.map.vectorLength;

const programDataBase = (built: NucleusCompileSuccess): number =>
  stateBase(built) + 41;

describe("packet-based service gateway", () => {
  it("passes exact slots and writable concrete/open u8 packets to MON-3", async () => {
    const source = [
      "const scanKeys = 1",
      "var first as u8[3] = [0, 0, 0]",
      "var second as u8[4] = [9, 9, 9, 77]",
      "sub relay(packet as u8[])",
      "service(scanKeys, packet)",
      "end",
      "sub main()",
      "service(1, first)",
      "relay(second)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "service.nu", source }], {
      writableBase: 0x4000,
      writableCapacity: 0x1000,
      establishStack: false,
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = await execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[invocationCountAddress]).toBe(2);
    expect(executed.memory[stateBase(built) + 6]).toBe(0);
    const base = programDataBase(built);
    expect(Array.from(executed.memory.slice(base, base + 3))).toEqual([
      0x41, 1, 1,
    ]);
    expect(Array.from(executed.memory.slice(base + 3, base + 7))).toEqual([
      0x41, 1, 1, 77,
    ]);
  });

  it.each([
    ["new", 0x41, [0x41, 1, 1]],
    ["held", 0x42, [0x42, 1, 0]],
    ["none", 0xff, [0xff, 0, 0]],
  ] as const)("normalizes MON-3 %s-key flags", async (state, key, expected) => {
    const source = [
      "var packet as u8[3] = [0, 0, 0]",
      "sub main()",
      "service(1, packet)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: `${state}.nu`, source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = await execute(built, { key, state });
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[invocationCountAddress]).toBe(1);
    const base = programDataBase(built);
    expect(Array.from(executed.memory.slice(base, base + 3))).toEqual(expected);
  });

  it.each([
    ["service(true, packet)", 60, "true"],
    ["service(256, packet)", 61, "256"],
    ["service(-1, packet)", 61, "1"],
    ["service(slot, packet)", 60, "slot"],
    ["service(1, scalar)", 60, "scalar"],
    ["service(1, text)", 60, "text"],
    ["service(1, readonly)", 60, "readonly"],
    ["service(1, recordValue)", 60, "recordValue"],
    ["service(1, words)", 60, "words"],
  ] as const)("rejects %s at the offending argument", async (line, code, token) => {
    const source = [
      "record Item",
      "value as u8",
      "end",
      "var slot as u8 = 1",
      "var scalar as u8",
      'var text as string[3] = "abc"',
      "const readonly as u8[3] = [1, 2, 3]",
      "var recordValue as Item = (1)",
      "var words as u16[3]",
      "var packet as u8[3]",
      "sub main()",
      line,
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "invalid-service.nu", source }], {
      services,
    });
    expect(built.success).toBe(false);
    if (built.success) return;
    expect(built.diagnostic).toMatchObject({
      code,
      sourcePart: 1,
      sourceName: "invalid-service.nu",
      ...position(source, token, source.indexOf(line)),
    });
  });

  it.each([0, 255] as const)(
    "traps unknown slot %i before mutating the packet",
    async (slot) => {
    const source = [
      "var packet as u8[3] = [7, 8, 9]",
      "sub main()",
      `service(${slot}, packet)`,
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "unknown.nu", source }], {
      writableBase: 0x4000,
      writableCapacity: 0x1000,
      establishStack: false,
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = await execute(built);
    expect(executed.memory[statusAddress]).toBe(3);
    expect(executed.memory[stateBase(built) + 1]).toBe(7);
    expect(
      executed.memory[stateBase(built) + 3] |
        ((executed.memory[stateBase(built) + 4] ?? 0) << 8),
    ).toBe(source.indexOf("service"));
    expect(executed.memory[invocationCountAddress]).toBe(0);
    const base = programDataBase(built);
    expect(Array.from(executed.memory.slice(base, base + 3))).toEqual([7, 8, 9]);
    },
  );

  it("evaluates one nested packet path and confines provider writes to its extent", async () => {
    const source = [
      "var calls as u8",
      "var before as u8 = $A5",
      "var packets as u8[2][2] = [[10, 0], [20, 0]]",
      "var after as u8 = $5A",
      "sub choose() as u8",
      "calls = calls + 1",
      "return 1",
      "end",
      "sub main()",
      "service(0, packets[choose()])",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "path.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = await execute(built, { packetProvider: echoProvider });
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[invocationCountAddress]).toBe(1);
    expect(executed.memory[built.materialized.parsed.map.bssBase]).toBe(1);
    const base = programDataBase(built);
    expect(Array.from(executed.memory.slice(base, base + 6))).toEqual([
      0xa5, 10, 0, 20, 21, 0x5a,
    ]);
  });

  it("traps a one-byte-short packet before native dispatch or mutation", async () => {
    const source = [
      "var before as u8 = $A5",
      "var packet as u8[1] = [10]",
      "var after as u8 = $5A",
      "sub main()",
      "service(0, packet)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "short.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = await execute(built, { packetProvider: echoProvider });
    expect(executed.memory[statusAddress]).toBe(3);
    expect(executed.memory[trapNumberAddress]).toBe(7);
    expect(executed.memory[invocationCountAddress]).toBe(0);
    expect(
      executed.memory[stateBase(built) + 3] |
        ((executed.memory[stateBase(built) + 4] ?? 0) << 8),
    ).toBe(source.indexOf("service"));
    const base = programDataBase(built);
    expect(Array.from(executed.memory.slice(base, base + 3))).toEqual([
      0xa5, 10, 0x5a,
    ]);
  });

  it("rejects the MON-3 one-byte-short extent before RST or mutation", async () => {
    const source = [
      "var packet as u8[2] = [10, 11]",
      "sub main()",
      "service(1, packet)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "short-mon3.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = await execute(built);
    expect(executed.memory[statusAddress]).toBe(3);
    expect(executed.memory[trapNumberAddress]).toBe(7);
    expect(executed.memory[invocationCountAddress]).toBe(0);
    const base = programDataBase(built);
    expect(Array.from(executed.memory.slice(base, base + 2))).toEqual([10, 11]);
  });

  it.each([
    "service(1)",
    "service(1, packet, packet)",
    "service(1, packet) else fail",
    "service(1, packet) handle code\nend",
    "value = service(1, packet)",
  ])("rejects the non-statement form %s", async (statement) => {
    const source = [
      "var packet as u8[3]",
      "var value as u8",
      "var code as u8",
      "sub main() fails",
      statement,
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "service-form.nu", source }], {
      services,
    });
    expect(built.success).toBe(false);
    if (built.success) return;
    expect(built.diagnostic.sourcePart).toBe(1);
    expect(built.diagnostic.sourceName).toBe("service-form.nu");
    expect(built.diagnostic.line).toBe(5);
  });

  it("rejects a transient aggregate result as the packet root", async () => {
    const source = [
      "var packet as u8[3]",
      "sub selected() as u8[3]",
      "return packet",
      "end",
      "sub main()",
      "service(1, selected())",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "transient.nu", source }], {
      services,
    });
    expect(built.success).toBe(false);
    if (built.success) return;
    expect(built.diagnostic).toMatchObject({
      sourcePart: 1,
      sourceName: "transient.nu",
      ...position(source, "selected", source.indexOf("service")),
    });
  });

  it.each([0, 1] as const)(
    "keeps bank %i selected across the always-visible gateway",
    async (entryBank) => {
      const source = [
        "var packet as u8[2] = [8, 0]",
        "sub main()",
        "service(0, packet)",
        "end",
        "",
      ].join("\n");
      const built = await compileNucleus(
        [{ name: `bank-${entryBank}.nu`, source }],
        {
          bankCount: 2,
          entryBank,
          partBanks: [entryBank],
          imageBase: 0x8000,
          imageCapacity: 0x1000,
          writableBase: 0x4000,
          writableCapacity: 0x1000,
          services: { ...services, farCall: 0x7000, farJump: 0x7080 },
        },
      );
      if (!built.success) throw new Error(JSON.stringify(built));
      const executed = await execute(built, {
        packetProvider: echoProvider,
        bankSwitch: { port: 0x7f, windowBase: 0x8000, windowCapacity: 0x1000 },
      });
      expect(executed.memory[statusAddress]).toBe(1);
      expect(executed.selectedBank).toBe(entryBank);
      const base = programDataBase(built);
      expect(Array.from(executed.memory.slice(base, base + 2))).toEqual([8, 9]);
    },
  );

  it("maps the complete generated gateway to the service statement", async () => {
    const source = [
      "var packet as u8[3]",
      "sub main()",
      "service(1, packet)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "mapped.nu", source }],
      { services },
      { debugMap: true },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const segment = built.debugMapping?.maps[0]?.map.files["mapped.nu"]?.segments?.find(
      ({ line }) => line === 3,
    );
    expect(segment).toBeDefined();
    const image = built.materialized.flatImage;
    if (image === undefined || segment === undefined) {
      throw new Error("flat gateway segment is unavailable");
    }
    const start = segment.start - built.materialized.parsed.begin.imageBase;
    const bytes = image.slice(start, start + segment.end - segment.start);
    expect(Array.from(bytes)).toEqual([
      0x21, 0x4d, 0x40, 0xe5, 0xd1, 0x21, 0x03, 0x00, 0xe5, 0xd5,
      0x3e, 0x01, 0xe1, 0xc1, 0x11, 0x00, 0x83, 0xd5, 0x11, 0x1f,
      0x00, 0xcd, 0x21, 0x40,
    ]);
  });

  it("retains multipart trap attribution at the service statement", async () => {
    const parts = [
      { name: "model.nu", source: "var packet as u8[2] = [10, 11]\n" },
      { name: "main.nu", source: "sub main()\nservice(1, packet)\nend\n" },
    ];
    const built = await compileNucleus(parts, { services }, { debugMap: true });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = await execute(built);
    expect(executed.memory[statusAddress]).toBe(3);
    const offset = parts[1]!.source.indexOf("service");
    expect(
      executed.memory[stateBase(built) + 3] |
        ((executed.memory[stateBase(built) + 4] ?? 0) << 8),
    ).toBe(offset);
    expect(
      built.debugMapping?.maps[0]?.map.files["main.nu"]?.segments?.some(
        ({ line, column, start, end }) =>
          line === 2 && column === 1 && start < end,
      ),
    ).toBe(true);
  });

  it("assembles the compact MON-3 provider to 37 bytes", async () => {
    expect((await providerBytes()).length).toBe(37);
  });

  it("resets after rejection and reproduces the valid artifact", async () => {
    const valid = "var packet as u8[3]\nsub main()\nservice(1, packet)\nend\n";
    const first = await compileNucleus([{ name: "reset.nu", source: valid }], {
      services,
    });
    const rejected = await compileNucleus(
      [{ name: "reset.nu", source: "sub main()\nservice(true, packet)\nend\n" }],
      { services },
    );
    const recovered = await compileNucleus(
      [{ name: "reset.nu", source: valid }],
      { services },
    );
    expect(first.success).toBe(true);
    expect(rejected.success).toBe(false);
    expect(recovered.success).toBe(true);
    if (!first.success || !recovered.success) return;
    expect(recovered.nobj).toEqual(first.nobj);
  });
});

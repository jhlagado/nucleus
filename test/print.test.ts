import { readFileSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  compileNucleus,
  defaultNucleusServices,
  type NucleusCompileResult,
} from "../src/compiler.js";
import { executeCommittedNobj } from "../src/proof.js";

const services = {
  ...defaultNucleusServices,
  writeOutputByte: 0x7100,
  success: 0x7180,
  unhandledFailure: 0x7181,
  trap: 0x7182,
};

const outputLength = 0x7200;
const outputBase = outputLength + 1;

const outputService = [
  0x5f, // LD E,A
  0x3a,
  outputLength & 0xff,
  outputLength >>> 8, // LD A,(outputLength)
  0x4f, // LD C,A
  0x06,
  0x00, // LD B,0
  0x21,
  outputBase & 0xff,
  outputBase >>> 8, // LD HL,outputBase
  0x09, // ADD HL,BC
  0x7b, // LD A,E
  0x77, // LD (HL),A
  0x3a,
  outputLength & 0xff,
  outputLength >>> 8, // LD A,(outputLength)
  0x3c, // INC A
  0x32,
  outputLength & 0xff,
  outputLength >>> 8, // LD (outputLength),A
  0xaf, // XOR A
  0xc9, // RET
];

const terminalWrites = [
  { at: services.success, bytes: [0x76] },
  { at: services.unhandledFailure, bytes: [0x76] },
  { at: services.trap, bytes: [0x76] },
] as const;

const compile = async (source: string): Promise<NucleusCompileResult> =>
  compileNucleus([{ name: "print.nu", source }], { services });

describe("the polymorphic print intrinsic", () => {
  it("supports a measured TEC-1-style menu and value display", async () => {
    const source = readFileSync(
      path.resolve(import.meta.dirname, "..", "examples", "tec1-console.nu"),
      "utf8",
    );
    const built = await compile(source);
    expect(built.success).toBe(true);
    if (!built.success) return;
    const bank = built.materialized.parsed.map.banks[0];
    expect(new TextEncoder().encode(source)).toHaveLength(1_034);
    expect(built.instructions).toBe(311_818);
    expect(built.cycles).toBe(3_101_195);
    expect(built.nobj).toHaveLength(13_837);
    expect(bank?.usedLength).toBe(2_299);
    expect(bank?.readOnlyLength).toBe(158);
    expect(bank?.aggregateConstantLength).toBe(88);
    expect(
      (bank?.usedLength ?? 0) -
        ((bank?.readOnlyBase ?? 0) -
          built.materialized.parsed.begin.imageBase) -
        (bank?.readOnlyLength ?? 0),
    ).toBe(1_706);
    const executed = executeCommittedNobj(built.nobj, {
      maxInstructions: 20_000,
      maxCycles: 200_000,
      halted: true,
      writes: [
        { at: services.readInputByte, bytes: [0x3e, "2".charCodeAt(0), 0xc9] },
        { at: services.writeOutputByte, bytes: outputService },
        ...terminalWrites,
      ],
    });
    const length = executed.memory[outputLength] ?? 0;
    expect(
      new TextDecoder().decode(
        executed.memory.slice(outputBase, outputBase + length),
      ),
    ).toBe("\r\nTEC-1 TOOLBOX\r\n1 BYTE  2 WORD  Q QUIT\r\n> WORD: 1234\r\n");
    expect(executed.memory[0x4021]).toBe(2);
  });

  it("prints bounded strings of different capacities from library code", async () => {
    const source = [
      'const empty as string[1] = ""',
      'const short as string[5] = "H\\0i"',
      'const longer as string[9] = "Nucleus!"',
      "sub emitShort(text as string[5]) fails",
      "print(text) else fail",
      "end",
      "sub main() fails",
      "print(empty) else fail",
      "emitShort(short) else fail",
      "print(longer) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compile(source);
    expect(built.success).toBe(true);
    if (!built.success) return;
    const executed = executeCommittedNobj(built.nobj, {
      maxInstructions: 20_000,
      maxCycles: 200_000,
      halted: true,
      writes: [
        { at: services.writeOutputByte, bytes: outputService },
        ...terminalWrites,
      ],
    });
    const length = executed.memory[outputLength] ?? 0;
    expect(
      Array.from(executed.memory.slice(outputBase, outputBase + length)),
    ).toEqual([
      "H".charCodeAt(0),
      0,
      "i".charCodeAt(0),
      ...new TextEncoder().encode("Nucleus!"),
    ]);
    expect(executed.memory[0x4021]).toBe(2); // RunSucceeded
  });

  it("prints a bank-local string through a real cross-bank call", async () => {
    const proofManifest = JSON.parse(
      readFileSync(
        path.resolve(
          import.meta.dirname,
          "..",
          "proofs",
          "banked-target-z80-slice-proof.json",
        ),
        "utf8",
      ),
    ) as {
      nobj: { execution: { writes: { at: number; bytes: number[] }[] } };
    };
    const adapter = (address: number): number[] =>
      proofManifest.nobj.execution.writes.find(({ at }) => at === address)
        ?.bytes ?? [];
    expect(adapter(0x7000).length).toBeGreaterThan(0);
    expect(adapter(0x7080).length).toBeGreaterThan(0);

    const bankedServices = {
      readInputByte: 0x7300,
      writeOutputByte: services.writeOutputByte,
      readStorageByte: 0x7303,
      rewindStorageInput: 0x7306,
      writeStorageByte: 0x7309,
      seekStorageOutput: 0x730c,
      success: services.success,
      unhandledFailure: services.unhandledFailure,
      trap: services.trap,
      farCall: 0x7000,
      farJump: 0x7080,
    };
    const built = await compileNucleus(
      [
        {
          name: "library.nu",
          source: [
            'const Remote as string[5] = "BANK1"',
            "sub emitRemote() fails",
            "print(Remote) else fail",
            "end",
            "",
          ].join("\n"),
        },
        {
          name: "main.nu",
          source: [
            "sub main() fails",
            "emitRemote() else fail",
            "end",
            "",
          ].join("\n"),
        },
      ],
      {
        bankCount: 2,
        entryBank: 0,
        partBanks: [1, 0],
        services: bankedServices,
      },
      { debugMap: true },
    );
    expect(built.success).toBe(true);
    if (!built.success) return;
    expect(built.debugMapping?.maps.map(({ bank }) => bank)).toEqual([0, 1]);

    const executed = executeCommittedNobj(
      built.nobj,
      {
        maxInstructions: 20_000,
        maxCycles: 200_000,
        halted: true,
        writes: [
          { at: bankedServices.farCall, bytes: adapter(0x7000) },
          { at: bankedServices.farJump, bytes: adapter(0x7080) },
          { at: bankedServices.writeOutputByte, bytes: outputService },
          ...terminalWrites,
        ],
      },
      {
        bankSwitch: {
          port: 0x7f,
          windowBase: 0x8000,
          windowCapacity: 0x1000,
        },
      },
    );
    const length = executed.memory[outputLength] ?? 0;
    expect(
      new TextDecoder().decode(
        executed.memory.slice(outputBase, outputBase + length),
      ),
    ).toBe("BANK1");
    expect(executed.selectedBank).toBe(0);
    expect(executed.memory[0x4021]).toBe(2);
  });

  it("uses the existing handle and propagation rules", async () => {
    const failingOutput = [0x3e, 3, 0x37, 0xc9]; // LD A,outputFailure / SCF / RET
    const handled = await compile(
      [
        "var code as u8",
        'const text as string[5] = "Hello"',
        "sub main()",
        "print(text) handle code",
        "end",
        "end",
        "",
      ].join("\n"),
    );
    expect(handled.success).toBe(true);
    if (!handled.success) return;
    const handledRun = executeCommittedNobj(handled.nobj, {
      maxInstructions: 20_000,
      maxCycles: 200_000,
      halted: true,
      writes: [
        { at: services.writeOutputByte, bytes: failingOutput },
        ...terminalWrites,
      ],
    });
    expect(handledRun.memory[0x4046]).toBe(3);
    expect(handledRun.memory[0x4021]).toBe(2);

    const propagated = await compile(
      [
        'const text as string[5] = "Hello"',
        "sub main() fails",
        "print(text) else fail",
        "end",
        "",
      ].join("\n"),
    );
    expect(propagated.success).toBe(true);
    if (!propagated.success) return;
    const propagatedRun = executeCommittedNobj(propagated.nobj, {
      maxInstructions: 20_000,
      maxCycles: 200_000,
      halted: true,
      writes: [
        { at: services.writeOutputByte, bytes: failingOutput },
        ...terminalWrites,
      ],
    });
    expect(propagatedRun.memory[0x4021]).toBe(3); // RunTrapped
    expect(propagatedRun.memory[0x4022]).toBe(6); // unhandled-error
    expect(propagatedRun.memory[0x4026]).toBe(3); // outputFailure
  });

  it("keeps earlier bytes when a later output call fails", async () => {
    const failAfterTwo = [
      0xf5, // PUSH AF
      0x3a,
      outputLength & 0xff,
      outputLength >>> 8, // LD A,(outputLength)
      0xfe,
      0x02, // CP 2
      0x28,
      0x03, // JR Z,failure
      0xf1, // POP AF
      0x18,
      0x05, // JR success
      0xf1, // POP AF
      0x3e,
      0x03,
      0x37,
      0xc9, // LD A,outputFailure / SCF / RET
      ...outputService,
    ];
    const built = await compile(
      [
        'const text as string[5] = "Hello"',
        "sub main() fails",
        "print(text) else fail",
        "end",
        "",
      ].join("\n"),
    );
    expect(built.success).toBe(true);
    if (!built.success) return;
    const executed = executeCommittedNobj(built.nobj, {
      maxInstructions: 20_000,
      maxCycles: 200_000,
      halted: true,
      writes: [
        { at: services.writeOutputByte, bytes: failAfterTwo },
        ...terminalWrites,
      ],
    });
    expect(
      new TextDecoder().decode(
        executed.memory.slice(outputBase, outputBase + 2),
      ),
    ).toBe("He");
    expect(executed.memory[outputLength]).toBe(2);
    expect(executed.memory[0x4021]).toBe(3);
    expect(executed.memory[0x4026]).toBe(3);
  });

  it("checks the bounded-string invariant before output", async () => {
    const built = await compile(
      [
        'const text as string[5] = "Hello"',
        "sub main() fails",
        "print(text) else fail",
        "end",
        "",
      ].join("\n"),
    );
    expect(built.success).toBe(true);
    if (!built.success) return;
    const stringAddress =
      built.materialized.parsed.map.banks[0]?.aggregateConstantBase ?? -1;
    const executed = executeCommittedNobj(built.nobj, {
      maxInstructions: 20_000,
      maxCycles: 200_000,
      halted: true,
      writes: [
        { at: services.writeOutputByte, bytes: outputService },
        { at: stringAddress, bytes: [6] },
        ...terminalWrites,
      ],
    });
    expect(executed.memory[outputLength]).toBe(0);
    expect(executed.memory[0x4021]).toBe(3);
    expect(executed.memory[0x4022]).toBe(1); // bounds
  });

  it("checks the complete carrier region before reading the string", async () => {
    const built = await compile(
      [
        'const text as string[5] = "Hello"',
        "sub main() fails",
        "print(text) else fail",
        "end",
        "",
      ].join("\n"),
    );
    expect(built.success).toBe(true);
    if (!built.success) return;
    const image = built.materialized.banks[0] ?? new Uint8Array();
    const imageBase = built.materialized.parsed.begin.imageBase;
    const stringAddress =
      built.materialized.parsed.map.banks[0]?.aggregateConstantBase ?? -1;
    const carrierLoads: number[] = [];
    for (let index = 0; index + 2 < image.length; index += 1) {
      if (
        image[index] === 0x21 &&
        image[index + 1] === (stringAddress & 0xff) &&
        image[index + 2] === stringAddress >>> 8
      ) {
        carrierLoads.push(imageBase + index);
      }
    }
    expect(carrierLoads).toHaveLength(1);
    const executed = executeCommittedNobj(built.nobj, {
      maxInstructions: 20_000,
      maxCycles: 200_000,
      halted: true,
      writes: [
        { at: (carrierLoads[0] ?? -1) + 1, bytes: [0xff, 0xff] },
        { at: 0xffff, bytes: [0] },
        { at: services.writeOutputByte, bytes: outputService },
        ...terminalWrites,
      ],
    });
    expect(executed.memory[outputLength]).toBe(0);
    expect(executed.memory[0x4021]).toBe(3);
    expect(executed.memory[0x4022]).toBe(1); // bounds
  });

  it("does not consume a hidden aggregate-type entry", async () => {
    const declarations = Array.from(
      { length: 8 },
      (_, index) => `const s${index + 1} as string[${index + 1}] = ""`,
    );
    const withinCapacity = await compile(
      [
        ...declarations,
        "sub main() fails",
        "print(s1) else fail",
        "end",
        "",
      ].join("\n"),
    );
    expect(withinCapacity.success).toBe(true);

    const overflow = await compile(
      [
        ...declarations,
        'const s9 as string[9] = ""',
        "sub main() fails",
        "print(s1) else fail",
        "end",
        "",
      ].join("\n"),
    );
    expect(overflow.success).toBe(false);
    if (overflow.success) return;
    expect(overflow.diagnostic.code).toBe(76);
  });

  it("produces validated debug mapping for the reused semantic slot", async () => {
    const built = await compileNucleus(
      [
        {
          name: "print.nu",
          source:
            'const text as string[5] = "Hello"\nsub main() fails\nprint(text) else fail\nend\n',
        },
      ],
      { services },
      { debugMap: true },
    );
    expect(built.success).toBe(true);
    if (!built.success) return;
    expect(built.debugMapping?.semanticOperations).toBeGreaterThan(0);
    expect(built.debugMapping?.maps).toHaveLength(1);
  });

  it("rejects non-strings, unconsumed failure and redefinition", async () => {
    const cases = [
      {
        source:
          "var value as u8\nsub main() fails\nprint(value) else fail\nend\n",
        code: 60,
      },
      {
        source: 'const text as string[1] = "X"\nsub main()\nprint(text)\nend\n',
        code: 87,
      },
      { source: "sub print()\nend\nsub main()\nend\n", code: 55 },
    ];
    for (const { source, code } of cases) {
      const result = await compile(source);
      expect(result.success).toBe(false);
      if (result.success) continue;
      expect(result.diagnostic.code).toBe(code);
    }
  });
});

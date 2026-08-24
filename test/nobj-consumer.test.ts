import { compile } from "@jhlagado/azm/compile";
import {
  createZ80Runtime,
  parseIntelHex,
} from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

import { crc16CcittFalse, materializeNobjChunks } from "../src/nobj.js";

interface ConsumerImage {
  readonly memory: Uint8Array;
  readonly symbols: Readonly<Record<string, number>>;
}

interface ConsumerOutcome {
  readonly memory: Uint8Array;
  readonly instructions: number;
  readonly tStates: number;
  readonly pc: number;
  readonly result: readonly number[];
}

let image: ConsumerImage;
let bankedImage: ConsumerImage;
let controlTopImage: ConsumerImage;

const symbol = (name: string): number => {
  const value = image.symbols[name];
  if (value === undefined) throw new Error(`missing consumer symbol ${name}`);
  return value;
};

const bankedSymbol = (name: string): number => {
  const value = bankedImage.symbols[name];
  if (value === undefined) throw new Error(`missing banked symbol ${name}`);
  return value;
};

const writeWord = (memory: Uint8Array, at: number, value: number): void => {
  memory[at] = value & 0xff;
  memory[at + 1] = value >>> 8;
};

interface NobjRecordLocation {
  readonly kind: number;
  readonly offset: number;
  readonly payload: number;
  readonly length: number;
}

const recordsOf = (bytes: Uint8Array): readonly NobjRecordLocation[] => {
  const records: NobjRecordLocation[] = [];
  let offset = 0;
  while (offset < bytes.length) {
    const length = bytes[offset + 1]! | (bytes[offset + 2]! << 8);
    records.push({
      kind: bytes[offset]!,
      offset,
      payload: offset + 3,
      length,
    });
    offset += 3 + length;
  }
  expect(offset).toBe(bytes.length);
  return records;
};

const recordOf = (bytes: Uint8Array, kind: number): NobjRecordLocation => {
  const record = recordsOf(bytes).find((candidate) => candidate.kind === kind);
  if (record === undefined) throw new Error(`missing NOBJ record ${kind}`);
  return record;
};

const refreshCrc = (bytes: Uint8Array): Uint8Array => {
  const crc = crc16CcittFalse(bytes.slice(0, bytes.length - 2));
  bytes[bytes.length - 2] = crc & 0xff;
  bytes[bytes.length - 1] = crc >>> 8;
  return bytes;
};

const run = (
  mutate?: (memory: Uint8Array) => void,
  object?: Uint8Array,
  start = "ProofStart",
): ConsumerOutcome => {
  const memory = image.memory.slice();
  if (object !== undefined) {
    memory.set(object, symbol("NobjObject"));
    writeWord(
      memory,
      symbol("ProofObjectActiveEnd"),
      symbol("NobjObject") + object.length,
    );
  }
  mutate?.(memory);
  const runtime = createZ80Runtime(
    { memory, startAddress: symbol(start) },
    symbol(start),
  );
  let instructions = 0;
  let tStates = 0;
  while (!runtime.isHalted() && instructions < 3_000_000) {
    tStates += runtime.step().cycles ?? 0;
    instructions += 1;
  }
  expect(runtime.isHalted(), `consumer stopped at $${runtime.getPC().toString(16)}`).toBe(
    true,
  );
  const resultAt = symbol("NobjResult");
  return {
    memory: runtime.hardware.memory,
    instructions,
    tStates,
    pc: runtime.getPC(),
    result: [...runtime.hardware.memory.slice(resultAt, resultAt + 4)],
  };
};

const committedObject = (): Uint8Array =>
  image.memory.slice(symbol("NobjObject"), symbol("NobjObjectEnd"));

const committedBankedObject = (): Uint8Array =>
  bankedImage.memory.slice(
    bankedSymbol("NobjObject"),
    bankedSymbol("NobjObjectEnd"),
  );

const runBanked = (
  object?: Uint8Array,
  mutate?: (memory: Uint8Array) => void,
): ConsumerOutcome => {
  const memory = bankedImage.memory.slice();
  if (object !== undefined) {
    memory.set(object, bankedSymbol("NobjObject"));
    writeWord(
      memory,
      bankedSymbol("ProofObjectActiveEnd"),
      bankedSymbol("NobjObject") + object.length,
    );
  }
  mutate?.(memory);
  const runtime = createZ80Runtime(
    { memory, startAddress: bankedSymbol("ProofStart") },
    bankedSymbol("ProofStart"),
  );
  let instructions = 0;
  let tStates = 0;
  while (!runtime.isHalted() && instructions < 3_000_000) {
    tStates += runtime.step().cycles ?? 0;
    instructions += 1;
  }
  expect(runtime.isHalted()).toBe(true);
  const resultAt = bankedSymbol("NobjResult");
  return {
    memory: runtime.hardware.memory,
    instructions,
    tStates,
    pc: runtime.getPC(),
    result: [...runtime.hardware.memory.slice(resultAt, resultAt + 4)],
  };
};

const withSecondOverlappingPatch = (): Uint8Array => {
  const original = committedObject();
  const mapOffset = 45;
  const extraPatch = Uint8Array.of(3, 4, 0, 0, 1, 0x80, 0xa5);
  const bytes = new Uint8Array(original.length + extraPatch.length);
  bytes.set(original.slice(0, mapOffset), 0);
  bytes.set(extraPatch, mapOffset);
  bytes.set(original.slice(mapOffset), mapOffset + extraPatch.length);
  const commitOffset = bytes.length - 10;
  bytes[commitOffset + 3] = 7;
  bytes[commitOffset + 4] = 0;
  return refreshCrc(bytes);
};

const withSecondPatchAt = (address: number): Uint8Array => {
  const original = committedObject();
  const mapOffset = recordOf(original, 4).offset;
  const extraPatch = Uint8Array.of(
    3, 4, 0, 0,
    address & 0xff, address >>> 8,
    0xa5,
  );
  const bytes = new Uint8Array(original.length + extraPatch.length);
  bytes.set(original.slice(0, mapOffset));
  bytes.set(extraPatch, mapOffset);
  bytes.set(original.slice(mapOffset), mapOffset + extraPatch.length);
  const commit = recordOf(bytes, 5);
  writeWord(bytes, commit.payload, recordsOf(bytes).length);
  return refreshCrc(bytes);
};

const withDescendingOverlappingPatch = (): Uint8Array => {
  const original = committedObject();
  const originalPatch = recordOf(original, 3);
  writeWord(original, originalPatch.payload + 1, 0x8071);
  const mapOffset = recordOf(original, 4).offset;
  const extraPatch = Uint8Array.of(3, 5, 0, 0, 0x70, 0x80, 0xa5, 0xa6);
  const bytes = new Uint8Array(original.length + extraPatch.length);
  bytes.set(original.slice(0, mapOffset));
  bytes.set(extraPatch, mapOffset);
  bytes.set(original.slice(mapOffset), mapOffset + extraPatch.length);
  const commit = recordOf(bytes, 5);
  writeWord(bytes, commit.payload, recordsOf(bytes).length);
  return refreshCrc(bytes);
};

const flatObjectAtTopOfMemory = (): Uint8Array => {
  const bytes = committedObject();
  const records = recordsOf(bytes);
  const begin = records.find(({ kind }) => kind === 1)!;
  writeWord(bytes, begin.payload + 11, 0xff00);
  for (const record of records.filter(({ kind }) => kind === 2 || kind === 3)) {
    const address = bytes[record.payload + 1]! | (bytes[record.payload + 2]! << 8);
    writeWord(bytes, record.payload + 1, (address + 0x7f00) & 0xffff);
  }
  const map = records.find(({ kind }) => kind === 4)!;
  writeWord(bytes, map.payload + 3, 0xff00);
  writeWord(bytes, map.payload + 5, 0xff80);
  writeWord(bytes, map.payload + 9, 0xff80);
  writeWord(bytes, map.payload + 13, 0xff80);
  writeWord(bytes, map.payload + 17, 0xff82);
  writeWord(bytes, map.payload + 24, 0xff80);
  const commit = records.find(({ kind }) => kind === 5)!;
  writeWord(bytes, commit.payload + 3, 0xff00);
  return refreshCrc(bytes);
};

const flatRomObject = (): Uint8Array => {
  const bytes = committedObject();
  const map = recordOf(bytes, 4);
  bytes[map.payload + 1] = 1;
  writeWord(bytes, map.payload + 5, 0x4000);
  writeWord(bytes, map.payload + 9, 0x4000);
  writeWord(bytes, map.payload + 13, 0x4000);
  writeWord(bytes, map.payload + 17, 0x4002);
  writeWord(bytes, map.payload + 24, 0x8080);
  writeWord(bytes, map.payload + 33, 0x8080);
  writeWord(bytes, map.payload + 35, 2);
  return refreshCrc(bytes);
};

const flatObjectWithPatchAtEnd = (address: number): Uint8Array => {
  const bytes = address === 0x80ff ? flatRomObject() : committedObject();
  const patch = recordOf(bytes, 3);
  writeWord(bytes, patch.payload + 1, address);
  if (address === 0x80ff) {
    const map = recordOf(bytes, 4);
    writeWord(bytes, map.payload + 31, 0x0100);
    writeWord(bytes, map.payload + 35, 0x0080);
  }
  return refreshCrc(bytes);
};

const flatObjectWithPatchOverFill = (): Uint8Array => {
  const bytes = committedObject();
  const patch = recordOf(bytes, 3);
  writeWord(bytes, patch.payload + 1, 0x8070);
  return refreshCrc(bytes);
};

const bankedObjectWithAlternatingImages = (): Uint8Array => {
  const original = committedBankedObject();
  const patchOffset = recordOf(original, 3).offset;
  const extraImage = Uint8Array.of(2, 4, 0, 0, 6, 0x80, 0x99);
  const bytes = new Uint8Array(original.length + extraImage.length);
  bytes.set(original.slice(0, patchOffset));
  bytes.set(extraImage, patchOffset);
  bytes.set(original.slice(patchOffset), patchOffset + extraImage.length);
  const map = recordOf(bytes, 4);
  writeWord(bytes, map.payload + 32, 7);
  const commit = recordOf(bytes, 5);
  writeWord(bytes, commit.payload, recordsOf(bytes).length);
  return refreshCrc(bytes);
};

beforeAll(async () => {
  const platform = new URL(
    "../asm/vertical-slice/nobj-consumer-platform.asmi",
    import.meta.url,
  ).pathname;
  const assemble = async (name: string): Promise<ConsumerImage> => {
    const source = new URL(`../asm/vertical-slice/${name}.asm`, import.meta.url)
      .pathname;
    const assembled = await compile(source, {
      emitHex: true,
      emitD8m: true,
      registerContracts: "strict",
      registerContractsInterfaces: [platform],
    });
    const errors = assembled.diagnostics.filter(
      ({ severity }) => severity === "error",
    );
    expect(errors).toEqual([]);
    const hex = assembled.artifacts.find(({ kind }) => kind === "hex");
    const map = assembled.artifacts.find(({ kind }) => kind === "d8m");
    if (hex?.kind !== "hex" || map?.kind !== "d8m") {
      throw new Error("AZM omitted NOBJ consumer proof artifacts");
    }
    return {
      memory: parseIntelHex(hex.text).memory,
      symbols: Object.fromEntries(
        map.json.symbols.flatMap((entry) => {
          const value = entry.address ?? entry.value;
          return value === undefined ? [] : [[entry.name, value]];
        }),
      ),
    };
  };
  [image, bankedImage, controlTopImage] = await Promise.all([
    assemble("nobj-consumer-flat-proof"),
    assemble("nobj-consumer-banked-proof"),
    assemble("nobj-consumer-control-top-proof"),
  ]);
});

describe("the standalone Z80 NOBJ consumer", () => {
  it("materializes the flat image in one read, publishes, and enters", () => {
    const outcome = run();
    expect(outcome.result).toEqual([0, 0, 0, 0]);
    expect(outcome.pc).toBe(0x8006);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(1);
    expect(outcome.memory[symbol("ProofClosed")]).toBe(1);
    expect(outcome.memory[0x8001]).toBe(0x5a);
    expect(outcome.memory[0x8070]).toBe(0xee);
    expect(outcome.memory[0x8081]).toBe(0x5a);
    expect(outcome.memory[symbol("ProofLockCount")]).toBe(0);
    expect(outcome.instructions).toBe(12_646);
    expect(outcome.tStates).toBe(108_132);
    expect(symbol("NobjConsumerCodeEnd") - symbol("NobjConsumerCodeStart")).toBe(
      2_425,
    );
    expect(
      symbol("NobjConsumerWorkspaceEnd") - symbol("NobjConsumerWorkspaceBase"),
    ).toBe(381);
  });

  it.each([
    ["truncated header", 2, 4, 1, 0x7c],
    ["truncated BEGIN", 10, 4, 1, 0x7c],
    ["truncated IMAGE", 25, 4, 2, 0x3e],
    ["truncated PATCH", 43, 4, 4, 0x3e],
    ["truncated MAP", 70, 4, 5, 0x3e],
    ["truncated COMMIT", 95, 4, 6, 0x3e],
  ] as const)("rejects a %s without publication", (_name, length, status, ordinal, targetByte) => {
    const source = committedObject().slice(0, length);
    const outcome = run((memory) => {
      memory[0x8000] = 0x7c;
    }, source);
    expect(outcome.result).toEqual([1, status, ordinal, 0]);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
    expect(outcome.memory[0x8000]).toBe(targetByte);
  });

  it("reports ordinal zero for an empty object", () => {
    const outcome = run(undefined, new Uint8Array());
    expect(outcome.result).toEqual([1, 4, 0, 0]);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
  });

  it("rejects a corrupt CRC after direct writes without publishing", () => {
    const bytes = committedObject();
    bytes[bytes.length - 1] ^= 0x80;
    const outcome = run((memory) => {
      memory[0x8000] = 0x7c;
    }, bytes);
    expect(outcome.result).toEqual([1, 12, 6, 0]);
    expect(outcome.memory[0x8000]).toBe(0x3e);
    expect(outcome.memory[0x8001]).toBe(0x5a);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
  });

  it("rejects a byte following COMMIT", () => {
    const original = committedObject();
    const bytes = new Uint8Array(original.length + 1);
    bytes.set(original);
    bytes[bytes.length - 1] = 0xa5;
    expect(run(undefined, bytes).result).toEqual([1, 13, 6, 0]);
  });

  it("rejects EOF immediately after MAP as a missing COMMIT", () => {
    const bytes = committedObject();
    const commit = recordOf(bytes, 5);
    const outcome = run(undefined, bytes.slice(0, commit.offset));
    expect(outcome.result).toEqual([1, 4, 5, 0]);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
  });

  it("applies overlapping PATCH records in stream order", () => {
    const outcome = run(undefined, withSecondOverlappingPatch());
    expect(outcome.result).toEqual([0, 0, 0, 0]);
    expect(outcome.memory[0x8001]).toBe(0xa5);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(1);
  });

  it("uses the last write for descending overlapping PATCH records", () => {
    const outcome = run(undefined, withDescendingOverlappingPatch());
    expect(outcome.result).toEqual([0, 0, 0, 0]);
    expect(outcome.memory[0x8070]).toBe(0xa5);
    expect(outcome.memory[0x8071]).toBe(0xa6);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(1);
  });

  it("accepts two nonoverlapping PATCH records in resolution order", () => {
    const outcome = run(undefined, withSecondPatchAt(0x8070));
    expect(outcome.pc).toBe(0x8006);
    expect(outcome.memory[0x8070]).toBe(0xa5);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(1);
  });

  it("applies a PATCH over an implicit image-fill byte", () => {
    const outcome = run(undefined, flatObjectWithPatchOverFill());
    expect(outcome.pc).toBe(0x8006);
    expect(outcome.memory[0x8070]).toBe(0x5a);
  });

  it("accepts a one-byte PATCH ending exactly at image capacity", () => {
    const outcome = run((memory) => {
      writeWord(memory, symbol("NobjDeploymentProfile") + 11, 0x4000);
    }, flatObjectWithPatchAtEnd(0x80ff));
    expect(outcome.pc).toBe(0x8006);
    expect(outcome.memory[0x80ff]).toBe(0x5a);
  });

  it("rejects the first PATCH byte beyond image capacity", () => {
    const outcome = run(undefined, flatObjectWithPatchAtEnd(0x8100));
    expect(outcome.result).toEqual([1, 7, 4, 0]);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
  });

  it("does not require object locking", () => {
    const outcome = run((memory) => {
      memory[symbol("ProofFailureOperation")] = 4;
    });
    expect(outcome.result).toEqual([0, 0, 0, 0]);
    expect(outcome.memory[symbol("ProofLockCount")]).toBe(0);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(1);
  });

  it("does not require object rewind", () => {
    const outcome = run((memory) => {
      memory[symbol("ProofFailureOperation")] = 3;
    });
    expect(outcome.result).toEqual([0, 0, 0, 0]);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(1);
  });

  it("rejects a strategy other than direct single-read", () => {
    const outcome = run((memory) => {
      memory[symbol("NobjRunDescriptor") + 3] = 1;
    });
    expect(outcome.result).toEqual([0, 0, 0, 0]);
    expect(outcome.memory[symbol("ProofFailureStatus")]).toBe(1);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
    expect(outcome.memory[symbol("ProofLockCount")]).toBe(0);
  });

  it.each([0xfffe, 0xffff])(
    "rejects established-stack requirement $%s without 16-bit wrap",
    (requirement) => {
      const bytes = committedObject();
      const map = recordOf(bytes, 4);
      bytes[map.payload + 1] = 2;
      writeWord(bytes, map.payload + 21, requirement);
      const outcome = run((memory) => {
        memory[symbol("NobjDeploymentProfile") + 2] = 2;
      }, refreshCrc(bytes));
      expect(outcome.result).toEqual([1, 10, 5, 0]);
      expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
    },
  );

  it("accepts a flat loaded image whose mathematical end is exactly $10000", () => {
    const outcome = run((memory) => {
      writeWord(memory, symbol("NobjDeploymentProfile") + 7, 0xff00);
      writeWord(memory, symbol("NobjDeploymentProfile") + 11, 0xff80);
    }, flatObjectAtTopOfMemory());
    expect(outcome.pc).toBe(0xff06);
    expect(outcome.memory[0xff01]).toBe(0x5a);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(1);
  });

  it("rejects the first image end beyond $10000", () => {
    const outcome = run((memory) => {
      writeWord(memory, symbol("NobjDeploymentProfile") + 7, 0xff01);
    });
    expect(outcome.result).toEqual([1, 3, 0, 0]);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
  });

  it("accepts a flat ROM layout and keeps its writable region separate", () => {
    const outcome = run((memory) => {
      writeWord(memory, symbol("NobjDeploymentProfile") + 11, 0x4000);
    }, flatRomObject());
    expect(outcome.pc).toBe(0x8006);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(1);
  });

  it("rejects a target image overlapping the resident consumer", () => {
    const outcome = run((memory) => {
      writeWord(memory, symbol("NobjDeploymentProfile") + 7, 0x1000);
    });
    expect(outcome.result).toEqual([1, 15, 0, 0]);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
  });

  it.each([
    ["platform adapter", 0x6000],
    ["live control records", 0x4800],
  ] as const)("rejects an image overlapping %s", (_name, base) => {
    const outcome = run((memory) => {
      writeWord(memory, symbol("NobjDeploymentProfile") + 7, base);
    });
    expect(outcome.result).toEqual([1, 15, 0, 0]);
  });

  it("rejects writable storage overlapping the resident consumer", () => {
    const outcome = run((memory) => {
      writeWord(memory, symbol("NobjDeploymentProfile") + 11, 0x1000);
    });
    expect(outcome.result).toEqual([1, 15, 0, 0]);
  });

  it("accepts live control records below an exclusive $10000 limit", () => {
    const status = controlTopImage.symbols.ProofStatus;
    const start = controlTopImage.symbols.ProofStart;
    if (status === undefined || start === undefined) {
      throw new Error("missing control-top proof symbols");
    }
    const runtime = createZ80Runtime(
      { memory: controlTopImage.memory.slice(), startAddress: start },
      start,
    );
    while (!runtime.isHalted()) runtime.step();
    expect(runtime.hardware.memory[status]).toBe(0xa5);
  });

  it.each([
    ["ends at", 0x5f00],
    ["starts at", 0x6400],
  ] as const)("does not treat an image that %s a protected extent as overlapping", (_name, base) => {
    const outcome = run((memory) => {
      writeWord(memory, symbol("NobjDeploymentProfile") + 7, base);
      writeWord(memory, symbol("NobjDeploymentProfile") + 11, base + 0x80);
    });
    expect(outcome.result).toEqual([1, 3, 1, 0]);
  });

  it("does not treat writable storage ending at protected code as overlapping", () => {
    const outcome = run((memory) => {
      writeWord(memory, symbol("NobjDeploymentProfile") + 11, 0x0f00);
      writeWord(memory, symbol("NobjDeploymentProfile") + 13, 0x0100);
    });
    expect(outcome.result).toEqual([1, 10, 5, 0]);
  });

  it.each([
    ["invalid kind", (bytes: Uint8Array) => { bytes[0] = 6; }, 5, 1],
    ["reserved BEGIN flag", (bytes: Uint8Array) => {
      const begin = recordOf(bytes, 1);
      bytes[begin.payload + 6] = 2;
    }, 5, 1],
    ["unsupported NOBJ revision", (bytes: Uint8Array) => {
      const begin = recordOf(bytes, 1);
      bytes[begin.payload + 5] = 2;
    }, 5, 1],
    ["wrong runtime identity", (bytes: Uint8Array) => {
      const begin = recordOf(bytes, 1);
      writeWord(bytes, begin.payload + 7, 2);
    }, 3, 1],
    ["invalid IMAGE bank", (bytes: Uint8Array) => {
      const imageRecord = recordOf(bytes, 2);
      bytes[imageRecord.payload] = 1;
    }, 7, 2],
    ["overlapping IMAGE", (bytes: Uint8Array) => {
      const imageRecords = recordsOf(bytes).filter(({ kind }) => kind === 2);
      writeWord(bytes, imageRecords[1]!.payload + 1, 0x8005);
    }, 8, 3],
    ["duplicate IMAGE address", (bytes: Uint8Array) => {
      const imageRecords = recordsOf(bytes).filter(({ kind }) => kind === 2);
      writeWord(bytes, imageRecords[1]!.payload + 1, 0x8000);
    }, 8, 3],
    ["descending IMAGE address", (bytes: Uint8Array) => {
      const imageRecords = recordsOf(bytes).filter(({ kind }) => kind === 2);
      writeWord(bytes, imageRecords[0]!.payload + 1, 0x8010);
      writeWord(bytes, imageRecords[1]!.payload + 1, 0x8000);
    }, 8, 3],
    ["reserved MAP flag", (bytes: Uint8Array) => {
      const map = recordOf(bytes, 4);
      bytes[map.payload + 1] |= 4;
    }, 10, 5],
    ["inconsistent MAP entry", (bytes: Uint8Array) => {
      const map = recordOf(bytes, 4);
      writeWord(bytes, map.payload + 3, 0x8001);
    }, 10, 5],
    ["inconsistent BSS base", (bytes: Uint8Array) => {
      const map = recordOf(bytes, 4);
      writeWord(bytes, map.payload + 17, 0x8083);
    }, 10, 5],
    ["wrong COMMIT count", (bytes: Uint8Array) => {
      const commit = recordOf(bytes, 5);
      writeWord(bytes, commit.payload, 5);
    }, 11, 6],
    ["wrong COMMIT entry", (bytes: Uint8Array) => {
      const commit = recordOf(bytes, 5);
      writeWord(bytes, commit.payload + 3, 0x8001);
    }, 11, 6],
  ] as const)("rejects %s", (_name, mutateObject, status, ordinal) => {
    const bytes = committedObject();
    mutateObject(bytes);
    const outcome = run(undefined, refreshCrc(bytes));
    expect(outcome.result).toEqual([1, status, ordinal, 0]);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
  });

  it("rejects a MAP payload shorter than its fixed minimum", () => {
    const bytes = committedObject();
    const map = recordOf(bytes, 4);
    writeWord(bytes, map.offset + 1, 40);
    const outcome = run(undefined, bytes);
    expect(outcome.result).toEqual([1, 10, 5, 0]);
  });

  it("keeps a previous publication selected after a late validation failure", () => {
    const bytes = committedObject();
    bytes[bytes.length - 1] ^= 0x80;
    const outcome = run((memory) => {
      memory[symbol("ProofPublished")] = 1;
    }, bytes);
    expect(outcome.result).toEqual([1, 12, 6, 0]);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(1);
  });

  it("closes an opened object after a platform read failure", () => {
    const outcome = run((memory) => {
      memory[symbol("ProofFailureOperation")] = 2;
    });
    expect(outcome.result).toEqual([2, 0x42, 0, 0]);
    expect(outcome.memory[symbol("ProofCloseCount")]).toBe(1);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
  });

  it("does not close an object whose open operation failed", () => {
    const outcome = run((memory) => {
      memory[symbol("ProofFailureOperation")] = 1;
    });
    expect(outcome.result).toEqual([2, 0x42, 0, 0]);
    expect(outcome.memory[symbol("ProofCloseCount")]).toBe(0);
  });

  it("reports entry failure after publication without reopening the object", () => {
    const outcome = run((memory) => {
      memory[symbol("ProofFailureOperation")] = 7;
    });
    expect(outcome.result).toEqual([2, 0x42, 6, 0]);
    expect(outcome.memory[symbol("ProofCloseCount")]).toBe(1);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(1);
  });

  it("reports a close failure before publication", () => {
    const outcome = run((memory) => {
      memory[symbol("ProofFailureOperation")] = 8;
    });
    expect(outcome.result).toEqual([2, 0x42, 6, 0]);
    expect(outcome.memory[symbol("ProofCloseCount")]).toBe(1);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
  });

  it("reports a publication failure after closing the object", () => {
    const outcome = run((memory) => {
      memory[symbol("ProofFailureOperation")] = 6;
    });
    expect(outcome.result).toEqual([2, 0x42, 6, 0]);
    expect(outcome.memory[symbol("ProofCloseCount")]).toBe(1);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(0);
  });

  it("resets the record ordinal before a sequential pre-record failure", () => {
    const outcome = run(undefined, undefined, "ProofSequentialOrdinalStart");
    expect(outcome.result).toEqual([1, 3, 0, 0]);
  });

  it("recovers on the same consumer image after a failed object", () => {
    const outcome = run(undefined, undefined, "ProofSequentialRecoveryStart");
    expect(outcome.pc).toBe(0x8006);
    expect(outcome.memory[symbol("ProofPublished")]).toBe(1);
  });

  it("matches Node materialization for every valid flat fixture", () => {
    const cases: readonly [
      string,
      () => Uint8Array,
      ((memory: Uint8Array) => void)?,
    ][] = [
      ["baseline", committedObject],
      ["ascending overlap", withSecondOverlappingPatch],
      ["descending overlap", withDescendingOverlappingPatch],
      ["nonoverlapping resolution order", () => withSecondPatchAt(0x8070)],
      ["implicit fill", flatObjectWithPatchOverFill],
      ["ROM", flatRomObject, (memory) => {
        writeWord(memory, symbol("NobjDeploymentProfile") + 11, 0x4000);
      }],
      ["patch at capacity", () => flatObjectWithPatchAtEnd(0x80ff), (memory) => {
        writeWord(memory, symbol("NobjDeploymentProfile") + 11, 0x4000);
      }],
      ["mathematical $10000 end", flatObjectAtTopOfMemory, (memory) => {
        writeWord(memory, symbol("NobjDeploymentProfile") + 7, 0xff00);
        writeWord(memory, symbol("NobjDeploymentProfile") + 11, 0xff80);
      }],
    ];
    for (const [name, makeObject, mutate] of cases) {
      const object = makeObject();
      const expected = materializeNobjChunks([object]).banks[0]!;
      const begin = recordOf(object, 1);
      const imageBase = object[begin.payload + 11]! | (object[begin.payload + 12]! << 8);
      const outcome = run((memory) => {
        mutate?.(memory);
        memory[symbol("ProofFailureOperation")] = 6;
      }, object);
      expect(outcome.result, name).toEqual([2, 0x42, recordsOf(object).length, 0]);
      expect(
        outcome.memory.slice(imageBase, imageBase + expected.length),
        name,
      ).toEqual(expected);
    }
  });

  it("materializes two physical banks and enters the selected entry bank", () => {
    const outcome = runBanked();
    expect(outcome.pc).toBe(0x8006);
    expect(outcome.memory[bankedSymbol("ProofPublished")]).toBe(1);
    expect(outcome.memory[bankedSymbol("ProofSelectedBank")]).toBe(0);
    expect([...outcome.memory.slice(0x8000, 0x8006)]).toEqual([
      0x3e, 0x5a, 0x32, 0x01, 0x40, 0x76,
    ]);
    expect(
      [...outcome.memory.slice(
        bankedSymbol("ProofBank1") + 0x10,
        bankedSymbol("ProofBank1") + 0x12,
      )],
    ).toEqual([0xaa, 0xcc]);
    expect(outcome.instructions).toBe(15_532);
    expect(outcome.tStates).toBe(187_389);
  });

  it("accepts IMAGE records that alternate between physical banks", () => {
    const outcome = runBanked(bankedObjectWithAlternatingImages());
    expect(outcome.pc).toBe(0x8006);
    expect(outcome.memory[0x8006]).toBe(0x99);
    expect(outcome.memory[bankedSymbol("ProofPublished")]).toBe(1);
  });

  it("matches Node materialization for every valid banked fixture", () => {
    for (const object of [committedBankedObject(), bankedObjectWithAlternatingImages()]) {
      const expected = materializeNobjChunks([object]).banks;
      const outcome = runBanked(object, (memory) => {
        memory[bankedSymbol("ProofFailureOperation")] = 6;
      });
      expect(outcome.result).toEqual([2, 0x42, recordsOf(object).length, 0]);
      expect(
        outcome.memory.slice(
          bankedSymbol("ProofBank0"),
          bankedSymbol("ProofBank0") + expected[0]!.length,
        ),
      ).toEqual(expected[0]);
      expect(outcome.memory.slice(0x8000, 0x8000 + expected[1]!.length)).toEqual(
        expected[1],
      );
    }
  });
});

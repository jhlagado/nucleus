import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";

import {
  materializeNobj,
  NobjGenerationStore,
  type MaterializedNobj,
  type NobjBegin,
  type NobjCommitMetadata,
  type NobjMap,
  type NobjSequentialOutput,
  type NobjSpoolFactory,
  type ParsedNobj,
  type RuntimeLinkContext,
} from "./nobj.js";
import {
  commitNobjAdapterGeneration as commitNobjAdapterGenerationWithProvider,
  commitNobjAdapterGenerationTo as commitNobjAdapterGenerationToWithProvider,
} from "./nobj-adapter.js";
import {
  defaultRuntimeLinkContext,
  loadCanonicalRuntimeProvider,
} from "./nucleus-runtime.js";

interface MemoryRegionManifest {
  readonly name: string;
  readonly start: string;
  readonly end: string;
  readonly maxBytes: number;
}

interface MemoryProfileManifest {
  readonly name: string;
  readonly addressSpaceBytes: number;
  readonly regions: readonly MemoryRegionManifest[];
}

interface ProofManifest {
  readonly name: string;
  readonly source: string;
  readonly memoryProfile: string;
  /** Retained external ABI documentation; ATOM does not statically check it. */
  readonly interfaces?: readonly string[];
  readonly execution: {
    readonly entry: string;
    readonly maxInstructions: number;
    readonly maxCycles: number;
    readonly halted: boolean;
  };
  readonly symbols?: Readonly<Record<string, number>>;
  readonly writes?: readonly {
    readonly at: string;
    readonly bytes?: readonly number[];
    readonly ascii?: string;
  }[];
  readonly observations?: readonly {
    readonly at: string;
    readonly width: "u8" | "u16";
    readonly equals: number;
  }[];
  readonly extents?: readonly {
    readonly name: string;
    readonly from: string;
    readonly to: string;
    readonly maxBytes: number;
  }[];
  readonly nobj?: NobjProofManifest;
}

interface NobjProofManifest {
  readonly adapter: {
    readonly at: string;
    readonly lengthAt: string;
    readonly maxBytes: number;
  };
  readonly begin: NobjBegin;
  readonly map: NobjMap;
  readonly runtimeLinkContext?: RuntimeLinkContext;
  /** Materialize the committed object without entering it. */
  readonly materializeOnly?: boolean;
  readonly execution: {
    readonly maxInstructions: number;
    readonly maxCycles: number;
    readonly halted: boolean;
    readonly initialSp?: number;
    readonly expectedSp?: number;
    readonly expectedIx?: number;
    readonly expectedIy?: number;
    readonly writes?: readonly {
      readonly at: number;
      readonly bytes: readonly number[];
    }[];
  };
  readonly observations?: readonly NobjObservation[];
  readonly bankSwitch?: {
    readonly port: number;
    readonly windowBase: number;
    readonly windowCapacity: number;
  };
}

interface NobjObservation {
  readonly at: number;
  readonly width: "u8" | "u16";
  readonly equals: number;
  readonly bank?: number;
}

export interface NobjAdapterGeneration {
  readonly name: string;
  readonly producerMemory: Uint8Array;
  readonly start: number;
  readonly length: number;
  readonly maxBytes: number;
  readonly begin: NobjBegin;
  readonly map: NobjMap;
  readonly runtimeLinkContext?: RuntimeLinkContext;
  readonly store?: NobjGenerationStore;
  readonly spoolFactory?: NobjSpoolFactory;
  readonly lowMemoryPatchValidation?: boolean;
  readonly onImageByte?: (image: NobjAdapterImageByte) => void;
}

export interface NobjAdapterImageByte {
  readonly bank: number;
  readonly address: number;
  readonly value: number;
}

export interface ProofRegion {
  readonly name: string;
  readonly start: number;
  readonly end: number;
  readonly bytes: number;
}

export interface ProofExtent {
  readonly name: string;
  readonly bytes: number;
}

export interface ProofOutcome {
  readonly name: string;
  readonly instructions: number;
  readonly cycles: number;
  readonly recentProgramCounters: readonly number[];
  readonly regions: readonly ProofRegion[];
  readonly extents: readonly ProofExtent[];
  readonly symbols: Readonly<Record<string, number>>;
  readonly memory: Uint8Array;
  readonly nobj?: NobjExecutionOutcome;
}

export interface NobjExecutionOutcome {
  readonly serialized: Uint8Array;
  readonly parsed: ParsedNobj;
  readonly materialized: MaterializedNobj;
  readonly memory: Uint8Array;
  readonly instructions: number;
  readonly cycles: number;
  readonly selectedBank: number;
}

export class ProofFailure extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ProofFailure";
  }
}

export async function runProofManifest(
  manifestFile: string,
): Promise<ProofOutcome> {
  const manifestPath = path.resolve(manifestFile);
  const manifestDirectory = path.dirname(manifestPath);
  const manifest = readJson<ProofManifest>(manifestPath);
  const memoryProfile = readJson<MemoryProfileManifest>(
    path.resolve(manifestDirectory, manifest.memoryProfile),
  );
  const sourcePath = path.resolve(manifestDirectory, manifest.source);
  // Preserve declared interface-file existence, without claiming AZM's static
  // register analysis. Execution observations below remain the proof boundary.
  for (const file of manifest.interfaces ?? []) {
    readFileSync(path.resolve(manifestDirectory, file), "utf8");
  }
  const entry = path
    .relative(fileURLToPath(new URL("../asm/", import.meta.url)), sourcePath)
    .split(path.sep)
    .join("/");
  const assembly = entry === "vertical-slice/tokenizer-trace-proof.asm"
    ? (await import("../scripts/assemble-native-tokenizer.mjs")).assembleNativeTokenizerTrace()
    : entry === "vertical-slice/stage7-ll1-engine-proof.asm"
      ? (await import("../scripts/assemble-native-grammar.mjs")).assembleNativeGrammarProof()
      : (await import("../scripts/atom-source.mjs")).assembleAtomSource(entry);
  const assembled = await assembly.catch((cause: unknown) => {
    throw new ProofFailure(
      `${manifest.name}: ATOM assembly failed\n${cause instanceof Error ? cause.message : String(cause)}`,
    );
  });
  const symbols = assembled.symbols;
  const symbolValue = (name: string): number => {
    const wanted = name.toLowerCase();
    for (const [candidate, value] of Object.entries(symbols)) {
      if (candidate.toLowerCase() === wanted) return value;
    }
    throw new ProofFailure(`${manifest.name}: missing symbol ${name}`);
  };

  for (const [name, expected] of Object.entries(manifest.symbols ?? {})) {
    const actual = symbolValue(name);
    if (actual !== expected) {
      throw new ProofFailure(
        `${manifest.name}: symbol ${name} is ${hexWord(actual)}, expected ${hexWord(expected)}`,
      );
    }
  }

  const regions = memoryProfile.regions.map((region) => {
    const start = symbolValue(region.start);
    const end = symbolValue(region.end);
    const bytes = end - start;
    if (start < 0 || end > 0x10000 || bytes <= 0) {
      throw new ProofFailure(
        `${manifest.name}: invalid ${region.name} region ${hexWord(start)}..${hexWord(end)}`,
      );
    }
    if (bytes > region.maxBytes) {
      throw new ProofFailure(
        `${manifest.name}: ${region.name} uses ${bytes} bytes, limit ${region.maxBytes}`,
      );
    }
    return { name: region.name, start, end, bytes };
  });
  const orderedRegions = [...regions].sort(
    (left, right) => left.start - right.start,
  );
  if (orderedRegions[0]?.start !== 0) {
    throw new ProofFailure(
      `${manifest.name}: memory profile does not start at $0000`,
    );
  }
  for (let index = 1; index < orderedRegions.length; index += 1) {
    const previous = orderedRegions[index - 1];
    const current = orderedRegions[index];
    if (previous && current && previous.end !== current.start) {
      throw new ProofFailure(
        `${manifest.name}: ${previous.name} and ${current.name} do not meet`,
      );
    }
  }
  if (
    memoryProfile.addressSpaceBytes !== 0x10000 ||
    orderedRegions.at(-1)?.end !== memoryProfile.addressSpaceBytes
  ) {
    throw new ProofFailure(
      `${manifest.name}: memory profile does not cover exactly 64 KiB`,
    );
  }

  const extents = (manifest.extents ?? []).map((extent) => {
    const bytes = symbolValue(extent.to) - symbolValue(extent.from);
    if (bytes < 0 || bytes > extent.maxBytes) {
      throw new ProofFailure(
        `${manifest.name}: ${extent.name} uses ${bytes} bytes, limit ${extent.maxBytes}`,
      );
    }
    return { name: extent.name, bytes };
  });

  const runtime = createZ80Runtime(
    parseIntelHex(assembled.hex),
    symbolValue(manifest.execution.entry),
  );
  const memory = (runtime.hardware as unknown as { memory: Uint8Array }).memory;
  for (const write of manifest.writes ?? []) {
    const bytes =
      write.bytes ??
      (write.ascii === undefined
        ? undefined
        : Array.from(new TextEncoder().encode(write.ascii)));
    if (bytes === undefined) {
      throw new ProofFailure(
        `${manifest.name}: write at ${write.at} has no bytes`,
      );
    }
    const address = symbolValue(write.at);
    if (address < 0 || address + bytes.length > memory.length) {
      throw new ProofFailure(
        `${manifest.name}: write at ${write.at} is out of range`,
      );
    }
    memory.set(bytes, address);
  }

  let cycles = 0;
  let instructions = 0;
  const recentProgramCounters: number[] = [];
  while (
    instructions < manifest.execution.maxInstructions &&
    cycles <= manifest.execution.maxCycles &&
    !runtime.isHalted()
  ) {
    recentProgramCounters.push(runtime.getPC());
    if (recentProgramCounters.length > 16) recentProgramCounters.shift();
    const step = runtime.step();
    cycles += step.cycles ?? 0;
    instructions += 1;
  }

  const failures: string[] = [];
  if (runtime.isHalted() !== manifest.execution.halted) {
    failures.push(
      `halted=${runtime.isHalted()}, expected ${manifest.execution.halted}`,
    );
  }
  if (instructions > manifest.execution.maxInstructions) {
    failures.push(
      `instruction limit ${manifest.execution.maxInstructions} exceeded`,
    );
  }
  if (cycles > manifest.execution.maxCycles) {
    failures.push(`cycle limit ${manifest.execution.maxCycles} exceeded`);
  }
  for (const observation of manifest.observations ?? []) {
    const address = symbolValue(observation.at);
    const actual =
      observation.width === "u8"
        ? memory[address]
        : (memory[address] ?? 0) | ((memory[address + 1] ?? 0) << 8);
    if (actual !== observation.equals) {
      failures.push(
        `${observation.at}=${actual}, expected ${observation.equals}`,
      );
    }
  }
  if (failures.length > 0) {
    throw new ProofFailure(
      [
        `${manifest.name}: proof failed`,
        ...failures.map((failure) => `  ${failure}`),
        `  PC=${hexWord(runtime.getPC())} SP=${hexWord(runtime.cpu.sp)}`,
        `  recent PCs: ${recentProgramCounters.map(hexWord).join(" ")}`,
      ].join("\n"),
    );
  }

  const nobj =
    manifest.nobj === undefined
      ? undefined
      : await runNobjManifest(
          manifest.name,
          manifest.nobj,
          memory,
          symbolValue,
        );

  return {
    name: manifest.name,
    instructions,
    cycles,
    recentProgramCounters,
    regions,
    extents,
    symbols,
    memory,
    ...(nobj === undefined ? {} : { nobj }),
  };
}

const runNobjManifest = async (
  name: string,
  manifest: NobjProofManifest,
  producerMemory: Uint8Array,
  symbol: (name: string) => number,
): Promise<NobjExecutionOutcome> => {
  const start = symbol(manifest.adapter.at);
  const lengthAddress = symbol(manifest.adapter.lengthAt);
  const length =
    (producerMemory[lengthAddress] ?? 0) |
    ((producerMemory[lengthAddress + 1] ?? 0) << 8);
  const runtimeLinkContext =
    manifest.runtimeLinkContext ?? defaultRuntimeLinkContext;
  const serialized = await commitNobjAdapterGeneration({
    name,
    producerMemory,
    start,
    length,
    maxBytes: manifest.adapter.maxBytes,
    begin: manifest.begin,
    map: manifest.map,
    runtimeLinkContext,
  });
  if (manifest.materializeOnly === true) {
    const parsed = parseNobjForExecution(serialized);
    const materialized = materializeNobj(parsed);
    const memory = new Uint8Array(0x10000);
    if (materialized.flatImage !== undefined) {
      memory.set(materialized.flatImage, parsed.begin.imageBase);
    }
    return {
      serialized,
      parsed,
      materialized,
      memory,
      instructions: 0,
      cycles: 0,
      selectedBank: parsed.map.entryBank,
    };
  }
  return executeCommittedNobj(serialized, manifest.execution, {
    observations: manifest.observations,
    bankSwitch: manifest.bankSwitch,
  });
};

export const commitNobjAdapterGeneration = async (
  generation: NobjAdapterGeneration,
): Promise<Uint8Array> => {
  const runtimeLinkContext =
    generation.runtimeLinkContext ?? defaultRuntimeLinkContext;
  const runtimeProvider = await loadCanonicalRuntimeProvider([
    runtimeLinkContext,
  ]);
  return commitNobjAdapterGenerationWithProvider({
    ...generation,
    runtimeLinkContext,
    runtimeProvider,
  });
};

export const commitNobjAdapterGenerationTo = async (
  generation: NobjAdapterGeneration,
  output: NobjSequentialOutput,
): Promise<NobjCommitMetadata> => {
  const runtimeLinkContext =
    generation.runtimeLinkContext ?? defaultRuntimeLinkContext;
  const runtimeProvider = await loadCanonicalRuntimeProvider([
    runtimeLinkContext,
  ]);
  return commitNobjAdapterGenerationToWithProvider(
    { ...generation, runtimeLinkContext, runtimeProvider },
    output,
  );
};

export const executeCommittedNobj = (
  serialized: Uint8Array,
  execution: {
    readonly maxInstructions: number;
    readonly maxCycles: number;
    readonly halted: boolean;
    readonly initialSp?: number;
    readonly expectedSp?: number;
    readonly expectedIx?: number;
    readonly expectedIy?: number;
    readonly writes?: readonly {
      readonly at: number;
      readonly bytes: readonly number[];
    }[];
  },
  options: {
    readonly observations?: readonly NobjObservation[];
    readonly bankSwitch?: NobjProofManifest["bankSwitch"];
    readonly ioRead?: (port: number) => number;
    readonly ioWrite?: (port: number, value: number) => void;
  } = {},
): NobjExecutionOutcome => {
  const parsed = parseNobjForExecution(serialized);
  const materialized = materializeNobj(parsed);
  const commonMemory = new Uint8Array(0x10000);
  let selectedBank = parsed.map.entryBank;
  if (materialized.flatImage !== undefined) {
    commonMemory.set(materialized.flatImage, parsed.begin.imageBase);
  } else {
    const entryImage = materialized.banks[selectedBank];
    if (entryImage === undefined) {
      throw new ProofFailure("entry bank image is unavailable");
    }
    commonMemory.set(entryImage, parsed.begin.imageBase);
  }
  const program = {
    memory: commonMemory,
    startAddress: parsed.map.entryAddress,
  };
  const switchConfig = options.bankSwitch;
  const runtime = createZ80Runtime(
    program,
    parsed.map.entryAddress,
    {
      read: (port) => options.ioRead?.(port) ?? 0,
      write: (port, value) => {
        if (switchConfig !== undefined && (port & 0xff) === switchConfig.port) {
          if (value >= parsed.begin.bankCount) {
            throw new ProofFailure(`bank selector ${value} is out of range`);
          }
          selectedBank = value;
          const selectedImage = materialized.banks[selectedBank];
          if (selectedImage === undefined) {
            throw new ProofFailure(`bank image ${selectedBank} is unavailable`);
          }
          runtime.hardware.memory.set(selectedImage, parsed.begin.imageBase);
        }
        options.ioWrite?.(port, value);
      },
    },
    parsed.begin.banked && switchConfig !== undefined
      ? {
          romRanges: [
            {
              start: switchConfig.windowBase,
              end: switchConfig.windowBase + switchConfig.windowCapacity - 1,
            },
          ],
        }
      : undefined,
  );
  if (execution.initialSp !== undefined) {
    if (
      !Number.isInteger(execution.initialSp) ||
      execution.initialSp < 0 ||
      execution.initialSp > 0xffff
    ) {
      throw new ProofFailure("NOBJ execution initial SP is outside 0..65535");
    }
    runtime.cpu.sp = execution.initialSp;
  }
  for (const write of execution.writes ?? []) {
    if (write.at < 0 || write.at + write.bytes.length > 0x10000) {
      throw new ProofFailure("NOBJ execution write exceeds address space");
    }
    runtime.hardware.memory.set(write.bytes, write.at);
  }
  if (parsed.begin.banked) {
    if (switchConfig === undefined) {
      throw new ProofFailure(
        "banked NOBJ execution requires a bank-switch hook",
      );
    }
  }

  let instructions = 0;
  let cycles = 0;
  const recentProgramCounters: number[] = [];
  while (
    instructions < execution.maxInstructions &&
    cycles <= execution.maxCycles &&
    !runtime.isHalted()
  ) {
    recentProgramCounters.push(runtime.getPC());
    if (recentProgramCounters.length > 16) recentProgramCounters.shift();
    const step = runtime.step();
    instructions += 1;
    cycles += step.cycles ?? 0;
  }
  const failures: string[] = [];
  if (runtime.isHalted() !== execution.halted) {
    failures.push(`halted=${runtime.isHalted()}, expected ${execution.halted}`);
  }
  if (instructions >= execution.maxInstructions && !runtime.isHalted()) {
    failures.push(`instruction limit ${execution.maxInstructions} reached`);
  }
  if (cycles > execution.maxCycles) {
    failures.push(`cycle limit ${execution.maxCycles} exceeded`);
  }
  if (
    execution.expectedSp !== undefined &&
    runtime.cpu.sp !== execution.expectedSp
  ) {
    failures.push(
      `SP=${hexWord(runtime.cpu.sp)}, expected ${hexWord(execution.expectedSp)}`,
    );
  }
  if (
    execution.expectedIx !== undefined &&
    runtime.cpu.ix !== execution.expectedIx
  ) {
    failures.push(
      `IX=${hexWord(runtime.cpu.ix)}, expected ${hexWord(execution.expectedIx)}`,
    );
  }
  if (
    execution.expectedIy !== undefined &&
    runtime.cpu.iy !== execution.expectedIy
  ) {
    failures.push(
      `IY=${hexWord(runtime.cpu.iy)}, expected ${hexWord(execution.expectedIy)}`,
    );
  }
  for (const observation of options.observations ?? []) {
    const observed =
      observation.bank === undefined
        ? runtime.hardware.memory
        : materialized.banks[observation.bank];
    if (observed === undefined) {
      failures.push(`observation bank ${observation.bank} is unavailable`);
      continue;
    }
    const offset =
      observation.bank === undefined
        ? observation.at
        : observation.at - parsed.begin.imageBase;
    const actual =
      observation.width === "u8"
        ? observed[offset]
        : (observed[offset] ?? 0) | ((observed[offset + 1] ?? 0) << 8);
    if (actual !== observation.equals) {
      failures.push(
        `NOBJ observation at ${hexWord(observation.at)}=${actual}, expected ${observation.equals}`,
      );
    }
  }
  if (failures.length > 0) {
    throw new ProofFailure(
      `NOBJ execution failed\n${failures.join("\n")}\nPC=${hexWord(runtime.getPC())} bank=${selectedBank}\nrecent PCs: ${recentProgramCounters.map(hexWord).join(" ")}`,
    );
  }
  return {
    serialized: serialized.slice(),
    parsed,
    materialized,
    memory: runtime.hardware.memory.slice(),
    instructions,
    cycles,
    selectedBank,
  };
};

const parseNobjForExecution = (serialized: Uint8Array): ParsedNobj => {
  // Kept as a named boundary so no execution path can bypass strict validation.
  const store = new NobjGenerationStore();
  return store.publish(serialized);
};

function readJson<T>(file: string): T {
  return JSON.parse(readFileSync(file, "utf8")) as T;
}

function hexWord(value: number): string {
  return `$${(value & 0xffff).toString(16).padStart(4, "0")}`;
}

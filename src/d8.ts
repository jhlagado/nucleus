import type { createZ80Runtime } from "@jhlagado/debug80-runtime";

import type { NucleusSourcePart } from "./compiler.js";
import {
  assertNucleusSemanticOperationKeys,
  nucleusD8SourceName,
} from "./d8-internal.js";
import type { NobjBegin, ParsedNobj } from "./nobj.js";
import type { NobjAdapterImageByte } from "./proof.js";

type CompilerCpu = ReturnType<typeof createZ80Runtime>["cpu"];

export const nucleusDebugPorts = {
  source: 0xd8,
  declaration: 0xd9,
  contextPush: 0xda,
  contextPop: 0xdb,
  routine: 0xdc,
  semanticStart: 0xdd,
  semanticEnd: 0xde,
  imageByte: 0xdf,
} as const;

export const isNucleusDebugPort = (port: number): boolean =>
  (port & 0xff) >= nucleusDebugPorts.source &&
  (port & 0xff) <= nucleusDebugPorts.imageByte;

export interface NucleusLoadedSourcePart {
  readonly id: number;
  readonly name: string;
  readonly start: number;
  readonly end: number;
  readonly bytes: Uint8Array;
}

export interface NucleusD8Segment {
  readonly start: number;
  readonly end: number;
  readonly line: number;
  readonly column: number;
  readonly kind: "code";
  readonly confidence: "high";
  readonly lstLine: number;
  readonly lstTextId: number;
}

export interface NucleusD8Symbol {
  readonly name: string;
  readonly address: number;
  readonly line: number;
  readonly kind: "label";
  readonly scope: "global";
}

export interface NucleusD8DebugMap {
  readonly format: "d8-debug-map";
  readonly version: 1;
  readonly arch: "z80";
  readonly addressWidth: 16;
  readonly endianness: "little";
  readonly files: Readonly<
    Record<
      string,
      {
        readonly meta: { readonly lineCount: number };
        readonly segments?: readonly NucleusD8Segment[];
        readonly symbols?: readonly NucleusD8Symbol[];
      }
    >
  >;
  readonly lstText: readonly string[];
  readonly segmentDefaults: {
    readonly kind: "code";
    readonly confidence: "high";
  };
  readonly symbolDefaults: {
    readonly kind: "label";
    readonly scope: "global";
  };
  readonly memory: {
    readonly segments: readonly {
      readonly name: string;
      readonly start: number;
      readonly end: number;
      readonly kind: "rom" | "banked";
      readonly bank: number;
    }[];
  };
  readonly generator: {
    readonly name: "Nucleus";
    readonly tool: "nucleus";
  };
}

export interface NucleusD8BankMap {
  readonly bank: number;
  readonly map: NucleusD8DebugMap;
}

export interface NucleusDebugMapping {
  readonly maps: readonly NucleusD8BankMap[];
  readonly sourceMarks: number;
  readonly declarationMarks: number;
  readonly semanticOperations: number;
  readonly semanticBytes: number;
  readonly imageBytes: number;
}

export const nucleusD8OutputPaths = (
  requestedPath: string,
  mapping: NucleusDebugMapping,
): readonly { bank: number; path: string; map: NucleusD8DebugMap }[] => {
  if (mapping.maps.length === 1) {
    const only = mapping.maps[0];
    return only === undefined ? [] : [{ ...only, path: requestedPath }];
  }
  const suffix = ".d8.json";
  const base = requestedPath.toLowerCase().endsWith(suffix)
    ? requestedPath.slice(0, -suffix.length)
    : requestedPath;
  return mapping.maps.map(({ bank, map }) => ({
    bank,
    path: `${base}.bank-${bank}.d8.json`,
    map,
  }));
};

interface SourceLocation {
  readonly part: NucleusLoadedSourcePart;
  readonly offset: number;
  readonly line: number;
  readonly column: number;
}

interface DeclarationRecord extends SourceLocation {
  readonly key: number;
}

interface SourceContext extends SourceLocation {
  readonly key: number;
  readonly routineName?: string;
}

interface RoutineRecord {
  readonly name: string;
  readonly context: SourceContext;
  address?: number;
  bank?: number;
}

interface ImageObservation {
  readonly bank: number;
  readonly address: number;
  readonly value: number;
  readonly semanticKey?: number;
  readonly source?: SourceContext;
}

export interface NucleusDebugTraceSymbols {
  readonly sourcePartId: number;
  readonly tokenStartOffset: number;
  readonly tokenStartLine: number;
  readonly tokenStartColumn: number;
  readonly sinkCursor: number;
  readonly semanticPayloadBase: number;
  readonly semanticReadCursor: number;
  readonly declarationNamePointer: number;
  readonly declarationNameLength: number;
  readonly stage7CurrentRoutine: number;
  readonly stage7RoutineTableBase: number;
  readonly stage7RoutineEntrySize: number;
}

const readWord = (memory: Uint8Array, address: number): number =>
  (memory[address] ?? 0) | ((memory[address + 1] ?? 0) << 8);

const decode = (bytes: Uint8Array): string => new TextDecoder().decode(bytes);

const lineCount = (bytes: Uint8Array): number => {
  let count = 1;
  for (const byte of bytes) if (byte === 0x0a) count += 1;
  return count;
};

const lineText = (
  part: NucleusLoadedSourcePart,
  wantedLine: number,
): string => {
  let line = 1;
  let start = 0;
  for (let index = 0; index <= part.bytes.length; index += 1) {
    const byte = part.bytes[index];
    if (index === part.bytes.length || byte === 0x0a) {
      if (line === wantedLine) {
        let end = index;
        if (end > start && part.bytes[end - 1] === 0x0d) end -= 1;
        return decode(part.bytes.slice(start, end));
      }
      line += 1;
      start = index + 1;
    }
  }
  return "";
};

const positionAtOffset = (
  part: NucleusLoadedSourcePart,
  offset: number,
): { line: number; column: number } => {
  if (offset < 0 || offset > part.bytes.length) {
    throw new Error(`source offset ${offset} is outside part ${part.id}`);
  }
  let line = 1;
  let column = 1;
  for (let index = 0; index < offset; index += 1) {
    const byte = part.bytes[index];
    if (byte === 0x0d && part.bytes[index + 1] === 0x0a) {
      index += 1;
      line += 1;
      column = 1;
    } else if (byte === 0x0a) {
      line += 1;
      column = 1;
    } else {
      column += 1;
    }
  }
  return { line, column };
};

export class NucleusDebugCollector {
  readonly #memory: Uint8Array;
  readonly #parts: readonly NucleusLoadedSourcePart[];
  readonly #symbols: NucleusDebugTraceSymbols;
  readonly #marks: SourceContext[] = [];
  readonly #declarations: DeclarationRecord[] = [];
  readonly #contexts: SourceContext[] = [];
  readonly #routines: RoutineRecord[] = [];
  readonly #semanticKeys: number[] = [];
  readonly #images: ImageObservation[] = [];
  readonly #errors: string[] = [];
  #currentContext: SourceContext | undefined;
  #activeSource: SourceContext | undefined;
  #activeSemanticKey: number | undefined;
  #generationStarted = false;
  #semanticEndCount = 0;
  #semanticEndKey: number | undefined;

  public constructor(
    memory: Uint8Array,
    parts: readonly NucleusLoadedSourcePart[],
    symbols: NucleusDebugTraceSymbols,
  ) {
    this.#memory = memory;
    this.#parts = parts;
    this.#symbols = symbols;
  }

  public collect(port: number, cpu: CompilerCpu): void {
    switch (port & 0xff) {
      case nucleusDebugPorts.source:
        this.#recordSourceMark();
        return;
      case nucleusDebugPorts.declaration:
        this.#recordDeclaration();
        return;
      case nucleusDebugPorts.contextPush:
        if (this.#currentContext === undefined) {
          this.#errors.push(
            "construct context push has no current source mark",
          );
        } else {
          this.#contexts.push(this.#currentContext);
        }
        return;
      case nucleusDebugPorts.contextPop:
        this.#resumeContext();
        return;
      case nucleusDebugPorts.routine:
        this.#recordRoutine();
        return;
      case nucleusDebugPorts.semanticStart:
        this.#recordSemanticStart();
        return;
      case nucleusDebugPorts.semanticEnd:
        this.#recordSemanticEnd();
        return;
      case nucleusDebugPorts.imageByte:
        this.#recordImageByte(cpu);
        return;
      default:
        this.#errors.push(`unknown Nucleus debug port ${port & 0xff}`);
    }
  }

  public finish(
    parsed: ParsedNobj,
    begin: NobjBegin,
    expectedImages: readonly NobjAdapterImageByte[],
  ): NucleusDebugMapping {
    if (this.#contexts.length !== 0) {
      this.#errors.push(
        `successful parse left ${this.#contexts.length} source contexts active`,
      );
    }
    if (this.#semanticEndCount !== 1) {
      this.#errors.push(
        `successful dispatch emitted ${this.#semanticEndCount} semantic-end events`,
      );
    }
    const operationCount =
      this.#memory[this.#symbols.semanticPayloadBase - 1] ?? 0;
    if (operationCount !== this.#semanticKeys.length) {
      this.#errors.push(
        `semantic operation count ${operationCount} differs from ${this.#semanticKeys.length} trace events`,
      );
    }
    try {
      const transcriptLength = this.#semanticEndKey ?? 0;
      const payload = this.#memory.subarray(
        this.#symbols.semanticPayloadBase,
        this.#symbols.semanticPayloadBase + transcriptLength,
      );
      assertNucleusSemanticOperationKeys(
        payload,
        operationCount,
        this.#semanticKeys,
      );
    } catch (error) {
      this.#errors.push(error instanceof Error ? error.message : String(error));
    }
    this.#validateImages(parsed, expectedImages);
    if (this.#errors.length > 0) {
      throw new Error(
        `invalid Nucleus debug trace\n${this.#errors.join("\n")}`,
      );
    }
    return {
      maps: Array.from({ length: begin.bankCount }, (_, bank) => ({
        bank,
        map: this.#buildMap(bank, begin),
      })),
      sourceMarks: this.#marks.length,
      declarationMarks: this.#declarations.length,
      semanticOperations: this.#semanticKeys.length,
      semanticBytes: this.#semanticEndKey ?? 0,
      imageBytes: this.#images.length,
    };
  }

  #semanticKey(cursorAddress: number): number {
    const key =
      readWord(this.#memory, cursorAddress) - this.#symbols.semanticPayloadBase;
    if (key < 0 || key > 0x1ff) {
      this.#errors.push(
        `semantic key ${key} is outside the transcript payload`,
      );
    }
    return key;
  }

  #partById(id: number): NucleusLoadedSourcePart | undefined {
    return this.#parts.find((part) => part.id === id);
  }

  #locationFromState(): SourceLocation | undefined {
    const id = this.#memory[this.#symbols.sourcePartId] ?? 0;
    const part = this.#partById(id);
    if (part === undefined) {
      this.#errors.push(`source mark refers to unknown part ${id}`);
      return undefined;
    }
    const offset = readWord(this.#memory, this.#symbols.tokenStartOffset);
    const actual = positionAtOffset(part, offset);
    const line = readWord(this.#memory, this.#symbols.tokenStartLine);
    const column = readWord(this.#memory, this.#symbols.tokenStartColumn);
    if (line !== actual.line || column !== actual.column) {
      this.#errors.push(
        `source position ${id}:${line}:${column} disagrees with byte offset ${offset} (${actual.line}:${actual.column})`,
      );
    }
    return { part, offset, line, column };
  }

  #locationFromPointer(
    pointer: number,
    length: number,
  ): SourceLocation | undefined {
    const part = this.#parts.find(
      (candidate) =>
        pointer >= candidate.start && pointer + length <= candidate.end,
    );
    if (part === undefined || length < 1) {
      this.#errors.push(
        `name pointer ${pointer.toString(16)} length ${length} is outside loaded source`,
      );
      return undefined;
    }
    const offset = pointer - part.start;
    const retained = this.#memory.slice(pointer, pointer + length);
    const original = part.bytes.slice(offset, offset + length);
    if (!retained.every((byte, index) => byte === original[index])) {
      this.#errors.push(
        `name pointer ${pointer.toString(16)} does not retain the original source spelling`,
      );
      return undefined;
    }
    const { line, column } = positionAtOffset(part, offset);
    return { part, offset, line, column };
  }

  #appendMark(context: SourceContext): void {
    const previous = this.#marks.at(-1);
    if (previous !== undefined && context.key < previous.key) {
      this.#errors.push(
        `source key ${context.key} follows larger key ${previous.key}`,
      );
    }
    this.#marks.push(context);
    this.#currentContext = context;
  }

  #recordSourceMark(): void {
    const location = this.#locationFromState();
    if (location === undefined) return;
    this.#appendMark({
      ...location,
      key: this.#semanticKey(this.#symbols.sinkCursor),
    });
  }

  #recordDeclaration(): void {
    const pointer = readWord(
      this.#memory,
      this.#symbols.declarationNamePointer,
    );
    const length = this.#memory[this.#symbols.declarationNameLength] ?? 0;
    const location = this.#locationFromPointer(pointer, length);
    if (location !== undefined) {
      this.#declarations.push({
        ...location,
        key: this.#semanticKey(this.#symbols.sinkCursor),
      });
    }
  }

  #recordRoutine(): void {
    const current = this.#memory[this.#symbols.stage7CurrentRoutine] ?? 0xff;
    let pointer: number;
    let length: number;
    if (current === 0xff) {
      pointer = readWord(this.#memory, this.#symbols.declarationNamePointer);
      length = this.#memory[this.#symbols.declarationNameLength] ?? 0;
    } else {
      const entry =
        this.#symbols.stage7RoutineTableBase +
        current * this.#symbols.stage7RoutineEntrySize;
      pointer = readWord(this.#memory, entry);
      length = this.#memory[entry + 2] ?? 0;
    }
    const location = this.#locationFromPointer(pointer, length);
    if (location === undefined) return;
    const name = decode(this.#memory.slice(pointer, pointer + length));
    const context: SourceContext = {
      ...location,
      key: this.#semanticKey(this.#symbols.sinkCursor),
      routineName: name,
    };
    this.#contexts.push(context);
    this.#appendMark(context);
    this.#routines.push({ name, context });
  }

  #resumeContext(): void {
    const context = this.#contexts.pop();
    if (context === undefined) {
      this.#errors.push("source context stack underflow");
      return;
    }
    this.#appendMark({
      ...context,
      key: this.#semanticKey(this.#symbols.sinkCursor),
    });
  }

  #recordSemanticStart(): void {
    this.#beginGeneration();
    if (this.#semanticEndCount !== 0) {
      this.#errors.push("semantic operation started after semantic end");
    }
    const key = this.#semanticKey(this.#symbols.semanticReadCursor);
    const previous = this.#semanticKeys.at(-1);
    if (previous === undefined && key !== 0) {
      this.#errors.push(`first semantic key is ${key}, expected 0`);
    }
    if (previous !== undefined && key <= previous) {
      this.#errors.push(
        `semantic key ${key} does not strictly follow ${previous}`,
      );
    }
    this.#semanticKeys.push(key);
    this.#activeSemanticKey = key;
    this.#activeSource = [...this.#marks]
      .reverse()
      .find((mark) => mark.key <= key);
  }

  #recordSemanticEnd(): void {
    this.#beginGeneration();
    this.#semanticEndCount += 1;
    if (this.#semanticEndKey === undefined) {
      this.#semanticEndKey = this.#semanticKey(
        this.#symbols.semanticReadCursor,
      );
    }
    this.#activeSemanticKey = undefined;
    this.#activeSource = undefined;
  }

  #beginGeneration(): void {
    if (this.#generationStarted) return;
    this.#generationStarted = true;
    if (this.#contexts.length !== 0) {
      this.#errors.push(
        `generation began with ${this.#contexts.length} source contexts active`,
      );
    }
  }

  #recordImageByte(cpu: CompilerCpu): void {
    if (this.#semanticEndCount !== 0) {
      this.#errors.push("IMAGE byte was emitted after semantic end");
    }
    const observation: ImageObservation = {
      bank: cpu.c & 0xff,
      address: ((cpu.h << 8) | cpu.l) & 0xffff,
      value: cpu.a & 0xff,
      ...(this.#activeSemanticKey === undefined
        ? {}
        : { semanticKey: this.#activeSemanticKey }),
      ...(this.#activeSource === undefined
        ? {}
        : { source: this.#activeSource }),
    };
    this.#images.push(observation);
    if (observation.source?.routineName !== undefined) {
      const routine = this.#routines.find(
        (candidate) =>
          candidate.address === undefined &&
          candidate.name === observation.source?.routineName &&
          candidate.context.part.id === observation.source?.part.id &&
          candidate.context.offset === observation.source?.offset,
      );
      if (routine !== undefined) {
        routine.address = observation.address;
        routine.bank = observation.bank;
      }
    }
  }

  #validateImages(
    parsed: ParsedNobj,
    expectedImages: readonly NobjAdapterImageByte[],
  ): void {
    if (this.#images.length !== expectedImages.length) {
      this.#errors.push(
        `IMAGE trace count ${this.#images.length} differs from ${expectedImages.length} compiler-adapter IMAGE bytes`,
      );
    }
    const comparedLength = Math.min(this.#images.length, expectedImages.length);
    for (let index = 0; index < comparedLength; index += 1) {
      const event = this.#images[index];
      const expected = expectedImages[index];
      if (
        event !== undefined &&
        expected !== undefined &&
        (event.bank !== expected.bank ||
          event.address !== expected.address ||
          event.value !== expected.value)
      ) {
        this.#errors.push(
          `IMAGE trace ${index} is ${event.bank}:${event.address.toString(16)}=${event.value}, expected compiler-adapter byte ${expected.bank}:${expected.address.toString(16)}=${expected.value}`,
        );
      }
    }
    for (const event of this.#images) {
      const record = parsed.images.find(
        (candidate) =>
          candidate.bank === event.bank &&
          event.address >= candidate.address &&
          event.address < candidate.address + candidate.bytes.length,
      );
      const actual =
        record?.bytes[event.address - (record?.address ?? event.address)];
      if (actual !== event.value) {
        this.#errors.push(
          `IMAGE trace ${event.bank}:${event.address.toString(16)}=${event.value} is absent from committed NOBJ`,
        );
      }
    }
  }

  #buildMap(bank: number, begin: NobjBegin): NucleusD8DebugMap {
    const mapped = this.#images.filter(
      (event): event is ImageObservation & { source: SourceContext } =>
        event.bank === bank && event.source !== undefined,
    );
    const segments: Array<{
      file: string;
      location: SourceContext;
      start: number;
      end: number;
    }> = [];
    for (const event of mapped) {
      const file = nucleusD8SourceName(event.source.part.name);
      const previous = segments.at(-1);
      if (
        previous !== undefined &&
        previous.end === event.address &&
        previous.file === file &&
        previous.location.line === event.source.line &&
        previous.location.column === event.source.column
      ) {
        previous.end += 1;
      } else {
        segments.push({
          file,
          location: event.source,
          start: event.address,
          end: event.address + 1,
        });
      }
    }

    const texts: string[] = [];
    const textIds = new Map<string, number>();
    const files = Object.create(null) as Record<
      string,
      {
        meta: { lineCount: number };
        segments?: NucleusD8Segment[];
        symbols?: NucleusD8Symbol[];
      }
    >;
    for (const part of this.#parts) {
      files[nucleusD8SourceName(part.name)] = {
        meta: { lineCount: lineCount(part.bytes) },
      };
    }
    for (const segment of segments) {
      const text = lineText(segment.location.part, segment.location.line);
      let lstTextId = textIds.get(text);
      if (lstTextId === undefined) {
        lstTextId = texts.length;
        texts.push(text);
        textIds.set(text, lstTextId);
      }
      const entry = files[segment.file];
      if (entry === undefined) continue;
      entry.segments ??= [];
      entry.segments.push({
        start: segment.start,
        end: segment.end,
        line: segment.location.line,
        column: segment.location.column,
        kind: "code",
        confidence: "high",
        lstLine: segment.location.line,
        lstTextId,
      });
    }
    for (const routine of this.#routines) {
      if (routine.address === undefined || routine.bank !== bank) continue;
      const file = nucleusD8SourceName(routine.context.part.name);
      const entry = files[file];
      if (entry === undefined) continue;
      entry.symbols ??= [];
      entry.symbols.push({
        name: routine.name,
        address: routine.address,
        line: routine.context.line,
        kind: "label",
        scope: "global",
      });
    }
    return {
      format: "d8-debug-map",
      version: 1,
      arch: "z80",
      addressWidth: 16,
      endianness: "little",
      files,
      lstText: texts,
      segmentDefaults: { kind: "code", confidence: "high" },
      symbolDefaults: { kind: "label", scope: "global" },
      memory: {
        segments: [
          {
            name: begin.banked ? `Nucleus bank ${bank}` : "Nucleus image",
            start: begin.imageBase,
            end: begin.imageBase + begin.imageCapacity,
            kind: begin.banked ? "banked" : "rom",
            bank,
          },
        ],
      },
      generator: { name: "Nucleus", tool: "nucleus" },
    };
  }
}

export const sourcePartBytes = (part: NucleusSourcePart): Uint8Array =>
  typeof part.source === "string"
    ? new TextEncoder().encode(part.source)
    : part.source;

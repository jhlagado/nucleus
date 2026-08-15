import { createHash } from "node:crypto";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { debugCompilerHex, debugCompilerSymbols, normalCompilerHex, normalCompilerSymbols, } from "./generated-compiler-images.js";
import { materializeNobj, parseNobj, } from "./nobj.js";
import { commitNobjAdapterGeneration, } from "./proof.js";
import { isNucleusDebugPort, NucleusDebugCollector, sourcePartBytes, } from "./d8.js";
const SOURCE_BASE = normalCompilerSymbols.SourceBase ?? 0x5000;
const SOURCE_LIMIT = normalCompilerSymbols.SourceLimit ?? 0x5800;
const TARGET_DESCRIPTOR = 0x9e00;
const PART_BANKS = TARGET_DESCRIPTOR + 0x10;
const RETURN_SENTINEL = 0x9fff;
const STACK_TOP = 0xff00;
const RUNTIME_IDENTITY = 8;
const TARGET_DESCRIPTOR_SIZE = 15;
const TARGET_MAP_SIZE = 0x28;
const MAX_SOURCE_PARTS = 8;
const DEFAULT_INSTRUCTION_LIMIT = 5000000;
const DEFAULT_CYCLE_LIMIT = 50000000;
export const nucleusCompilerCapacities = {
    sourceParts: MAX_SOURCE_PARTS,
    sourceWindowBytes: SOURCE_LIMIT - SOURCE_BASE,
    sourceDescriptorBytesPerPart: 5,
    targetBanks: 4,
    instructionLimit: DEFAULT_INSTRUCTION_LIMIT,
    cycleLimit: DEFAULT_CYCLE_LIMIT,
};
export const defaultNucleusServices = {
    readInputByte: 0x7000,
    writeOutputByte: 0x7003,
    readStorageByte: 0x7006,
    rewindStorageInput: 0x7009,
    writeStorageByte: 0x700c,
    seekStorageOutput: 0x700f,
    success: 0x7012,
    unhandledFailure: 0x7015,
    trap: 0x7018,
    farCall: 0x701b,
    farJump: 0x701e,
};
const hexByte = (value) => (value & 0xff).toString(16).toUpperCase().padStart(2, "0");
const intelHexRecord = (address, recordType, bytes) => {
    const header = [bytes.length, address >>> 8, address, recordType];
    let sum = 0;
    let body = "";
    for (const value of [...header, ...bytes]) {
        sum = (sum + value) & 0xff;
        body += hexByte(value);
    }
    return `:${body}${hexByte(-sum)}`;
};
/** Convert a successful flat-target compile into a Debug80-loadable Intel HEX image. */
export const writeNucleusIntelHex = (result) => {
    const image = result.materialized.flatImage;
    if (image === undefined) {
        throw new Error("Intel HEX output requires a flat Nucleus target");
    }
    const { imageBase } = result.materialized.parsed.begin;
    const usedLength = result.materialized.parsed.map.banks[0]?.usedLength ?? 0;
    const lines = [];
    for (let offset = 0; offset < usedLength; offset += 16) {
        lines.push(intelHexRecord(imageBase + offset, 0, image.slice(offset, Math.min(offset + 16, usedLength))));
    }
    lines.push(intelHexRecord(0, 1, new Uint8Array()));
    return `${lines.join("\n")}\n`;
};
const compilerImages = new Map();
const symbol = (symbols, name) => {
    const wanted = name.toLowerCase();
    for (const [candidate, value] of Object.entries(symbols)) {
        if (candidate.toLowerCase() === wanted)
            return value;
    }
    throw new Error(`Nucleus compiler image is missing symbol ${name}`);
};
const loadCompilerImage = async (debugHooks) => {
    let pending = compilerImages.get(debugHooks);
    if (pending === undefined) {
        pending = (async () => {
            const hex = debugHooks ? debugCompilerHex : normalCompilerHex;
            const symbols = debugHooks ? debugCompilerSymbols : normalCompilerSymbols;
            return { program: parseIntelHex(hex), symbols };
        })();
        compilerImages.set(debugHooks, pending);
    }
    return pending;
};
const compilerImageFingerprint = (image) => {
    const hash = createHash("sha256");
    hash.update(image.program.memory);
    hash.update(JSON.stringify(Object.entries(image.symbols).sort(([left], [right]) => left.localeCompare(right))));
    return hash.digest("hex");
};
export const nucleusCompilerInfo = async () => {
    const [normal, debug] = await Promise.all([
        loadCompilerImage(false),
        loadCompilerImage(true),
    ]);
    return {
        hostApiVersion: 1,
        languageVersion: "0.1",
        runtimeIdentity: RUNTIME_IDENTITY,
        normalImageSha256: compilerImageFingerprint(normal),
        debugImageSha256: compilerImageFingerprint(debug),
        capacities: nucleusCompilerCapacities,
        targets: { flat: true, banked: true, maxBanks: 4 },
    };
};
const requireWord = (name, value) => {
    if (!Number.isInteger(value) || value < 0 || value > 0xffff) {
        throw new RangeError(`${name} is outside 0..65535`);
    }
};
const writeWord = (memory, address, value) => {
    requireWord("word", value);
    memory[address] = value & 0xff;
    memory[address + 1] = value >>> 8;
};
const readWord = (memory, address) => (memory[address] ?? 0) | ((memory[address + 1] ?? 0) << 8);
const prepareSource = (memory, parts, sourceBase, sourceLimit, requestedBanks) => {
    if (parts.length < 1 || parts.length > MAX_SOURCE_PARTS) {
        throw new RangeError(`Nucleus source requires 1..${MAX_SOURCE_PARTS} parts`);
    }
    const encoded = parts.map(sourcePartBytes);
    const loaded = [];
    let sourceCursor = sourceBase + parts.length * 5;
    for (let index = 0; index < encoded.length; index += 1) {
        const bytes = encoded[index] ?? new Uint8Array();
        const descriptor = sourceBase + index * 5;
        const end = sourceCursor + bytes.length;
        if (end > sourceLimit) {
            throw new RangeError("Nucleus source parts exceed the 2 KiB host source window");
        }
        memory[descriptor] = index + 1;
        writeWord(memory, descriptor + 1, sourceCursor);
        writeWord(memory, descriptor + 3, end);
        memory.set(bytes, sourceCursor);
        loaded.push({
            id: index + 1,
            name: parts[index]?.name ?? `part-${index + 1}.nu`,
            start: sourceCursor,
            end,
            bytes,
        });
        sourceCursor = end;
    }
    const partBanks = requestedBanks?.slice() ?? encoded.map(() => 0);
    if (partBanks.length !== encoded.length) {
        throw new RangeError("Nucleus target partBanks must match source parts");
    }
    return { partBanks, loaded };
};
const isBankedTarget = (target) => Object.prototype.hasOwnProperty.call(target, "bankCount");
const flatTargetUsesRomMode = (target) => {
    const imageBase = target.imageBase ?? 0x8000;
    const imageEnd = imageBase + (target.imageCapacity ?? 0x1000);
    const writableBase = target.writableBase ?? 0x4000;
    const writableEnd = writableBase + (target.writableCapacity ?? 0x1000);
    return !(writableBase >= imageBase && writableEnd <= imageEnd);
};
const prepareTarget = (memory, partBanks, target) => {
    const imageBase = target.imageBase ?? 0x8000;
    const imageCapacity = target.imageCapacity ?? 0x1000;
    const writableBase = target.writableBase ?? 0x4000;
    const writableCapacity = target.writableCapacity ?? 0x1000;
    for (const [name, value] of [
        ["image base", imageBase],
        ["image capacity", imageCapacity],
        ["writable base", writableBase],
        ["writable capacity", writableCapacity],
    ]) {
        requireWord(name, value);
    }
    const imageFill = target.imageFill ?? 0xff;
    if (!Number.isInteger(imageFill) || imageFill < 0 || imageFill > 0xff) {
        throw new RangeError("Nucleus target image fill is outside 0..255");
    }
    memory.fill(0, TARGET_DESCRIPTOR, TARGET_DESCRIPTOR + TARGET_DESCRIPTOR_SIZE);
    writeWord(memory, TARGET_DESCRIPTOR, RUNTIME_IDENTITY);
    writeWord(memory, TARGET_DESCRIPTOR + 2, imageBase);
    writeWord(memory, TARGET_DESCRIPTOR + 4, imageCapacity);
    writeWord(memory, TARGET_DESCRIPTOR + 6, writableBase);
    writeWord(memory, TARGET_DESCRIPTOR + 8, writableCapacity);
    memory[TARGET_DESCRIPTOR + 10] = target.establishStack === false ? 0 : 1;
    const bankCount = isBankedTarget(target) ? target.bankCount : 1;
    const entryBank = isBankedTarget(target) ? target.entryBank : 0;
    if (!Number.isInteger(bankCount) ||
        bankCount < (isBankedTarget(target) ? 2 : 1) ||
        bankCount > 4) {
        throw new RangeError("Nucleus target bankCount is outside its supported range");
    }
    if (!Number.isInteger(entryBank) || entryBank < 0 || entryBank >= bankCount) {
        throw new RangeError("Nucleus target entryBank is outside the bank count");
    }
    for (const bank of partBanks) {
        if (!Number.isInteger(bank) || bank < 0 || bank >= bankCount) {
            throw new RangeError("Nucleus source part bank is outside the bank count");
        }
    }
    memory[TARGET_DESCRIPTOR + 11] = bankCount;
    memory[TARGET_DESCRIPTOR + 12] = entryBank;
    writeWord(memory, TARGET_DESCRIPTOR + 13, PART_BANKS);
    memory.set(partBanks, PART_BANKS);
    return {
        banked: bankCount > 1,
        runtimeIdentity: RUNTIME_IDENTITY,
        bankCount,
        imageFill,
        imageBase,
        imageCapacity,
    };
};
const capturedMap = (memory, base, romMode, establishStack, partBanks) => ({
    romMode,
    establishedStack: establishStack,
    entryBank: memory[base] ?? 0,
    entryAddress: readWord(memory, base + 1),
    writableBase: readWord(memory, base + 13),
    writableCapacity: readWord(memory, base + 15),
    vectorBase: readWord(memory, base + 17),
    vectorLength: readWord(memory, base + 19),
    initializedRunBase: readWord(memory, base + 21),
    initializedRunLength: readWord(memory, base + 23),
    bssBase: readWord(memory, base + 25),
    bssLength: readWord(memory, base + 27),
    stackRequirement: readWord(memory, base + 29),
    dataLoadBank: memory[base + 31] ?? 0,
    dataLoadAddress: readWord(memory, base + 32),
    dataLoadLength: readWord(memory, base + 34),
    partBanks,
    banks: [
        {
            usedLength: readWord(memory, base + 3),
            readOnlyBase: readWord(memory, base + 5),
            readOnlyLength: readWord(memory, base + 7),
            aggregateConstantBase: readWord(memory, base + 36),
            aggregateConstantLength: readWord(memory, base + 38),
        },
    ],
});
const capturedContext = (memory, base, services) => ({
    runtimeBase: readWord(memory, base),
    writableBase: readWord(memory, base + 2),
    writableCapacity: readWord(memory, base + 4),
    writableStateBase: readWord(memory, base + 6),
    vectorBase: readWord(memory, base + 8),
    programDataBase: readWord(memory, base + 10),
    programDataCapacity: readWord(memory, base + 12),
    readOnlyBase: readWord(memory, base + 14),
    readOnlyCapacity: readWord(memory, base + 16),
    services,
});
const capturedBankedMap = (memory, symbols, begin, target, partBanks) => {
    const address = (name) => symbol(symbols, name);
    const startupLength = readWord(memory, address("TargetStartupLength"));
    const staticLength = readWord(memory, address("StaticImageLength"));
    const vectorLength = address("NucleusRuntimeVectorLength");
    const stateLength = address("NucleusRuntimeStateLength");
    const runtimeLength = address("NucleusRuntimeExpectedLength");
    const initializedLength = vectorLength + stateLength + staticLength;
    const cursors = address("AdapterCapturedBankCursors");
    const remaining = address("AdapterCapturedBankRemaining");
    const roLengths = address("AdapterCapturedBankRoLengths");
    const banks = Array.from({ length: target.bankCount }, (_, bank) => {
        const cursor = readWord(memory, cursors + bank * 2);
        const bankRemaining = readWord(memory, remaining + bank * 2);
        if (cursor - begin.imageBase + bankRemaining !== begin.imageCapacity) {
            throw new Error(`Nucleus bank ${bank} cursor/capacity state is inconsistent`);
        }
        const aggregateLength = readWord(memory, roLengths + bank * 2);
        let aggregateConstantBase = begin.imageBase + 3 + runtimeLength;
        if (bank === target.entryBank) {
            aggregateConstantBase += startupLength + initializedLength;
        }
        const entryReadOnlyBase = bank === target.entryBank
            ? begin.imageBase + 3 + runtimeLength + startupLength
            : 0;
        return {
            usedLength: cursor - begin.imageBase,
            readOnlyBase: bank === target.entryBank
                ? entryReadOnlyBase
                : aggregateLength === 0
                    ? 0
                    : aggregateConstantBase,
            readOnlyLength: (bank === target.entryBank ? initializedLength : 0) + aggregateLength,
            aggregateConstantBase: aggregateLength === 0 ? 0 : aggregateConstantBase,
            aggregateConstantLength: aggregateLength,
        };
    });
    return {
        romMode: true,
        establishedStack: target.establishStack !== false,
        entryBank: target.entryBank,
        entryAddress: begin.imageBase,
        writableBase: target.writableBase ?? 0x4000,
        writableCapacity: target.writableCapacity ?? 0x1000,
        vectorBase: target.writableBase ?? 0x4000,
        vectorLength,
        initializedRunBase: target.writableBase ?? 0x4000,
        initializedRunLength: initializedLength,
        bssBase: readWord(memory, address("TargetBssBase")),
        bssLength: readWord(memory, address("ProgramBssLength")),
        stackRequirement: address("TargetStackRequirement"),
        dataLoadBank: target.entryBank,
        dataLoadAddress: banks[target.entryBank]?.readOnlyBase ?? 0,
        dataLoadLength: initializedLength,
        partBanks,
        banks,
    };
};
export const compileNucleus = async (parts, target = {}, options = {}) => {
    const debugHooks = options.debugMap === true;
    const image = await loadCompilerImage(debugHooks);
    let debugCollectionActive = debugHooks;
    let collector;
    const runtime = createZ80Runtime({ ...image.program, memory: image.program.memory.slice() }, symbol(image.symbols, "CompileTargetAggregateCallParts"), {
        write: (port, value) => {
            if (debugCollectionActive && isNucleusDebugPort(port & 0xff)) {
                collector?.collect(port & 0xff, runtime.cpu);
                return;
            }
            options.compilerIoWrite?.(port, value);
        },
    });
    const memory = runtime.hardware.memory;
    const sourceBase = symbol(image.symbols, "SourceBase");
    const sourceLimit = symbol(image.symbols, "SourceLimit");
    const prepared = prepareSource(memory, parts, sourceBase, sourceLimit, isBankedTarget(target) ? target.partBanks : undefined);
    const partBanks = prepared.partBanks;
    const begin = prepareTarget(memory, partBanks, target);
    if (debugHooks) {
        const traceSymbols = {
            sourcePartId: symbol(image.symbols, "SourcePartId"),
            tokenStartOffset: symbol(image.symbols, "TokenStartOffset"),
            tokenStartLine: symbol(image.symbols, "TokenStartLine"),
            tokenStartColumn: symbol(image.symbols, "TokenStartColumn"),
            sinkCursor: symbol(image.symbols, "SinkCursor"),
            semanticPayloadBase: symbol(image.symbols, "SemanticPayloadBase"),
            semanticReadCursor: symbol(image.symbols, "SemanticReadCursor"),
            declarationNamePointer: symbol(image.symbols, "DeclarationNamePointer"),
            declarationNameLength: symbol(image.symbols, "DeclarationNameLength"),
            stage7CurrentRoutine: symbol(image.symbols, "Stage7CurrentRoutine"),
            stage7RoutineTableBase: symbol(image.symbols, "Stage7RoutineTableBase"),
            stage7RoutineEntrySize: symbol(image.symbols, "Stage7RoutineEntrySize"),
        };
        collector = new NucleusDebugCollector(memory, prepared.loaded, traceSymbols);
    }
    const adapterBase = symbol(image.symbols, "AdapterLogBase");
    writeWord(memory, symbol(image.symbols, "AdapterCursor"), adapterBase);
    for (const name of [
        "AdapterOpen",
        "AdapterCommitted",
        "AdapterAborted",
        "AdapterFailureCountdown",
        "AdapterMapFailure",
        "AdapterCommitFailure",
    ]) {
        memory[symbol(image.symbols, name)] = 0;
    }
    memory[RETURN_SENTINEL] = 0x76;
    writeWord(memory, STACK_TOP, RETURN_SENTINEL);
    runtime.cpu.sp = STACK_TOP;
    runtime.cpu.pc = symbol(image.symbols, "CompileTargetAggregateCallParts");
    runtime.cpu.a = parts.length;
    runtime.cpu.h = sourceBase >>> 8;
    runtime.cpu.l = sourceBase & 0xff;
    runtime.cpu.ix = TARGET_DESCRIPTOR;
    runtime.cpu.halted = false;
    let instructions = 0;
    let cycles = 0;
    try {
        while (!runtime.isHalted()) {
            if (instructions >= DEFAULT_INSTRUCTION_LIMIT ||
                cycles >= DEFAULT_CYCLE_LIMIT) {
                throw new Error("Nucleus compiler exceeded its host execution limit");
            }
            const step = runtime.step();
            instructions += 1;
            cycles += step.cycles ?? 0;
        }
    }
    finally {
        debugCollectionActive = false;
    }
    if (runtime.cpu.flags.C !== 0) {
        const part = memory[symbol(image.symbols, "DiagnosticPartId")] ?? 0;
        return {
            success: false,
            diagnostic: {
                code: memory[symbol(image.symbols, "DiagnosticCode")] ?? 0,
                sourcePart: part,
                sourceName: parts[part - 1]?.name,
                offset: readWord(memory, symbol(image.symbols, "DiagnosticOffset")),
                line: readWord(memory, symbol(image.symbols, "DiagnosticLine")),
                column: readWord(memory, symbol(image.symbols, "DiagnosticColumn")),
            },
            instructions,
            cycles,
        };
    }
    if ((memory[symbol(image.symbols, "AdapterCommitted")] ?? 0) !== 1) {
        throw new Error("Nucleus compiler returned success without committing output");
    }
    const cursor = readWord(memory, symbol(image.symbols, "AdapterCursor"));
    const map = isBankedTarget(target)
        ? capturedBankedMap(memory, image.symbols, begin, target, partBanks)
        : capturedMap(memory, symbol(image.symbols, "AdapterCapturedMap"), flatTargetUsesRomMode(target), target.establishStack !== false, partBanks);
    const runtimeLinkContext = capturedContext(memory, symbol(image.symbols, "AdapterCapturedContext"), target.services ?? defaultNucleusServices);
    const adapterImages = collector === undefined ? undefined : [];
    const nobj = await commitNobjAdapterGeneration({
        name: "nucleus-host-compile",
        producerMemory: memory,
        start: adapterBase,
        length: cursor - adapterBase,
        maxBytes: symbol(image.symbols, "AdapterLogLimit") - adapterBase,
        begin,
        map,
        runtimeLinkContext,
        ...(adapterImages === undefined
            ? {}
            : {
                onImageByte: (imageByte) => adapterImages.push(imageByte),
            }),
    });
    const parsed = parseNobj(nobj);
    const debugMapping = collector?.finish(parsed, begin, adapterImages ?? []);
    return {
        success: true,
        nobj,
        materialized: materializeNobj(parsed),
        ...(debugMapping === undefined ? {} : { debugMapping }),
        instructions,
        cycles,
    };
};

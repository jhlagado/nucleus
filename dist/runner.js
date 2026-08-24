import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { defaultNucleusServices, } from "./compiler.js";
import { assertNucleusTarget } from "./configuration.js";
import { nodeNobjRunnerHex, nodeNobjRunnerSymbols, } from "./generated-node-runner.js";
const DEFAULT_INSTRUCTION_LIMIT = 5000000;
const DEFAULT_CYCLE_LIMIT = 50000000;
const LOADER_BASE_INSTRUCTION_LIMIT = 250000;
const LOADER_INSTRUCTIONS_PER_OBJECT_BYTE = 512;
const LOADER_BASE_CYCLE_LIMIT = 2000000;
const LOADER_CYCLES_PER_OBJECT_BYTE = 5000;
const RUNTIME_VECTOR_LENGTH = 36;
const address = (name) => {
    const value = nodeNobjRunnerSymbols[name];
    if (value === undefined)
        throw new Error(`Node NOBJ runner omits ${name}`);
    return value;
};
const writeWord = (memory, at, value) => {
    memory[at] = value & 0xff;
    memory[at + 1] = value >>> 8;
};
const word = (high, low) => (high << 8) | low;
const wordAt = (memory, at) => word(memory[at + 1], memory[at]);
const sameServices = (target) => {
    const services = target.services ?? defaultNucleusServices;
    return Object.entries(defaultNucleusServices).every(([name, value]) => services[name] === value);
};
/**
 * Load one committed NOBJ with the standalone Z80 consumer, then execute
 * it through the Node reference program-service adapter.
 */
export const runNucleusNobj = (object, target = {}, options = {}) => {
    target = assertNucleusTarget(target);
    if (target.establishStack === false) {
        throw new Error("the Node NOBJ runner requires an established target stack");
    }
    if (!sameServices(target)) {
        throw new Error("the Node NOBJ runner requires the standard Node service addresses");
    }
    const imageBase = target.imageBase ?? 0x8000;
    const imageCapacity = target.imageCapacity ?? 0x1000;
    const writableBase = target.writableBase ?? 0x4000;
    const writableCapacity = target.writableCapacity ?? 0x1000;
    const imageFill = target.imageFill ?? 0xff;
    const bankCount = "bankCount" in target ? target.bankCount : 1;
    const entryBank = "entryBank" in target ? target.entryBank : 0;
    if (bankCount < 1 || bankCount > 4 || entryBank < 0 || entryBank >= bankCount) {
        throw new Error("the Node NOBJ runner received an invalid bank profile");
    }
    const descriptor = address("NobjConsumerControlBase");
    const profile = descriptor + 0x10;
    const result = descriptor + 0x30;
    const bankBindings = result + 0x10;
    const objectSelector = 1;
    const initial = parseIntelHex(nodeNobjRunnerHex);
    const memory = initial.memory.slice();
    memory.set([10, 0, 1, 0], descriptor);
    writeWord(memory, descriptor + 4, objectSelector);
    writeWord(memory, descriptor + 6, profile);
    writeWord(memory, descriptor + 8, result);
    memory.set([18, 1, 2 | (bankCount > 1 ? 1 : 0)], profile);
    writeWord(memory, profile + 3, 10);
    memory[profile + 5] = bankCount;
    memory[profile + 6] = imageFill;
    writeWord(memory, profile + 7, imageBase);
    writeWord(memory, profile + 9, imageCapacity);
    writeWord(memory, profile + 11, writableBase);
    writeWord(memory, profile + 13, writableCapacity);
    memory[profile + 15] = entryBank;
    writeWord(memory, profile + 16, bankCount > 1 ? bankBindings : 0);
    for (let bank = 0; bank < bankCount; bank += 1) {
        const binding = bankBindings + bank * 6;
        memory[binding] = bank;
        memory[binding + 1] = 0;
        const deviceOffset = bank * imageCapacity;
        memory[binding + 2] = deviceOffset & 0xff;
        memory[binding + 3] = (deviceOffset >>> 8) & 0xff;
        memory[binding + 4] = (deviceOffset >>> 16) & 0xff;
        memory[binding + 5] = (deviceOffset >>> 24) & 0xff;
    }
    memory.fill(0xa5, result, result + 4);
    const input = Uint8Array.from(options.input ?? []);
    const storageInput = Uint8Array.from(options.storageInput ?? []);
    const output = [];
    const storageOutput = Array.from(options.storageOutput ?? []);
    let inputCursor = 0;
    let storageInputCursor = 0;
    let storageOutputCursor = storageOutput.length;
    let objectCursor = 0;
    let objectOpen = false;
    let published = false;
    let entered;
    let terminal;
    let activeRuntime;
    let programRunning = false;
    let selectedBank;
    const bankImages = Array.from({ length: bankCount }, () => new Uint8Array(imageCapacity).fill(imageFill));
    const runtimeStateBase = writableBase + RUNTIME_VECTOR_LENGTH;
    const storeSelectedBank = (live) => {
        if (selectedBank === undefined)
            return;
        bankImages[selectedBank].set(live.subarray(imageBase, imageBase + imageCapacity));
    };
    const selectTargetBank = (bank) => {
        if (bank < 0 || bank >= bankCount)
            return false;
        const live = activeRuntime.hardware.memory;
        if (selectedBank !== bank) {
            storeSelectedBank(live);
            live.set(bankImages[bank], imageBase);
            selectedBank = bank;
        }
        return true;
    };
    const atMon3Gateway = () => activeRuntime.getPC() === ((address("NodeMon3Gateway") + 1) & 0xffff);
    const succeed = () => {
        activeRuntime.cpu.flags.C = 0;
    };
    const fail = (status) => {
        activeRuntime.cpu.a = status;
        activeRuntime.cpu.flags.C = 1;
    };
    const readByte = (bytes, cursor) => cursor < bytes.length ? bytes[cursor] : undefined;
    const onWrite = (port, value) => {
        const cpu = activeRuntime.cpu;
        const hl = word(cpu.h, cpu.l);
        if ((port & 0xff) !== address("NodeMon3GatewayPort") ||
            !atMon3Gateway()) {
            options.ioWrite?.(port, value);
            return;
        }
        switch (cpu.c) {
            case address("NucleusServiceLoaderOpen"):
                if (hl !== objectSelector || objectOpen)
                    fail(2);
                else {
                    objectOpen = true;
                    objectCursor = 0;
                    succeed();
                }
                return;
            case address("NucleusServiceLoaderReadByte"): {
                const next = objectOpen ? readByte(object, objectCursor) : undefined;
                if (next === undefined)
                    fail(objectOpen ? 1 : 2);
                else {
                    objectCursor += 1;
                    cpu.a = next;
                    succeed();
                }
                return;
            }
            case address("NucleusServiceLoaderRewind"):
                fail(2);
                return;
            case address("NucleusServiceLoaderLock"):
                fail(2);
                return;
            case address("NucleusMonBankSelect"):
                if ((!programRunning && cpu.ix !== profile) ||
                    !selectTargetBank(value))
                    fail(2);
                else
                    succeed();
                return;
            case address("NucleusServiceLoaderPublish"): {
                if (value !== entryBank ||
                    cpu.e !== (profile & 0xff) ||
                    cpu.d !== profile >>> 8) {
                    fail(2);
                }
                else {
                    published = true;
                    succeed();
                }
                return;
            }
            case address("NucleusServiceLoaderEnter"):
                if (!published ||
                    value !== entryBank ||
                    cpu.ix !== profile ||
                    !selectTargetBank(value)) {
                    fail(2);
                }
                else {
                    entered = hl;
                    succeed();
                }
                return;
            case address("NucleusServiceLoaderClose"):
                objectOpen = false;
                succeed();
                return;
            case address("NucleusServicePlatformInfo"):
                cpu.a = 1;
                cpu.d = 0;
                cpu.e = 0x0f;
                succeed();
                return;
            case address("NucleusServiceReadInput"): {
                const buffered = readByte(input, inputCursor);
                const next = buffered ?? options.readInput?.();
                if (next === undefined)
                    fail(1);
                else {
                    if (buffered !== undefined)
                        inputCursor += 1;
                    cpu.a = next & 0xff;
                    succeed();
                }
                return;
            }
            case address("NucleusServiceWriteOutput"):
                output.push(value);
                options.writeOutput?.(value);
                succeed();
                return;
            case address("NucleusServiceReadStorage"): {
                const next = readByte(storageInput, storageInputCursor);
                if (next === undefined)
                    fail(1);
                else {
                    storageInputCursor += 1;
                    cpu.a = next;
                    succeed();
                }
                return;
            }
            case address("NucleusServiceRewindStorage"):
                storageInputCursor = 0;
                succeed();
                return;
            case address("NucleusServiceWriteStorage"):
                if (storageOutputCursor > storageOutput.length)
                    fail(4);
                else {
                    storageOutput[storageOutputCursor] = value;
                    storageOutputCursor += 1;
                    succeed();
                }
                return;
            case address("NucleusServiceSeekStorage"):
                if (hl > storageOutput.length)
                    fail(4);
                else {
                    storageOutputCursor = hl;
                    succeed();
                }
                return;
            case address("NucleusServiceExitSuccess"):
                terminal = "success";
                return;
            case address("NucleusServiceExitFailure"):
                terminal = "unhandledFailure";
                return;
            case address("NucleusServiceExitTrap"):
                terminal = "trap";
                return;
            case address("NucleusServicePacket"): {
                const handler = options.packetService;
                const inputBc = wordAt(activeRuntime.hardware.memory, address("NodeProgramInputBC"));
                if (handler === undefined || hl + inputBc > 0x10000) {
                    fail(7);
                    return;
                }
                const status = handler(value, activeRuntime.hardware.memory.subarray(hl, hl + inputBc));
                if (status === undefined || status === 0)
                    succeed();
                else
                    fail(status);
                return;
            }
            default:
                fail(0xee);
                return;
        }
    };
    const onRead = (port) => options.ioRead?.(port) ?? 0;
    const loader = createZ80Runtime({ memory, startAddress: address("NobjConsumerRun") }, address("NobjConsumerRun"), { read: onRead, write: onWrite });
    activeRuntime = loader;
    const loaderStack = address("NobjConsumerStackLimit") - 2;
    writeWord(loader.hardware.memory, loaderStack, address("NodeNobjReturnSentinel"));
    loader.cpu.sp = loaderStack;
    loader.cpu.ix = descriptor;
    const loaderInstructionLimit = LOADER_BASE_INSTRUCTION_LIMIT +
        object.length * LOADER_INSTRUCTIONS_PER_OBJECT_BYTE;
    const loaderCycleLimit = LOADER_BASE_CYCLE_LIMIT + object.length * LOADER_CYCLES_PER_OBJECT_BYTE;
    let loaderInstructions = 0;
    let loaderCycles = 0;
    while (entered === undefined &&
        !loader.isHalted() &&
        loaderInstructions < loaderInstructionLimit &&
        loaderCycles <= loaderCycleLimit) {
        const step = loader.step();
        loaderInstructions += 1;
        loaderCycles += step.cycles ?? 0;
    }
    const loadedMemory = loader.hardware.memory;
    let programInstructions = 0;
    let programCycles = 0;
    const common = (live) => {
        storeSelectedBank(live);
        return {
            instructions: loaderInstructions + programInstructions,
            cycles: loaderCycles + programCycles,
            loaderInstructions,
            loaderCycles,
            programInstructions,
            programCycles,
            output: Uint8Array.from(output),
            storageOutput: Uint8Array.from(storageOutput),
            memory: live.slice(),
            ...(bankCount === 1
                ? {}
                : { banks: bankImages.map((bank) => bank.slice()) }),
        };
    };
    if (entered === undefined) {
        if (loaderInstructions >= loaderInstructionLimit ||
            loaderCycles > loaderCycleLimit) {
            return {
                success: false,
                outcome: "executionLimit",
                phase: "loader",
                programCounter: loader.getPC(),
                ...common(loadedMemory),
            };
        }
        return {
            success: false,
            outcome: "loaderFailure",
            loaderOutcome: loadedMemory[result] ?? 0,
            status: loadedMemory[result + 1] ?? 0,
            recordOrdinal: word(loadedMemory[result + 3] ?? 0, loadedMemory[result + 2] ?? 0),
            ...common(loadedMemory),
        };
    }
    storeSelectedBank(loadedMemory);
    writeWord(loadedMemory, address("NodeProgramRuntimeStateBase"), runtimeStateBase);
    const imageEnd = imageBase + imageCapacity;
    const writableEnd = writableBase + writableCapacity;
    const romMode = bankCount > 1 || writableBase >= imageEnd || writableEnd <= imageBase;
    const program = createZ80Runtime({ memory: loadedMemory, startAddress: entered }, entered, { read: onRead, write: onWrite }, romMode
        ? { romRanges: [{ start: imageBase, end: imageEnd - 1 }] }
        : undefined);
    activeRuntime = program;
    programRunning = true;
    const maxInstructions = options.maxInstructions ?? DEFAULT_INSTRUCTION_LIMIT;
    const maxCycles = options.maxCycles ?? DEFAULT_CYCLE_LIMIT;
    while (terminal === undefined &&
        !program.isHalted() &&
        programInstructions < maxInstructions &&
        programCycles <= maxCycles) {
        const step = program.step();
        programInstructions += 1;
        programCycles += step.cycles ?? 0;
    }
    const live = program.hardware.memory;
    if (terminal === undefined) {
        return {
            success: false,
            outcome: "executionLimit",
            phase: "program",
            programCounter: program.getPC(),
            ...common(live),
        };
    }
    if (terminal === "success") {
        return { success: true, outcome: "success", ...common(live) };
    }
    const state = runtimeStateBase;
    return {
        success: false,
        outcome: terminal,
        trapReason: live[state + 1] ?? 0,
        trapOffset: word(live[state + 4] ?? 0, live[state + 3] ?? 0),
        errorCode: live[state + 5] ?? 0,
        ...common(live),
    };
};

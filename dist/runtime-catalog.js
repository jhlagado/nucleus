import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { generatedRuntimeCatalog } from "./generated-runtime-catalog.js";
import { NobjError, } from "./nobj.js";
const serviceOrder = [
    "readInputByte",
    "writeOutputByte",
    "readStorageByte",
    "rewindStorageInput",
    "writeStorageByte",
    "seekStorageOutput",
    "success",
    "unhandledFailure",
    "trap",
    "farCall",
    "farJump",
    "packetService",
];
const runtimeVectorLength = serviceOrder.length * 3;
const runtimeStateLength = 41;
const runtimeProgramDataBaseOffset = 37;
const runtimeProgramDataCapacityOffset = 39;
const checkedWord = (name, value) => {
    if (!Number.isInteger(value) || value < 0 || value > 0xffff) {
        throw new NobjError(`${name} is outside 0..65535`);
    }
};
const checkedRegion = (name, base, capacity, allowEmpty = false) => {
    checkedWord(`${name} base`, base);
    checkedWord(`${name} capacity`, capacity);
    if (!allowEmpty && capacity === 0) {
        throw new NobjError(`${name} capacity is zero`);
    }
    if (base + capacity > 0x10000) {
        throw new NobjError(`${name} crosses the Z80 address space`);
    }
};
/** Validate the addresses that select and initialize a linked runtime image. */
export const validateRuntimeLinkContext = (context) => {
    checkedWord("runtime base", context.runtimeBase);
    checkedRegion("writable", context.writableBase, context.writableCapacity);
    checkedWord("writable state base", context.writableStateBase);
    checkedWord("vector base", context.vectorBase);
    checkedRegion("program data", context.programDataBase, context.programDataCapacity, true);
    checkedRegion("read-only data", context.readOnlyBase, context.readOnlyCapacity, true);
    const writableEnd = context.writableBase + context.writableCapacity;
    const vectorEnd = context.vectorBase + runtimeVectorLength;
    if (context.writableStateBase < context.writableBase ||
        context.writableStateBase >= writableEnd) {
        throw new NobjError("writable state base is outside writable storage");
    }
    if (context.vectorBase < context.writableBase || vectorEnd > writableEnd) {
        throw new NobjError("vector table is outside writable storage");
    }
    if (context.vectorBase !== context.writableBase) {
        throw new NobjError("runtime vector base differs from writable base");
    }
    if (context.writableStateBase !== context.vectorBase + runtimeVectorLength) {
        throw new NobjError("runtime state does not follow the vector table");
    }
    if (context.programDataBase !==
        context.writableStateBase + runtimeStateLength) {
        throw new NobjError("program data does not follow runtime state");
    }
    if (context.programDataBase + context.programDataCapacity > writableEnd) {
        throw new NobjError("program data exceeds writable storage");
    }
    for (const service of serviceOrder) {
        checkedWord(`${service} service address`, context.services[service]);
    }
};
const executableContextKey = (identity, runtimeBase, writableStateBase, packetService) => JSON.stringify([identity, runtimeBase, writableStateBase, packetService]);
const vectorBytes = (services, packetServiceGateway) => {
    const bytes = new Uint8Array(runtimeVectorLength);
    serviceOrder.forEach((name, index) => {
        const address = name === "packetService" ? packetServiceGateway : services[name];
        bytes[index * 3] = 0xc3;
        bytes[index * 3 + 1] = address & 0xff;
        bytes[index * 3 + 2] = address >>> 8;
    });
    return bytes;
};
const catalogImage = (entry) => {
    if (entry.vectorLength !== runtimeVectorLength ||
        entry.stateLength !== runtimeStateLength ||
        entry.programDataBaseOffset !== runtimeProgramDataBaseOffset ||
        entry.programDataCapacityOffset !== runtimeProgramDataCapacityOffset) {
        throw new NobjError(`generated runtime catalog entry ${entry.name} is invalid`);
    }
    const state = new Uint8Array(runtimeStateLength);
    state[entry.runStateOffset] = entry.runReady;
    state[entry.activationLimitOffset] = entry.activationCapacity;
    return {
        identity: entry.identity,
        bytes: parseIntelHex(entry.hex).memory.slice(entry.runtimeBase, entry.runtimeBase + entry.expectedLength),
        initialBytes: Uint8Array.from([
            ...new Uint8Array(runtimeVectorLength),
            ...state,
        ]),
        vectorBytes: new Uint8Array(runtimeVectorLength),
        helperOffsets: { ...entry.helperOffsets },
        currentBankOffset: entry.currentBankOffset,
    };
};
const images = new Map();
for (const entry of generatedRuntimeCatalog) {
    const image = catalogImage(entry);
    images.set(executableContextKey(image.identity, entry.runtimeBase, entry.stateBase, entry.packetService), image);
}
/** Pre-linked runtime images shipped with the Node harness. */
export const bundledRuntimeProvider = {
    get(identity, context) {
        validateRuntimeLinkContext(context);
        const image = images.get(executableContextKey(identity, context.runtimeBase, context.writableStateBase, context.services.packetService));
        if (image === undefined)
            return undefined;
        const packetServiceGateway = image.helperOffsets?.PacketServiceGateway;
        if (packetServiceGateway === undefined) {
            throw new NobjError("runtime catalog entry omits PacketServiceGateway");
        }
        const vectors = vectorBytes(context.services, context.runtimeBase + packetServiceGateway);
        const state = image.initialBytes.slice(runtimeVectorLength);
        state[runtimeProgramDataBaseOffset] = context.programDataBase & 0xff;
        state[runtimeProgramDataBaseOffset + 1] =
            context.programDataBase >>> 8;
        state[runtimeProgramDataCapacityOffset] =
            context.programDataCapacity & 0xff;
        state[runtimeProgramDataCapacityOffset + 1] =
            context.programDataCapacity >>> 8;
        return {
            ...image,
            bytes: image.bytes.slice(),
            initialBytes: Uint8Array.from([...vectors, ...state]),
            vectorBytes: vectors,
            helperOffsets: image.helperOffsets === undefined
                ? undefined
                : { ...image.helperOffsets },
        };
    },
};
/** Runtime placements pre-linked into the published Node package. */
export const bundledRuntimeCatalog = generatedRuntimeCatalog.map(({ name, runtimeBase, stateBase, packetService }) => ({
    name,
    runtimeBase,
    writableStateBase: stateBase,
    packetService,
}));

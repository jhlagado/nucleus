import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { nativeImportResolverHex, nativeImportResolverSymbols, } from "./generated-native-import-resolver.js";
import { NucleusSystemStatus, } from "./object-services.js";
const symbol = (name) => {
    const value = nativeImportResolverSymbols[name];
    if (value === undefined) {
        throw new Error(`native import resolver omitted symbol ${name}`);
    }
    return value;
};
/**
 * Execute the prebuilt Z80 import resolver over named-object services.
 *
 * This is the Node platform binding beneath a genuine Z80 tool. It performs no
 * import parsing, dependency ordering, or SP1 serialization in TypeScript.
 */
export const runNativeImportResolver = (services, entry) => {
    const entryBytes = Buffer.from(entry, "ascii");
    if (entryBytes.length < 1 ||
        entryBytes.length > 0xff ||
        entryBytes.some((byte) => byte < 0x20 || byte > 0x7e)) {
        return {
            success: false,
            status: NucleusSystemStatus.invalid,
            instructions: 0,
        };
    }
    const memory = parseIntelHex(nativeImportResolverHex).memory;
    const gateway = 0x0010;
    const gatewayPort = 0xe1;
    const entryAt = 0x7d00;
    const returnAt = 0x7dff;
    const stackAt = 0x7f00;
    memory[gateway] = 0xd3; // OUT (n),A
    memory[gateway + 1] = gatewayPort;
    memory[gateway + 2] = 0xc9; // RET
    memory.set(entryBytes, entryAt);
    memory[returnAt] = 0x76; // HALT
    let runtime;
    runtime = createZ80Runtime({ memory, startAddress: symbol("NativeImportResolve") }, symbol("NativeImportResolve"), {
        write: (port) => {
            if ((port & 0xff) !== gatewayPort) {
                throw new Error(`native import resolver wrote unexpected port ${port & 0xff}`);
            }
            if (runtime.cpu.c !== symbol("NucleusServiceObject")) {
                throw new Error(`native import resolver requested unexpected service ${runtime.cpu.c}`);
            }
            const request = (runtime.cpu.h << 8) | runtime.cpu.l;
            const status = services.dispatch(runtime.hardware.memory, request);
            runtime.cpu.a = status;
            runtime.cpu.flags.C =
                status === NucleusSystemStatus.success ? 0 : 1;
        },
    });
    runtime.hardware.memory[stackAt] = returnAt & 0xff;
    runtime.hardware.memory[stackAt + 1] = returnAt >>> 8;
    runtime.cpu.sp = stackAt;
    runtime.cpu.h = entryAt >>> 8;
    runtime.cpu.l = entryAt & 0xff;
    runtime.cpu.b = entryBytes.length;
    let instructions = 0;
    const instructionLimit = 2000000;
    try {
        while (!runtime.isHalted() && instructions < instructionLimit) {
            runtime.step();
            instructions += 1;
        }
    }
    catch (error) {
        services.abortAll();
        throw error;
    }
    if (!runtime.isHalted()) {
        services.abortAll();
        throw new Error("native import resolver exceeded its instruction limit");
    }
    if (runtime.cpu.sp !== stackAt + 2) {
        services.abortAll();
        throw new Error("native import resolver returned with an unbalanced stack");
    }
    const status = runtime.cpu.a;
    const success = runtime.cpu.flags.C === 0 && status === NucleusSystemStatus.success;
    if (!success)
        services.abortAll();
    return {
        success,
        status,
        instructions,
    };
};

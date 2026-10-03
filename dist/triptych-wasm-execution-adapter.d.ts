import type { NucleusExecutionAdapter } from "./execution-adapter.js";
/** The subset of TriptychCpu needed by the Nucleus compiler host. */
export interface TriptychWasmCpuState {
    a(): number;
    b(): number;
    c(): number;
    d(): number;
    e(): number;
    h(): number;
    l(): number;
    ix(): number;
    iy(): number;
    sp(): number;
    pc(): number;
    halted(): boolean;
    flags(): TriptychWasmFlags;
}
export interface TriptychWasmFlags {
    s(): boolean;
    z(): boolean;
    y(): boolean;
    h(): boolean;
    x(): boolean;
    p(): boolean;
    n(): boolean;
    c(): boolean;
}
export interface TriptychWasmCpu {
    new (bootRom: Uint8Array): TriptychWasmCpu;
    disable_boot_rom_for_execution(): void;
    write_ram(address: number, bytes: Uint8Array): void;
    read_ram(address: number, length: number): Uint8Array;
    cpu_state(): TriptychWasmCpuState;
    set_execution_cpu_field(field: string, value: number): void;
    set_io_trace_enabled(enabled: boolean): void;
    take_io_trace(): readonly number[];
    step(maskableInterrupt: boolean): number;
}
export interface CreateTriptychWasmExecutionAdapterOptions {
    readonly TriptychCpu: TriptychWasmCpu;
    readonly bootRom?: Uint8Array;
}
/** Create the Nucleus execution seam backed by a caller-supplied Triptych WASM CPU. */
export declare const createTriptychWasmExecutionAdapter: ({ TriptychCpu, bootRom, }: CreateTriptychWasmExecutionAdapterOptions) => NucleusExecutionAdapter;

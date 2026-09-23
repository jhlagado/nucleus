import type {
  NucleusExecutionAdapter,
  NucleusExecutionCpu,
  NucleusExecutionCreateOptions,
  NucleusExecutionFlags,
  NucleusExecutionImage,
  NucleusExecutionRuntime,
} from "./execution-adapter.js";

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

const HEX_DIGITS = /^[0-9a-fA-F]+$/;

const parseHexByte = (text: string, offset: number): number => {
  const pair = text.slice(offset, offset + 2);
  if (pair.length !== 2 || !HEX_DIGITS.test(pair)) {
    throw new TypeError("invalid Intel HEX byte");
  }
  return Number.parseInt(pair, 16);
};

const parseIntelHex = (hexText: string): NucleusExecutionImage => {
  if (typeof hexText !== "string") {
    throw new TypeError("execution image must be Intel HEX text");
  }
  const memory = new Uint8Array(0x10000);
  const written = new Uint8Array(memory.length);
  let upper = 0;
  let ended = false;
  for (const [lineNumber, rawLine] of hexText.split(/\r?\n/).entries()) {
    const line = rawLine.trim();
    if (line === "") continue;
    if (ended || !line.startsWith(":")) {
      throw new TypeError(`invalid Intel HEX record at line ${lineNumber + 1}`);
    }
    if ((line.length - 1) % 2 !== 0) {
      throw new TypeError(`odd Intel HEX record at line ${lineNumber + 1}`);
    }
    const byteCount = parseHexByte(line, 1);
    const expectedLength = 1 + (byteCount + 5) * 2;
    if (line.length !== expectedLength) {
      throw new TypeError(`invalid Intel HEX length at line ${lineNumber + 1}`);
    }
    let checksum = 0;
    for (let offset = 1; offset < line.length; offset += 2) {
      checksum = (checksum + parseHexByte(line, offset)) & 0xff;
    }
    if (checksum !== 0) {
      throw new TypeError(`invalid Intel HEX checksum at line ${lineNumber + 1}`);
    }
    const address = (parseHexByte(line, 3) << 8) | parseHexByte(line, 5);
    const type = parseHexByte(line, 7);
    const dataStart = 9;
    if (type === 0x00) {
      const start = upper + address;
      if (start + byteCount > memory.length) {
        throw new TypeError(`Intel HEX data crosses 64 KiB at line ${lineNumber + 1}`);
      }
      for (let index = 0; index < byteCount; index += 1) {
        const value = parseHexByte(line, dataStart + index * 2);
        const at = start + index;
        if (written[at] !== 0 && memory[at] !== value) {
          throw new TypeError(`conflicting Intel HEX data at $${at.toString(16)}`);
        }
        memory[at] = value;
        written[at] = 1;
      }
    } else if (type === 0x01) {
      if (byteCount !== 0 || address !== 0) {
        throw new TypeError("invalid Intel HEX end record");
      }
      ended = true;
    } else if (type === 0x02) {
      if (byteCount !== 2) throw new TypeError("invalid Intel HEX segment record");
      upper = ((parseHexByte(line, dataStart) << 8) | parseHexByte(line, dataStart + 2)) << 4;
    } else if (type === 0x04) {
      if (byteCount !== 2) throw new TypeError("invalid Intel HEX linear record");
      upper = ((parseHexByte(line, dataStart) << 8) | parseHexByte(line, dataStart + 2)) << 16;
      if (upper > 0xffff) throw new TypeError("Intel HEX address exceeds Z80 space");
    } else if (type !== 0x03 && type !== 0x05) {
      throw new TypeError(`unsupported Intel HEX record type ${type}`);
    }
  }
  const writeRanges: { start: number; end: number }[] = [];
  let start: number | undefined;
  for (let address = 0; address <= memory.length; address += 1) {
    if (address < memory.length && written[address] !== 0) {
      start ??= address;
    } else if (start !== undefined) {
      writeRanges.push({ start, end: address });
      start = undefined;
    }
  }
  return { memory, startAddress: 0, writeRanges };
};

const stateOf = (machine: TriptychWasmCpu): NucleusExecutionCpu => {
  const state = machine.cpu_state();
  const flags = state.flags();
  const resultFlags: NucleusExecutionFlags = {
    C: flags.c() ? 1 : 0,
  };
  return {
    a: state.a(),
    b: state.b(),
    c: state.c(),
    d: state.d(),
    e: state.e(),
    h: state.h(),
    l: state.l(),
    ix: state.ix(),
    iy: state.iy(),
    sp: state.sp(),
    pc: state.pc(),
    halted: state.halted(),
    flags: resultFlags,
  };
};

const installState = (machine: TriptychWasmCpu, cpu: NucleusExecutionCpu): void => {
  for (const [field, value] of [
    ["a", cpu.a],
    ["b", cpu.b],
    ["c", cpu.c],
    ["d", cpu.d],
    ["e", cpu.e],
    ["h", cpu.h],
    ["l", cpu.l],
    ["ix", cpu.ix],
    ["iy", cpu.iy],
    ["sp", cpu.sp],
    ["pc", cpu.pc],
    ["halted", cpu.halted ? 1 : 0],
    ["f.c", cpu.flags.C ? 1 : 0],
  ] as const) {
    machine.set_execution_cpu_field(field, value);
  }
};

const resetState = (cpu: NucleusExecutionCpu, entry: number): void => {
  cpu.a = 0;
  cpu.b = 0;
  cpu.c = 0;
  cpu.d = 0;
  cpu.e = 0;
  cpu.h = 0;
  cpu.l = 0;
  cpu.ix = 0;
  cpu.iy = 0;
  cpu.sp = 0;
  cpu.pc = entry;
  cpu.halted = false;
  cpu.flags.C = 0;
};

const dispatchWrites = (
  machine: TriptychWasmCpu,
  write: ((port: number, value: number) => void) | undefined,
): void => {
  if (write === undefined) return;
  for (const packed of machine.take_io_trace()) {
    if ((packed & 0x01000000) === 0) continue;
    write((packed >>> 8) & 0xffff, packed & 0xff);
  }
};

/** Create the Nucleus execution seam backed by a caller-supplied Triptych WASM CPU. */
export const createTriptychWasmExecutionAdapter = ({
  TriptychCpu,
  bootRom = new Uint8Array(256),
}: CreateTriptychWasmExecutionAdapterOptions): NucleusExecutionAdapter => {
  if (!(bootRom instanceof Uint8Array) || bootRom.length !== 256) {
    throw new TypeError("bootRom must contain exactly 256 bytes");
  }
  return Object.freeze({
    parseImage: parseIntelHex,
    create({ image, entry, write }: NucleusExecutionCreateOptions): NucleusExecutionRuntime {
      const machine = new TriptychCpu(bootRom);
      machine.disable_boot_rom_for_execution();
      const memory = image.memory.slice();
      machine.write_ram(0, memory);
      machine.set_io_trace_enabled(write !== undefined);
      const cpu = stateOf(machine);
      resetState(cpu, entry);
      installState(machine, cpu);
      return {
        hardware: { memory },
        cpu,
        step() {
          machine.write_ram(0, memory);
          installState(machine, cpu);
          const cycles = machine.step(false);
          memory.set(machine.read_ram(0, 0x10000));
          dispatchWrites(machine, write);
          Object.assign(cpu, stateOf(machine));
          return { cycles };
        },
        isHalted() {
          return cpu.halted;
        },
      };
    },
  });
};

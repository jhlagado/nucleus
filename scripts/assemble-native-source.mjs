// Private Nucleus build boundary. Source is resolved and assembled by ATOM.
// Compatibility names apply only to the returned symbol dictionaries.
import {
  assembleResolvedAtomProject,
  materializeAtomGeneration,
  resolveAtomProject,
  writeAtomD8,
} from "atom-z80";

function sparseHex(generation) {
  const { base, bytes } = materializeAtomGeneration(generation);
  const emitted = new Set();
  for (const image of generation.images) {
    for (let offset = 0; offset < image.bytes.length; offset++) {
      emitted.add(image.address + offset);
    }
  }
  const addresses = [...emitted].sort((a, b) => a - b);
  const records = [];
  const hexByte = value => (value & 0xff).toString(16).toUpperCase().padStart(2, "0");
  for (let index = 0; index < addresses.length;) {
    const start = addresses[index];
    const data = [];
    do {
      data.push(bytes[addresses[index++] - base]);
    } while (data.length < 16 && addresses[index] === start + data.length);
    const record = [data.length, start >>> 8, start & 0xff, 0, ...data];
    record.push(-record.reduce((sum, value) => sum + value, 0) & 0xff);
    records.push(`:${record.map(hexByte).join("")}`);
  }
  return [...records, ":00000001FF", ""].join("\n");
}

export async function assembleNativeSource({
  root,
  entry,
  definitions = {},
  target = { start: 0, capacity: 0xffff },
  exportMap = {},
  requiredExports = [],
}) {
  const exportsByNative = new Map();
  for (const [publicName, nativeName] of Object.entries(exportMap)) {
    if (!publicName || typeof nativeName !== "string" || !nativeName) {
      throw new TypeError("Native source exports require nonempty public and native names");
    }
    const names = exportsByNative.get(nativeName) ?? [];
    names.push(publicName);
    exportsByNative.set(nativeName, names);
  }

  const project = await resolveAtomProject({ root, entry, definitions });
  const result = await assembleResolvedAtomProject(project, {
    target,
    maxInstructions: 1_000_000_000,
    maxCycles: 10_000_000_000,
    nativeMemoryLayout: {
      symbolStart: 0x4100,
      symbolEnd: 0xc000,
      pendingStart: 0xc000,
      pendingEnd: 0xe000,
      partDescriptors: 0xe000,
    },
  });
  const symbols = {};
  const addresses = {};
  for (const symbol of writeAtomD8(project, result.generation).symbols) {
    const mappedNames = exportsByNative.get(symbol.name);
    if (mappedNames === undefined && Object.hasOwn(exportMap, symbol.name)) {
      throw new Error(`Native source export collision: ${symbol.name}`);
    }
    const names = mappedNames ?? [symbol.name];
    for (const name of names) {
      if (Object.hasOwn(symbols, name)) {
        throw new Error(`Native source export collision: ${name}`);
      }
      Object.defineProperty(symbols, name, {
        value: symbol.address ?? symbol.value, enumerable: true,
      });
      if (symbol.address !== undefined) {
        Object.defineProperty(addresses, name, {
          value: symbol.address, enumerable: true,
        });
      }
    }
  }
  for (const name of requiredExports) {
    if (!Object.hasOwn(symbols, name)) {
      throw new Error(`Native source required export is missing: ${name}`);
    }
  }
  return {
    hex: sparseHex(result.generation), symbols, addresses,
    generation: result.generation, project,
    instructions: result.execution.instructions,
  };
}

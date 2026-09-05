// The production NOBJ runner and its executable service/loader proofs share
// canonical ATOM source. These reviewed maps restore output names only.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeSource } from "./assemble-native-source.mjs";

const exportMap = Object.assign({}, ...[
  "nobj", "compiler-proof", "slice-proof", "resolver", "cpm-source", "cpm-adapters",
].map(name => JSON.parse(readFileSync(new URL(`../asm/atom-${name}-symbols.json`, import.meta.url), "utf8"))));

const entries = new Set([
  "node-nobj-consumer.asm",
  "nobj-consumer-flat-proof.asm", "nobj-consumer-banked-proof.asm",
  "nobj-consumer-control-top-proof.asm", "nobj-runner-proof.asm",
  "object-services-node-proof.asm", "runtime-catalog-services-node-proof.asm",
  "platform-services-abi-proof.asm",
]);

export const isNativeNobjEntry = entry => entries.has(entry);

export async function assembleNativeNobj(entry) {
  if (!entries.has(entry)) throw new Error(`Unsupported native NOBJ entry: ${entry}`);
  const result = await assembleNativeSource({
    root: fileURLToPath(new URL("../", import.meta.url)),
    entry: `asm/vertical-slice/${entry}`, exportMap,
    requiredExports: entry === "node-nobj-consumer.asm"
      ? ["NobjConsumerRun", "NodeNobjConsumerCodeStart", "NodeProgramServiceCodeEnd"]
      : ["ProofStart"],
  });
  if (entry !== "nobj-runner-proof.asm") return result;

  // This one host-only extent is 65536, beyond an ATOM word. The authoritative
  // source declares its last address; no instruction may reference this EQU.
  const last = result.generation.symbols.find(symbol => symbol.name === "LPMEMEND");
  if (last?.value !== 0xffff || result.symbols.ProofMemoryEnd !== 0xffff ||
      Object.hasOwn(result.symbols, "LPMEMEND") ||
      Object.hasOwn(result.addresses, "ProofMemoryEnd")) {
    throw new Error("NOBJ proof memory end requires its exact last-address EQU and explicit output mapping");
  }
  if (Object.hasOwn(result.addresses, "LPLOGLEN") ||
      result.symbols.LPLOGLEN !== result.symbols.NobjAdapterEnd - result.symbols.NobjAdapterLog) {
    throw new Error("NOBJ proof log length must be the source-derived private EQU");
  }
  const { LPLOGLEN: privateLogLength, ...symbols } = result.symbols;
  return { ...result, symbols: { ...symbols, ProofMemoryEnd: 0x10000 } };
}

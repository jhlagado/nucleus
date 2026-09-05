// Private image-generator boundary. ATOM is the only production assembler.
import path from "node:path";
import { fileURLToPath } from "node:url";
import { assembleNativeCpmProof } from "./assemble-native-cpm.mjs";
import { assembleNativeImportResolver } from "./assemble-native-import-resolver.mjs";
import { assembleNativeCompiler, isNativeCompilerEntry } from "./assemble-native-compiler.mjs";

const asmRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../asm");

export async function assembleImageSource(source) {
  const entry = path.relative(asmRoot, source).split(path.sep).join("/");
  if (entry === ".." || entry.startsWith("../") || path.isAbsolute(entry)) {
    throw new Error(`Unsupported assembly entry outside the source tree: ${source}`);
  }
  const compilerEntry = entry.startsWith("vertical-slice/") ? entry.slice("vertical-slice/".length) : "";
  const result = isNativeCompilerEntry(compilerEntry)
    ? await assembleNativeCompiler(compilerEntry)
    : entry === "vertical-slice/cpm22-program-provider-proof.asm"
    ? await assembleNativeCpmProof("cpm22-program-provider-proof.asm")
    : entry === "vertical-slice/native-import-resolver-tool.asm"
    ? await assembleNativeImportResolver()
    : await (await import("./atom-source.mjs")).assembleAtomSource(entry);
  return { hex: result.hex, symbols: result.symbols };
}

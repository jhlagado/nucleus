// Private image-generator boundary. ATOM is the only production assembler.
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { assembleAtomSource } from "./atom-source.mjs";

const asmRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../asm");

export async function assembleImageSource(source) {
  let entry = path.relative(asmRoot, source).split(path.sep).join("/");
  const overrides = new Map();
  if (entry.startsWith("../")) {
    // The catalogue generator supplies a fully specified symbolic runtime
    // context. Its numeric profile inputs are not taken from AZM output.
    if (path.basename(source) !== "runtime-link.asm") throw new Error(`Unsupported generated assembly entry: ${source}`);
    entry = "vertical-slice/nucleus-target-runtime-link.asm";
    overrides.set(entry, await readFile(source, "utf8"));
    overrides.set("vertical-slice/nucleus-runtime-link-context.asmi", await readFile(path.join(path.dirname(source), "nucleus-runtime-link-context.asmi"), "utf8"));
  }
  const result = await assembleAtomSource(entry, { overrides });
  return { hex: result.hex, symbols: result.symbols };
}

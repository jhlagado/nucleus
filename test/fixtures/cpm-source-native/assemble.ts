import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeSource } from "../../../scripts/assemble-native-source.mjs";

export const repositoryRoot = fileURLToPath(new URL("../../../", import.meta.url));
const readJson = (relative: string) =>
  JSON.parse(readFileSync(new URL(relative, import.meta.url), "utf8"));
export const fixedBaseline = readJson("fixed-baseline.json") as {
  revision: string;
  origin: number;
  end: number;
  hex: string;
  sha256: string;
  bdosSha256: string;
  providerSha256: string;
  symbols: Record<string, number>;
};

export const assembleProviderProof = () => assembleNativeSource({
  root: repositoryRoot,
  entry: "test/fixtures/cpm-source-native/entry.asm",
  target: { start: 0x4100, capacity: 0x1700 },
  exportMap: {
    ...readJson("../../../asm/atom-cpm-source-symbols.json"),
    CpmHostWorkspaceLimit: "HOSTLIM",
  },
  requiredExports: [...Object.keys(fixedBaseline.symbols), "CpmHostWorkspaceLimit"],
});

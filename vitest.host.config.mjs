import { defineConfig } from "vitest/config";

// Execute packaged images. Source-assembly proof migration is a separate gate;
// this subset must not be presented as the full conformance suite.
const tests = [
  "cli", "configuration", "d8-publication", "d8", "handle-diagnostic", "host",
  "language-specification", "mon3-native-host", "native-host-shell",
  "native-import-resolver", "native-retained-names", "native-source-host",
  "object-services", "project-host", "project", "publication", "runner",
  "runtime-contract", "source-imports", "source-manifest", "source-plan",
  "source-position-capacity", "type-metadata",
];

export default defineConfig({
  test: { include: tests.map(name => `test/${name}.test.ts`), maxWorkers: 1 },
});

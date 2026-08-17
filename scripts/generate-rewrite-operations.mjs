import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourcePath = path.join(
  root,
  "grammar",
  "rewrite-semantic-operations.json",
);
const asmPath = path.join(root, "asm", "rewrite", "operations-generated.asmi");
const typescriptPath = path.join(
  root,
  "src",
  "rewrite-semantic-operations-internal.ts",
);

const source = JSON.parse(await readFile(sourcePath, "utf8"));
const sourceOperations = source.operations;
if (
  source.version !== 1 ||
  source.tracePolicy !== "operation-start" ||
  !Array.isArray(sourceOperations)
) {
  throw new Error("unsupported rewrite semantic-operation source");
}
const operations = sourceOperations.flatMap((operation) => {
  if (operation.name !== undefined && operation.names === undefined) {
    return [operation];
  }
  if (
    operation.name === undefined &&
    Array.isArray(operation.names) &&
    operation.names.length > 0
  ) {
    return operation.names.map((name) => ({
      ...operation,
      name,
      names: undefined,
    }));
  }
  throw new Error("each semantic operation entry needs name or names");
});

const operandWidths = { byte: 1, word: 2 };
const sourceKinds = { none: 0, direct: 1, enclosing: 2 };
const backendKinds = { recipe: 0, escape: 1 };
const operationNames = new Set();
const backendDirectories = { recipe: [], escape: [] };
const encodeStackEffect = (value, operationName) => {
  if (value === "dynamic") return 15;
  if (Number.isInteger(value) && value >= 0 && value < 15) return value;
  throw new Error(`invalid stack effect for ${operationName}`);
};
// The encoded $F nibble has one meaning. Keep a negative control inside the
// generator so a future relaxation cannot make literal 15 indistinguishable
// from the named dynamic effect.
let rejectsNumericDynamic = false;
try {
  encodeStackEffect(15, "numeric dynamic sentinel");
} catch {
  rejectsNumericDynamic = true;
}
if (!rejectsNumericDynamic) {
  throw new Error("numeric stack effect 15 must remain reserved");
}

const descriptors = operations.map((operation, zeroBasedIndex) => {
  const id = zeroBasedIndex + 1;
  if (!/^[A-Z][A-Za-z0-9]*$/.test(operation.name)) {
    throw new Error(`invalid semantic operation name ${operation.name}`);
  }
  if (operationNames.has(operation.name)) {
    throw new Error(`duplicate semantic operation ${operation.name}`);
  }
  operationNames.add(operation.name);
  if (!Array.isArray(operation.operands) || operation.operands.length > 8) {
    throw new Error(`invalid operands for ${operation.name}`);
  }
  const operandNames = new Set();
  let operandLayout = 0;
  let width = 1;
  const operands = operation.operands.map(([name, kind], index) => {
    const operandWidth = operandWidths[kind];
    const offset = width - 1;
    if (!/^[a-z][A-Za-z0-9]*$/.test(name) || operandNames.has(name)) {
      throw new Error(`invalid operand ${name} for ${operation.name}`);
    }
    if (operandWidth === undefined) {
      throw new Error(`invalid operand kind ${kind} for ${operation.name}`);
    }
    operandNames.add(name);
    if (operandWidth === 2) operandLayout |= 1 << index;
    width += operandWidth;
    return {
      name,
      kind,
      width: operandWidth,
      offset,
      recordOffset: offset + 1,
    };
  });
  if (width > 10) {
    throw new Error(`semantic operation ${operation.name} exceeds ten bytes`);
  }
  const [backendKind, backendName] = operation.backend ?? [];
  if (
    backendKinds[backendKind] === undefined ||
    !/^[a-z][A-Za-z0-9]*$/.test(backendName)
  ) {
    throw new Error(`invalid backend for ${operation.name}`);
  }
  const directory = backendDirectories[backendKind];
  let backendIndex = directory.indexOf(backendName);
  if (backendIndex < 0) {
    backendIndex = directory.length;
    directory.push(backendName);
  }
  if (backendIndex > 127) {
    throw new Error(`backend directory overflow for ${operation.name}`);
  }
  const [sourceStackIn, sourceStackOut] = operation.stack ?? [];
  const stackIn = encodeStackEffect(sourceStackIn, operation.name);
  const stackOut = encodeStackEffect(sourceStackOut, operation.name);
  if (!Number.isInteger(stackIn) || !Number.isInteger(stackOut)) {
    throw new Error(`invalid stack effect for ${operation.name}`);
  }
  const sourceKind = sourceKinds[operation.source];
  if (sourceKind === undefined) {
    throw new Error(`invalid source kind for ${operation.name}`);
  }
  if (backendIndex > 0x7f) {
    throw new Error(`backend selector for ${operation.name} exceeds seven bits`);
  }
  const backendSelector =
    backendIndex | (backendKinds[backendKind] << 7);
  return {
    id,
    name: operation.name,
    operands,
    width,
    operandLayout,
    backendKind,
    backendName,
    backendIndex,
    stackIn,
    stackOut,
    stackInSource: sourceStackIn,
    stackOutSource: sourceStackOut,
    source: operation.source,
    backendSelector,
  };
});

if (descriptors.length === 0 || descriptors.length > 255) {
  throw new Error("semantic operation count must be 1..255");
}

const asmName = (prefix, name) =>
  `${prefix}${name[0].toUpperCase()}${name.slice(1)}`;
const hexByte = (value) =>
  `$${value.toString(16).padStart(2, "0").toUpperCase()}`;

const asm = [
  "; Generated by scripts/generate-rewrite-operations.mjs. Do not edit.",
  "; Every operation emits one semantic-start trace event by global policy.",
  "; Only record widths and packed backend selectors are compiler-resident.",
  "; Complete operand, source, stack, and backend authority remains generated",
  "; in rewrite-semantic-operations-internal.ts for Host/D8 validation.",
  "",
  ...descriptors.map(({ id, name }) => `RewriteSemantic${name} .equ ${id}`),
  ...descriptors.flatMap(({ name, operands, width }) => [
    `RewriteSemantic${name}RecordWidth .equ ${width}`,
    ...operands.map(
      ({ name: operandName, offset }) =>
        `RewriteSemantic${name}Operand${asmName("", operandName)}Offset .equ ${offset}`,
    ),
    ...operands.map(
      ({ name: operandName, recordOffset }) =>
        `RewriteSemantic${name}RecordOperand${asmName("", operandName)}Offset .equ ${recordOffset}`,
    ),
    ...operands.map(
      ({ name: operandName, width: operandWidth }) =>
        `RewriteSemantic${name}Operand${asmName("", operandName)}Width .equ ${operandWidth}`,
    ),
  ]),
  `RewriteSemanticOperationCount .equ ${descriptors.length}`,
  `RewriteSemanticMaximumRecordWidth .equ ${Math.max(...descriptors.map(({ width }) => width))}`,
  "RewriteSemanticSourceNone .equ 0",
  "RewriteSemanticSourceDirect .equ 1",
  "RewriteSemanticSourceEnclosing .equ 2",
  "RewriteSemanticStackDynamic .equ 15",
  "",
  ...backendDirectories.recipe.map(
    (name, index) => `${asmName("RewriteRecipe", name)} .equ ${index}`,
  ),
  `RewriteRecipeCount .equ ${backendDirectories.recipe.length}`,
  ...backendDirectories.escape.map(
    (name, index) => `${asmName("RewriteEscape", name)} .equ ${index}`,
  ),
  `RewriteEscapeCount .equ ${backendDirectories.escape.length}`,
  "",
  "RewriteSemanticOperationWidthTable:",
  ...descriptors.map(({ width, name }) => `            .db ${width} ; ${name}`),
  "RewriteSemanticBackendSelectorTable:",
  ...descriptors.map(
    ({ backendSelector, name }) =>
      `            .db ${hexByte(backendSelector)} ; ${name}`,
  ),
  "RewriteSemanticBackendSelectorTableEnd:",
  "",
].join("\n");

const tsDescriptors = descriptors.map(
  ({
    id,
    name,
    operands,
    width,
    backendKind,
    backendName,
    backendIndex,
    stackIn,
    stackOut,
    stackInSource,
    stackOutSource,
    source: sourceKind,
  }) => ({
    id,
    name,
    operands: operands.map(
      ({
        name: operandName,
        kind,
        width: operandWidth,
        offset,
        recordOffset,
      }) => ({
        name: operandName,
        kind,
        width: operandWidth,
        offset,
        recordOffset,
      }),
    ),
    width,
    backend: { kind: backendKind, name: backendName, index: backendIndex },
    stack: {
      in: stackInSource,
      out: stackOutSource,
      encoded: (stackIn << 4) | stackOut,
    },
    source: sourceKind,
    trace: source.tracePolicy,
  }),
);

const typescript = `// Generated by scripts/generate-rewrite-operations.mjs. Do not edit.\n\nexport const rewriteSemanticTracePolicy = ${JSON.stringify(source.tracePolicy)} as const;\n\nexport const rewriteSemanticOperations = ${JSON.stringify(tsDescriptors, null, 2)} as const;\n\nexport const rewriteSemanticOperationMaximumWidth = ${Math.max(...descriptors.map(({ width }) => width))};\n\nconst rewriteSemanticWidths = Uint8Array.of(${descriptors.map(({ width }) => width).join(", ")});\n\nexport const rewriteSemanticOperationKeys = (\n  payload: Uint8Array,\n  operationCount: number,\n): readonly number[] => {\n  if (!Number.isInteger(operationCount) || operationCount < 0 || operationCount > 255) {\n    throw new Error(\`invalid rewrite semantic operation count \${operationCount}\`);\n  }\n  const keys: number[] = [];\n  let key = 0;\n  for (let index = 0; index < operationCount; index += 1) {\n    const operation = payload[key];\n    if (operation === undefined || operation === 0 || operation > rewriteSemanticWidths.length) {\n      throw new Error(\`rewrite semantic operation \${operation ?? "missing"} at key \${key} is invalid\`);\n    }\n    const width = rewriteSemanticWidths[operation - 1] ?? 0;\n    if (key + width > payload.length) {\n      throw new Error(\`rewrite semantic operation at key \${key} extends beyond the transcript payload\`);\n    }\n    keys.push(key);\n    key += width;\n  }\n  if (key !== payload.length) {\n    throw new Error(\`rewrite semantic transcript ends at \${payload.length}, expected decoded end \${key}\`);\n  }\n  return keys;\n};\n\nexport const assertRewriteSemanticOperationKeys = (\n  payload: Uint8Array,\n  operationCount: number,\n  observedKeys: readonly number[],\n): void => {\n  if (observedKeys.length !== operationCount) {\n    throw new Error(\`rewrite semantic operation count \${operationCount} differs from \${observedKeys.length} trace events\`);\n  }\n  const expected = rewriteSemanticOperationKeys(payload, operationCount);\n  expected.forEach((key, index) => {\n    if (observedKeys[index] !== key) {\n      throw new Error(\`rewrite semantic trace \${index} used key \${observedKeys[index] ?? "missing"}, expected operation boundary \${key}\`);\n    }\n  });\n};\n`;

const outputs = [
  [asmPath, asm],
  [typescriptPath, typescript],
];
if (process.argv.includes("--check")) {
  for (const [outputPath, expected] of outputs) {
    let actual = "";
    try {
      actual = await readFile(outputPath, "utf8");
    } catch {
      // The mismatch below reports a missing generated file.
    }
    if (actual !== expected) {
      throw new Error(
        `${path.relative(root, outputPath)} is stale; run npm run generate:rewrite-operations`,
      );
    }
  }
} else {
  await Promise.all(
    outputs.map(([outputPath, contents]) =>
      writeFile(outputPath, contents, "utf8"),
    ),
  );
}

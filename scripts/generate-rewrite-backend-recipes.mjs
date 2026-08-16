import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const semanticPath = path.join(
  root,
  "grammar",
  "rewrite-semantic-operations.json",
);
const recipePath = path.join(
  root,
  "grammar",
  "rewrite-backend-recipes.json",
);
const outputPath = path.join(
  root,
  "asm",
  "rewrite",
  "backend-recipes-generated.asmi",
);

const semanticSource = JSON.parse(await readFile(semanticPath, "utf8"));
const recipeSource = JSON.parse(await readFile(recipePath, "utf8"));
if (semanticSource.version !== 1 || recipeSource.version !== 1) {
  throw new Error("unsupported rewrite backend-recipe authority");
}

const operations = semanticSource.operations.flatMap((operation) =>
  operation.name === undefined
    ? operation.names.map((name) => ({ ...operation, name, names: undefined }))
    : [operation],
);
const operationIds = new Map(
  operations.map((operation, index) => [operation.name, index + 1]),
);
const recipeSelectors = [];
for (const operation of operations) {
  const [kind, selector] = operation.backend ?? [];
  if (kind !== "recipe") continue;
  if (!recipeSelectors.includes(selector)) recipeSelectors.push(selector);
}

const instruction = {
  end: 0,
  emit: 1,
  operandByte: 2,
  operandWord: 3,
  complementByte: 4,
  dispatch: 5,
};
const byte = (value, description) => {
  if (!Number.isInteger(value) || value < 0 || value > 255) {
    throw new Error(`invalid byte ${value} for ${description}`);
  }
  return value;
};
const hex = (value) => `$${value.toString(16).padStart(2, "0").toUpperCase()}`;
const labelName = (kind, name) =>
  `RewriteBackendRecipe${kind}${name[0].toUpperCase()}${name.slice(1)}`;

const operationsForSelector = new Map(
  recipeSelectors.map((selector) => [
    selector,
    operations.filter(
      (operation) =>
        operation.backend?.[0] === "recipe" &&
        operation.backend?.[1] === selector,
    ),
  ]),
);

const operandOffset = (selector, operandName) => {
  const selected = operationsForSelector.get(selector) ?? [];
  let expected;
  for (const operation of selected) {
    let offset = 0;
    let found;
    for (const [name, width] of operation.operands ?? []) {
      if (name === operandName) found = offset;
      offset += width === "word" ? 2 : 1;
    }
    if (found === undefined) {
      throw new Error(
        `${selector} operand ${operandName} is absent from ${operation.name}`,
      );
    }
    if (expected === undefined) expected = found;
    if (expected !== found) {
      throw new Error(
        `${selector} operand ${operandName} has inconsistent offsets`,
      );
    }
  }
  if (expected === undefined) {
    throw new Error(`recipe selector ${selector} has no semantic operations`);
  }
  return expected;
};

const encodeSteps = (ownerKind, ownerName, selector, steps) => {
  if (!Array.isArray(steps)) throw new Error(`invalid recipe ${ownerName}`);
  const lines = [];
  for (const step of steps) {
    const keys = Object.keys(step);
    if (keys.length !== 1) throw new Error(`invalid step in ${ownerName}`);
    const kind = keys[0];
    if (kind === "emit") {
      const values = step.emit;
      if (!Array.isArray(values) || values.length === 0 || values.length > 255) {
        throw new Error(`invalid literal run in ${ownerName}`);
      }
      const encoded = values.map((value) => byte(value, ownerName));
      lines.push(
        `            .db RewriteBackendRecipeEmit,${encoded.length},${encoded.map(hex).join(",")}`,
      );
      continue;
    }
    if (kind === "operandByte" || kind === "operandWord") {
      if (ownerKind !== "Selector") {
        throw new Error(`${kind} is not valid in fragment ${ownerName}`);
      }
      const name = step[kind];
      const offset = operandOffset(selector, name);
      lines.push(
        `            .db RewriteBackendRecipe${kind[0].toUpperCase()}${kind.slice(1)},${offset}`,
      );
      continue;
    }
    if (kind === "complementByte") {
      if (ownerKind !== "Selector") {
        throw new Error(`complementByte is not valid in fragment ${ownerName}`);
      }
      const [name, adjustment] = step.complementByte ?? [];
      const offset = operandOffset(selector, name);
      lines.push(
        `            .db RewriteBackendRecipeComplementByte,${offset},${byte(adjustment, ownerName)}`,
      );
      continue;
    }
    if (kind === "dispatch") {
      const { first, targets } = step.dispatch ?? {};
      const firstId = operationIds.get(first);
      if (firstId === undefined || !Array.isArray(targets) || targets.length === 0) {
        throw new Error(`invalid dispatch in ${ownerName}`);
      }
      for (let index = 0; index < targets.length; index += 1) {
        const operation = operations[firstId - 1 + index];
        if (operation === undefined) {
          throw new Error(`dispatch in ${ownerName} exceeds the operation table`);
        }
        if (
          operation.backend?.[0] !== "recipe" ||
          operation.backend?.[1] !== selector
        ) {
          throw new Error(
            `dispatch in ${ownerName} crosses recipe selector at ${operation.name}`,
          );
        }
        const target = targets[index];
        if (target !== null && recipeSource.fragments[target] === undefined) {
          throw new Error(`unknown fragment ${target} in ${ownerName}`);
        }
      }
      lines.push(
        `            .db RewriteBackendRecipeDispatch,${firstId},${targets.length}`,
      );
      lines.push(
        `            .dw ${targets.map((target) => (target === null ? "0" : labelName("Fragment", target))).join(",")}`,
      );
      continue;
    }
    throw new Error(`unknown recipe instruction ${kind} in ${ownerName}`);
  }
  lines.push("            .db RewriteBackendRecipeEnd");
  return lines;
};

for (const selector of Object.keys(recipeSource.selectors)) {
  if (!recipeSelectors.includes(selector)) {
    throw new Error(`unknown recipe selector ${selector}`);
  }
}
for (const name of Object.keys(recipeSource.fragments)) {
  if (!/^[a-z][A-Za-z0-9]*$/.test(name)) {
    throw new Error(`invalid recipe fragment ${name}`);
  }
}

const asm = [
  "; Generated by scripts/generate-rewrite-backend-recipes.mjs. Do not edit.",
  "; Recipe instructions and target-byte literal runs are data interpreted by",
  "; backend-recipes.asm. Directory and dispatch words are complete addresses.",
  "",
  "RewriteBackendRecipeEnd .equ 0",
  "RewriteBackendRecipeEmit .equ 1",
  "RewriteBackendRecipeOperandByte .equ 2",
  "RewriteBackendRecipeOperandWord .equ 3",
  "RewriteBackendRecipeComplementByte .equ 4",
  "RewriteBackendRecipeDispatch .equ 5",
  "RewriteBackendRecipeInstructionCount .equ 6",
  "",
  "RewriteBackendRecipeDirectory:",
  ...recipeSelectors.map((selector) =>
    recipeSource.selectors[selector] === undefined
      ? `            .dw 0 ; ${selector}`
      : `            .dw ${labelName("Selector", selector)} ; ${selector}`,
  ),
  "RewriteBackendRecipeDirectoryEnd:",
  "",
  ...Object.entries(recipeSource.selectors).flatMap(([name, steps]) => [
    `${labelName("Selector", name)}:`,
    ...encodeSteps("Selector", name, name, steps),
  ]),
  ...Object.entries(recipeSource.fragments).flatMap(([name, steps]) => [
    `${labelName("Fragment", name)}:`,
    ...encodeSteps("Fragment", name, undefined, steps),
  ]),
  "RewriteBackendRecipeDataEnd:",
  "",
].join("\n");

if (process.argv.includes("--check")) {
  let actual = "";
  try {
    actual = await readFile(outputPath, "utf8");
  } catch {
    // The mismatch below reports the missing generated file.
  }
  if (actual !== asm) {
    throw new Error(
      `${path.relative(root, outputPath)} is stale; run npm run generate:rewrite-backend-recipes`,
    );
  }
} else {
  await writeFile(outputPath, asm, "utf8");
}

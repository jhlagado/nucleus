import type { NucleusDiagnostic } from "./compiler.js";

const diagnosticMessages: Readonly<Record<number, string>> = {
  1: "invalid source token",
  36: "loop counter is already active",
  37: "expected a top-level declaration",
  38: "expected a byte sequence",
  39: "expected an array length",
  40: "semantic transcript capacity exceeded",
  41: "branch fixup is outside its supported range",
  45: "expected a readable value",
  51: "expected a value",
  52: "expected a result",
  53: "forward declaration does not match its completion",
  54: "forward declaration has no completion",
  55: "duplicate name",
  56: "symbol capacity exceeded",
  57: "unknown name",
  58: "expected a scalar value",
  59: "expected a type",
  60: "type mismatch",
  61: "integer value is outside its type range",
  62: "division by zero",
  63: "checked narrowing failed",
  64: "comparison operators cannot be chained",
  65: "expression nesting capacity exceeded",
  66: "Boolean fixup capacity exceeded",
  67: "internal semantic operation is invalid",
  68: "structured-control nesting capacity exceeded",
  69: "control-label capacity exceeded",
  70: "control-flow fixup capacity exceeded",
  71: "expected a Boolean value",
  72: "loop control used outside a loop",
  73: "invalid counted-loop counter",
  74: "invalid counted-loop step",
  75: "routine control flow is invalid",
  76: "type metadata capacity exceeded",
  77: "initializer nesting capacity exceeded",
  78: "initializer shape does not match its type",
  79: "initializer element count does not match its type",
  80: "string literal exceeds its declared capacity",
  81: "program-data capacity exceeded",
  82: "record type must contain a field",
  83: "type bound is invalid",
  84: "routine declaration capacity exceeded",
  85: "routine parameter capacity exceeded",
  86: "aggregate alias cannot escape its valid lifetime",
  87: "failure handling is invalid in this context",
  88: "source-part capacity exceeded",
  90: "string capacity is invalid",
  91: "compile-time assertion failed",
  92: "output segment is invalid",
  93: "read-only-data capacity exceeded",
  94: "assignment to read-only storage",
  95: "target configuration is invalid",
  96: "target image capacity exceeded",
  97: "target output failed",
  98: "`handle NAME` must follow an eligible failable call on the same logical line",
  99: "expected at least one `case` clause",
  100: "`case` must belong to an active `select`; `else` must be its one final clause",
  101: "source position capacity exceeded",
};

export const nucleusDiagnosticMessage = (code: number): string =>
  diagnosticMessages[code] ?? `Nucleus diagnostic ${code}`;

export interface FormatNucleusDiagnosticOptions {
  readonly includeCode?: boolean;
}

export const formatNucleusDiagnostic = (
  diagnostic: NucleusDiagnostic,
  options: FormatNucleusDiagnosticOptions = {},
): string => {
  const location = `${diagnostic.sourceName ?? `part ${diagnostic.sourcePart}`}:${diagnostic.line}:${diagnostic.column}`;
  const message = nucleusDiagnosticMessage(diagnostic.code);
  return `${location}: ${message}${options.includeCode === false ? "" : ` [N${diagnostic.code}]`}`;
};

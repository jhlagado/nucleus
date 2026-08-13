import type { NucleusDiagnostic } from "./compiler.js";
export declare const nucleusDiagnosticMessage: (code: number) => string;
export interface FormatNucleusDiagnosticOptions {
    readonly includeCode?: boolean;
}
export declare const formatNucleusDiagnostic: (diagnostic: NucleusDiagnostic, options?: FormatNucleusDiagnosticOptions) => string;

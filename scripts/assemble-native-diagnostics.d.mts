import { assembleNativeSource } from "./assemble-native-source.mjs";
/** Test-only composition of the canonical compiler diagnostic leaf. */
export function assembleNativeDiagnostics(nonlocal: boolean): ReturnType<typeof assembleNativeSource>;

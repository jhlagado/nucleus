import type { assembleNativeSource } from "./assemble-native-source.mjs";
export function isNativeCompilerEntry(entry: string): boolean;
export function assembleNativeCompiler(entry: string): ReturnType<typeof assembleNativeSource>;

import { assembleNativeSource } from "./assemble-native-source.mjs";

/** Private canonical source proof boundary; not an installed host API. */
export function assembleNativeCpmProof(entry: string): ReturnType<typeof assembleNativeSource>;

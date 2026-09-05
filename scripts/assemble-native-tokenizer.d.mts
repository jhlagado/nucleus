import { assembleNativeSource } from "./assemble-native-source.mjs";
export function assembleNativeTokenizerTrace(): ReturnType<typeof assembleNativeSource>;
export function assembleNativeTokenizerHostProof(): ReturnType<typeof assembleNativeSource>;
export function assembleNativeLoopZ80State(): ReturnType<typeof assembleNativeSource>;
export function assembleNativeCompilerStateProfile(options: {
  legacy: boolean; native: number; segmented: number; target: number;
}): ReturnType<typeof assembleNativeSource>;

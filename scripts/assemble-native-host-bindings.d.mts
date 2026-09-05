import { assembleNativeSource } from "./assemble-native-source.mjs";
export function assembleNativeHostBindings(options: {
  mon3: number; debug: number;
}): ReturnType<typeof assembleNativeSource>;
export function assembleNativeCpmHostVector(options: {
  origin: number;
}): ReturnType<typeof assembleNativeSource>;

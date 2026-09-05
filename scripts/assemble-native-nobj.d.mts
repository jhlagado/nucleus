import { assembleNativeSource } from "./assemble-native-source.mjs";
type NativeResult = Awaited<ReturnType<typeof assembleNativeSource>>;
export function isNativeNobjEntry(entry: string): boolean;
export function assembleNativeNobj(entry: string): Promise<NativeResult & {
  readonly generation: NativeResult["generation"] & {
    readonly symbols: readonly { readonly name: string; readonly value: number }[];
  };
}>;

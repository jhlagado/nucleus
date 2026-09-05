import { assembleNativeSource } from "./assemble-native-source.mjs";

/** Private context inputs; source is emitted in native ATOM syntax directly. */
export function assembleNativeRuntime(context: {
  readonly runtimeBase: number;
  readonly writableStateBase: number;
  readonly programDataBase: number;
  readonly programDataCapacity: number;
  readonly readOnlyBase: number;
  readonly readOnlyCapacity: number;
  readonly packetService: number;
}): ReturnType<typeof assembleNativeSource>;

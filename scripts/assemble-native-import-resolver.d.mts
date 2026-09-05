import { assembleNativeSource } from "./assemble-native-source.mjs";

/** Build-time only; installed hosts execute the generated resolver image. */
export function assembleNativeImportResolver(): ReturnType<typeof assembleNativeSource>;
export function assembleNativeSourcePlanProof(): ReturnType<typeof assembleNativeSource>;

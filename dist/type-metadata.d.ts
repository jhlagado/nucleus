/**
 * Compact compiler metadata for the complete Nucleus 0.1 type grammar.
 *
 * This is compiler-side metadata, not a generated-program runtime tag. The tag folds an
 * array's element family into the outer kind, which keeps every admitted type
 * in four bytes without excluding arrays of records or bounded strings.
 */
export declare const TYPE_DESCRIPTOR_SIZE = 4;
export declare const TypeTag: {
    readonly u8: 0;
    readonly u16: 1;
    readonly boolean: 2;
    readonly record: 3;
    readonly string: 4;
    readonly arrayU8: 5;
    readonly arrayU16: 6;
    readonly arrayBoolean: 7;
    readonly arrayRecord: 8;
    readonly arrayString: 9;
};
export type ScalarName = "u8" | "u16" | "boolean";
export type ScalarType = {
    readonly kind: "u8";
} | {
    readonly kind: "u16";
} | {
    readonly kind: "boolean";
};
export type NucleusType = ScalarType | {
    readonly kind: "record";
    readonly id: number;
} | {
    readonly kind: "string";
    readonly capacity: number;
} | {
    readonly kind: "array";
    readonly length: number;
    readonly element: ScalarType | {
        readonly kind: "record";
        readonly id: number;
    } | {
        readonly kind: "string";
        readonly capacity: number;
    };
};
export type TypeDescriptor = Readonly<Uint8Array>;
export declare function encodeType(type: NucleusType): TypeDescriptor;
export declare function sameType(left: TypeDescriptor, right: TypeDescriptor): boolean;
/**
 * Compare retained metadata bytes only. The report deliberately excludes the
 * code for allocation and lookup, which must be measured in the real compiler.
 */
export declare function metadataStorageReport(types: readonly NucleusType[]): {
    readonly symbols: number;
    readonly uniqueTypes: number;
    readonly inlineBytes: number;
    readonly internedBytes: number;
};

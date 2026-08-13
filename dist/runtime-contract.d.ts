/** Canonical numeric assignments for the direct Nucleus Z80 runtime contract. */
export declare const Trap: {
    readonly bounds: 1;
    readonly narrowing: 2;
    readonly divisionByZero: 3;
    readonly loopRange: 4;
    readonly activationCapacity: 5;
    readonly unhandledError: 6;
};
export declare const Service: {
    readonly readInputByte: 0;
    readonly writeOutputByte: 1;
    readonly readStorageByte: 2;
    readonly rewindStorageInput: 3;
    readonly writeStorageByte: 4;
    readonly seekStorageOutput: 5;
};
export declare const ServiceError: {
    readonly endOfInput: 1;
    readonly inputFailure: 2;
    readonly outputFailure: 3;
    readonly storageFailure: 4;
};

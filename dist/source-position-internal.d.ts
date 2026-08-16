import type { NucleusLoadedSourcePart } from "./d8.js";
export declare const sourcePositionAtOffset: (part: NucleusLoadedSourcePart, offset: number) => {
    line: number;
    column: number;
};

import type { NucleusLoadedSourcePart } from "./d8.js";

export const sourcePositionAtOffset = (
  part: NucleusLoadedSourcePart,
  offset: number,
): { line: number; column: number } => {
  if (offset < 0 || offset > part.bytes.length) {
    throw new Error(`source offset ${offset} is outside part ${part.id}`);
  }
  let line = 1;
  let column = 1;
  for (let index = 0; index < offset; index += 1) {
    const byte = part.bytes[index];
    if (byte === 0x0d && part.bytes[index + 1] === 0x0a) {
      index += 1;
      line += 1;
      column = 1;
    } else if (byte === 0x0a) {
      line += 1;
      column = 1;
    } else {
      column += 1;
    }
  }
  return { line, column };
};

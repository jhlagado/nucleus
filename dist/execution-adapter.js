import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
/** The current reference adapter; production Triptych adapters replace this. */
export const createDebug80ExecutionAdapter = () => {
    const parseImage = (hexText) => parseIntelHex(hexText);
    return Object.freeze({
        parseImage,
        create({ image, entry, write }) {
            return createZ80Runtime({
                ...image,
                memory: image.memory.slice(),
                writeRanges: image.writeRanges?.map(({ start, end }) => ({
                    start,
                    end,
                })),
            }, entry, write === undefined ? undefined : { write });
        },
    });
};

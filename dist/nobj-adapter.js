import { MemoryNobjSpool, NobjError, NobjGenerationSink, NobjGenerationStore, } from "./nobj.js";
const prepareNobjAdapterGeneration = ({ name, producerMemory, start, length, maxBytes, begin, map, runtimeLinkContext, runtimeProvider, store = new NobjGenerationStore(), spoolFactory, lowMemoryPatchValidation = false, onImageByte, }) => {
    if (length > maxBytes) {
        throw new NobjError(`${name}: NOBJ adapter log uses ${length} bytes, limit ${maxBytes}`);
    }
    if (start + length > producerMemory.length) {
        throw new NobjError(`${name}: NOBJ adapter log exceeds producer memory`);
    }
    const sink = new NobjGenerationSink(store, runtimeProvider, spoolFactory ?? (() => new MemoryNobjSpool()), { lowMemoryPatchValidation });
    sink.begin(begin);
    try {
        let cursor = start;
        const end = start + length;
        while (cursor < end) {
            if (end - cursor < 6) {
                throw new NobjError(`${name}: truncated NOBJ adapter operation`);
            }
            const kind = producerMemory[cursor] ?? 0;
            const bank = producerMemory[cursor + 1] ?? 0;
            const address = (producerMemory[cursor + 2] ?? 0) |
                ((producerMemory[cursor + 3] ?? 0) << 8);
            const count = (producerMemory[cursor + 4] ?? 0) |
                ((producerMemory[cursor + 5] ?? 0) << 8);
            cursor += 6;
            if (kind === 3 || kind === 4) {
                if (end - cursor < 2) {
                    throw new NobjError(`${name}: truncated runtime-image operation`);
                }
                const identity = (producerMemory[cursor] ?? 0) |
                    ((producerMemory[cursor + 1] ?? 0) << 8);
                cursor += 2;
                if (kind === 3) {
                    sink.runtimeImage(bank, address, identity, runtimeLinkContext, count);
                }
                else {
                    sink.runtimeInitialImage(bank, address, identity, runtimeLinkContext, count);
                }
                continue;
            }
            if (kind !== 1 && kind !== 2) {
                throw new NobjError(`${name}: unknown NOBJ adapter operation ${kind}`);
            }
            if (cursor + count > end) {
                throw new NobjError(`${name}: truncated NOBJ adapter bytes`);
            }
            const bytes = producerMemory.slice(cursor, cursor + count);
            cursor += count;
            if (kind === 1) {
                for (let offset = 0; offset < bytes.length; offset += 1) {
                    onImageByte?.({
                        bank,
                        address: address + offset,
                        value: bytes[offset] ?? 0,
                    });
                }
                sink.image(bank, address, bytes);
            }
            else {
                sink.patch(bank, address, bytes);
            }
        }
        sink.map(map);
        return sink;
    }
    catch (error) {
        sink.abort();
        throw error;
    }
};
export const commitNobjAdapterGeneration = (generation) => prepareNobjAdapterGeneration(generation).commit();
export const commitNobjAdapterGenerationTo = async (generation, output) => prepareNobjAdapterGeneration(generation).commitTo(output);

import { createHash } from "node:crypto";
import { isNucleusSourceIdentity, NUCLEUS_SOURCE_IDENTITY_REQUIREMENT, } from "./source-identity.js";
export const nucleusSourceFileCapacity = 0xff;
export const nucleusSourceByteCapacity = 0xffff;
export class NucleusSourceBundleError extends Error {
    constructor(message) {
        super(message);
        this.name = "NucleusSourceBundleError";
    }
}
const fail = (message) => {
    throw new NucleusSourceBundleError(message);
};
const bytesOf = (source) => typeof source === "string"
    ? new TextEncoder().encode(source)
    : source.slice();
const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");
const validateBoundary = (bytes, name) => {
    const delimiters = [];
    let quote = 0;
    let escaped = false;
    let comment = false;
    for (let offset = 0; offset < bytes.length; offset += 1) {
        const byte = bytes[offset];
        if (byte !== 0x09 &&
            byte !== 0x0a &&
            byte !== 0x0d &&
            (byte < 0x20 || byte > 0x7e)) {
            fail(`${name} has unsupported source byte at offset ${offset}`);
        }
        if (byte === 0x0d && bytes[offset + 1] !== 0x0a) {
            fail(`${name} has a lone CR at offset ${offset}`);
        }
        if (comment) {
            if (byte === 0x0a)
                comment = false;
            continue;
        }
        if (quote !== 0) {
            if (byte === 0x0a || byte === 0x0d) {
                fail(`${name} has an unterminated literal at offset ${offset}`);
            }
            if (escaped)
                escaped = false;
            else if (byte === 0x5c)
                escaped = true;
            else if (byte === quote)
                quote = 0;
            continue;
        }
        if (byte === 0x2f && bytes[offset + 1] === 0x2f) {
            comment = true;
            offset += 1;
        }
        else if (byte === 0x22 || byte === 0x27) {
            quote = byte;
        }
        else if (byte === 0x28 || byte === 0x5b) {
            delimiters.push(byte);
        }
        else if (byte === 0x29 || byte === 0x5d) {
            const expected = byte === 0x29 ? 0x28 : 0x5b;
            if (delimiters.pop() !== expected) {
                fail(`${name} has a mismatched delimiter at offset ${offset}`);
            }
        }
    }
    if (quote !== 0)
        fail(`${name} has an unterminated literal at its boundary`);
    if (delimiters.length !== 0)
        fail(`${name} ends inside a delimiter`);
};
const validateBank = (bank, name) => {
    if (!Number.isInteger(bank) || bank < 0 || bank > 0xff) {
        fail(`${name} has a bank outside 0..255`);
    }
};
export const prepareNucleusSourceBundle = (sources) => {
    if (sources.length < 1 || sources.length > nucleusSourceFileCapacity) {
        fail(`Nucleus projects require 1..${nucleusSourceFileCapacity} source files`);
    }
    const names = new Set();
    const prepared = [];
    let byteLength = 0;
    for (const source of sources) {
        if (!isNucleusSourceIdentity(source.name)) {
            fail(`source name ${NUCLEUS_SOURCE_IDENTITY_REQUIREMENT}`);
        }
        if (names.has(source.name))
            fail(`duplicate source name ${source.name}`);
        names.add(source.name);
        const bytes = bytesOf(source.source);
        validateBoundary(bytes, source.name);
        const bank = source.bank ?? 0;
        validateBank(bank, source.name);
        const start = byteLength;
        const addedNewline = bytes.at(-1) !== 0x0a;
        byteLength += bytes.length + Number(addedNewline);
        if (byteLength > nucleusSourceByteCapacity) {
            fail(`concatenated source contains ${byteLength} bytes; capacity is ${nucleusSourceByteCapacity}`);
        }
        prepared.push({
            bytes,
            file: {
                name: source.name,
                start,
                end: start + bytes.length,
                addedNewline,
                bank,
                byteLength: bytes.length,
                sha256: sha256(bytes),
            },
        });
    }
    const bytes = new Uint8Array(byteLength);
    const placement = [];
    for (const { bytes: fileBytes, file } of prepared) {
        bytes.set(fileBytes, file.start);
        const end = file.end + Number(file.addedNewline);
        if (file.addedNewline)
            bytes[file.end] = 0x0a;
        const previous = placement.at(-1);
        if (previous !== undefined && previous.bank === file.bank) {
            placement[placement.length - 1] = { ...previous, end };
        }
        else {
            placement.push({ start: file.start, end, bank: file.bank });
        }
    }
    return {
        bytes,
        byteLength,
        sha256: sha256(bytes),
        files: prepared.map(({ file }) => file),
        placement,
    };
};
const positionAt = (bytes, offset) => {
    let line = 1;
    let column = 1;
    for (let index = 0; index < offset; index += 1) {
        if (bytes[index] === 0x0d && bytes[index + 1] === 0x0a) {
            index += 1;
            line += 1;
            column = 1;
        }
        else if (bytes[index] === 0x0a) {
            line += 1;
            column = 1;
        }
        else {
            column += 1;
        }
    }
    return { line, column };
};
export const mapNucleusSourceBundleOffset = (bundle, offset) => {
    if (!Number.isInteger(offset) || offset < 0 || offset > bundle.byteLength) {
        fail(`source offset ${offset} is outside the concatenated source`);
    }
    const file = bundle.files.find((candidate, index) => {
        const next = bundle.files[index + 1];
        return offset >= candidate.start &&
            (next === undefined ? offset <= bundle.byteLength : offset < next.start);
    });
    if (file === undefined) {
        throw new NucleusSourceBundleError(`source offset ${offset} has no source file`);
    }
    const sourceOffset = Math.min(offset, file.end) - file.start;
    const sourceBytes = bundle.bytes.slice(file.start, file.end);
    return {
        name: file.name,
        offset: sourceOffset,
        ...positionAt(sourceBytes, sourceOffset),
        synthetic: file.addedNewline && offset >= file.end,
    };
};

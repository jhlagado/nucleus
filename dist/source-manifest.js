export function parseSourceManifest(text) {
    if (/\r(?!\n)/.test(text)) {
        throw new Error("source manifest contains a lone carriage return");
    }
    return text.replaceAll("\r\n", "\n").split("\n").filter(Boolean);
}
export function buildSourceParts(manifest, readSource) {
    return parseSourceManifest(manifest).map((name, index) => ({
        ordinal: index + 1,
        stableIdentity: `${index + 1}:${name}`,
        diagnosticName: name,
        bytes: readSource(name),
    }));
}

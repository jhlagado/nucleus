export const NUCLEUS_SOURCE_IDENTITY_REQUIREMENT = "must be a normalized project-relative printable ASCII path of 1..255 bytes using '/' separators";
export const isNucleusSourceIdentity = (value) => {
    if (typeof value !== "string" || value.length < 1 || value.length > 0xff) {
        return false;
    }
    if (value.includes("\\") ||
        value
            .split("/")
            .some((part) => part === "" || part === "." || part === "..")) {
        return false;
    }
    return [...value].every((character) => {
        const code = character.charCodeAt(0);
        return code >= 0x20 && code <= 0x7e;
    });
};

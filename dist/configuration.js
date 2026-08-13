export const NUCLEUS_TARGET_PROFILE_SCHEMA = "nucleus-target/v1";
export class NucleusConfigurationError extends Error {
    issues;
    code = "NUCLEUS_CONFIGURATION";
    constructor(message, issues) {
        super(message);
        this.issues = issues;
        this.name = "NucleusConfigurationError";
    }
}
const targetKeys = new Set([
    "schema",
    "imageBase",
    "imageCapacity",
    "writableBase",
    "writableCapacity",
    "establishStack",
    "services",
    "bankCount",
    "entryBank",
    "partBanks",
]);
export const nucleusTargetServiceNames = [
    "readInputByte",
    "writeOutputByte",
    "readStorageByte",
    "rewindStorageInput",
    "writeStorageByte",
    "seekStorageOutput",
    "success",
    "unhandledFailure",
    "trap",
    "farCall",
    "farJump",
];
const wordFields = [
    "imageBase",
    "imageCapacity",
    "writableBase",
    "writableCapacity",
];
const isObject = (value) => typeof value === "object" && value !== null && !Array.isArray(value);
const issue = (issues, path, message) => {
    issues.push({ path, message });
};
const validateWord = (issues, path, value) => {
    if (!Number.isInteger(value) ||
        value < 0 ||
        value > 0xffff) {
        issue(issues, path, "must be an integer in the range 0..65535");
        return false;
    }
    return true;
};
export const validateNucleusTarget = (value, options = {}) => {
    const issues = [];
    if (!isObject(value)) {
        return [{ path: "$", message: "must be a JSON object" }];
    }
    for (const key of Object.keys(value)) {
        if (!targetKeys.has(key))
            issue(issues, `$.${key}`, "is not a recognised target field");
    }
    if (value.schema !== undefined &&
        value.schema !== NUCLEUS_TARGET_PROFILE_SCHEMA) {
        issue(issues, "$.schema", `must be ${JSON.stringify(NUCLEUS_TARGET_PROFILE_SCHEMA)}`);
    }
    for (const field of wordFields) {
        if (value[field] !== undefined)
            validateWord(issues, `$.${field}`, value[field]);
    }
    if (value.establishStack !== undefined &&
        typeof value.establishStack !== "boolean") {
        issue(issues, "$.establishStack", "must be Boolean");
    }
    const imageBase = typeof value.imageBase === "number" ? value.imageBase : 0x8000;
    const imageCapacity = typeof value.imageCapacity === "number" ? value.imageCapacity : 0x1000;
    const writableBase = typeof value.writableBase === "number" ? value.writableBase : 0x4000;
    const writableCapacity = typeof value.writableCapacity === "number"
        ? value.writableCapacity
        : 0x1000;
    if (Number.isInteger(imageBase) &&
        Number.isInteger(imageCapacity) &&
        imageBase + imageCapacity > 0x10000) {
        issue(issues, "$.imageCapacity", "extends the image region beyond address 65535");
    }
    if (Number.isInteger(writableBase) &&
        Number.isInteger(writableCapacity) &&
        writableBase + writableCapacity > 0x10000) {
        issue(issues, "$.writableCapacity", "extends the writable region beyond address 65535");
    }
    if (value.services === undefined) {
        if (options.requireServices === true) {
            issue(issues, "$.services", "must define every Nucleus system service address");
        }
    }
    else if (!isObject(value.services)) {
        issue(issues, "$.services", "must be an object");
    }
    else {
        const knownServices = new Set(nucleusTargetServiceNames);
        for (const key of Object.keys(value.services)) {
            if (!knownServices.has(key)) {
                issue(issues, `$.services.${key}`, "is not a recognised Nucleus service");
            }
        }
        for (const name of nucleusTargetServiceNames) {
            const service = value.services[name];
            if (service === undefined) {
                issue(issues, `$.services.${name}`, "is required");
            }
            else {
                validateWord(issues, `$.services.${name}`, service);
            }
        }
    }
    const banked = value.bankCount !== undefined;
    if (!banked) {
        if (value.entryBank !== undefined) {
            issue(issues, "$.entryBank", "requires bankCount");
        }
        if (value.partBanks !== undefined) {
            issue(issues, "$.partBanks", "requires bankCount");
        }
    }
    else {
        const bankCount = value.bankCount;
        if (!Number.isInteger(bankCount) ||
            bankCount < 1 ||
            bankCount > 4) {
            issue(issues, "$.bankCount", "must be an integer in the range 1..4");
        }
        if (!Number.isInteger(value.entryBank) ||
            value.entryBank < 0 ||
            (Number.isInteger(bankCount) &&
                value.entryBank >= bankCount)) {
            issue(issues, "$.entryBank", "must identify a bank within bankCount");
        }
        if (!Array.isArray(value.partBanks)) {
            issue(issues, "$.partBanks", "must be an array of source-part bank ordinals");
        }
        else {
            if (options.sourcePartCount !== undefined &&
                value.partBanks.length !== options.sourcePartCount) {
                issue(issues, "$.partBanks", `must contain ${options.sourcePartCount} entries for this build`);
            }
            value.partBanks.forEach((bank, index) => {
                if (!Number.isInteger(bank) ||
                    bank < 0 ||
                    (Number.isInteger(bankCount) &&
                        bank >= bankCount)) {
                    issue(issues, `$.partBanks[${index}]`, "must identify a bank within bankCount");
                }
            });
        }
    }
    return issues;
};
export const assertNucleusTarget = (value, options = {}) => {
    const issues = validateNucleusTarget(value, options);
    if (issues.length > 0) {
        throw new NucleusConfigurationError("Invalid Nucleus target profile", issues);
    }
    const input = value;
    const target = {};
    for (const key of targetKeys) {
        if (key !== "schema" && input[key] !== undefined)
            target[key] = input[key];
    }
    return target;
};
export const parseNucleusTargetProfile = (text, options = {}) => {
    let value;
    try {
        value = JSON.parse(text);
    }
    catch (error) {
        throw new NucleusConfigurationError("Invalid Nucleus target profile JSON", [
            {
                path: "$",
                message: error instanceof Error ? error.message : String(error),
            },
        ]);
    }
    return assertNucleusTarget(value, options);
};

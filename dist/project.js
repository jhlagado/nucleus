import { NucleusConfigurationError } from "./configuration.js";
import { isNucleusSourceIdentity, NUCLEUS_SOURCE_IDENTITY_REQUIREMENT, } from "./source-identity.js";
export const NUCLEUS_PROJECT_V1_SCHEMA = "nucleus-project/v1";
export const NUCLEUS_PROJECT_V2_SCHEMA = "nucleus-project/v2";
export const NUCLEUS_PROJECT_SCHEMA = NUCLEUS_PROJECT_V1_SCHEMA;
const isObject = (value) => typeof value === "object" && value !== null && !Array.isArray(value);
const nonemptyString = (value) => typeof value === "string" && value.trim().length > 0;
export const parseNucleusProject = (text) => {
    let value;
    try {
        value = JSON.parse(text);
    }
    catch (error) {
        throw new NucleusConfigurationError("Invalid Nucleus project JSON", [
            {
                path: "$",
                message: error instanceof Error ? error.message : String(error),
            },
        ]);
    }
    const issues = [];
    if (!isObject(value)) {
        throw new NucleusConfigurationError("Invalid Nucleus project", [
            { path: "$", message: "must be a JSON object" },
        ]);
    }
    const v2 = value.schema === NUCLEUS_PROJECT_V2_SCHEMA;
    const allowed = new Set(v2
        ? ["schema", "root", "entry", "sourceBanks", "target", "outputs"]
        : ["schema", "root", "sources", "target", "outputs"]);
    for (const key of Object.keys(value)) {
        if (!allowed.has(key))
            issues.push({ path: `$.${key}`, message: "is not recognised" });
    }
    if (value.schema !== NUCLEUS_PROJECT_V1_SCHEMA &&
        value.schema !== NUCLEUS_PROJECT_V2_SCHEMA) {
        issues.push({
            path: "$.schema",
            message: `must be ${JSON.stringify(NUCLEUS_PROJECT_V1_SCHEMA)} or ${JSON.stringify(NUCLEUS_PROJECT_V2_SCHEMA)}`,
        });
    }
    if (value.root !== undefined && !nonemptyString(value.root)) {
        issues.push({ path: "$.root", message: "must be a nonempty path" });
    }
    if (v2) {
        if (!isNucleusSourceIdentity(value.entry)) {
            issues.push({
                path: "$.entry",
                message: NUCLEUS_SOURCE_IDENTITY_REQUIREMENT,
            });
        }
        if (value.sourceBanks !== undefined) {
            if (!isObject(value.sourceBanks)) {
                issues.push({ path: "$.sourceBanks", message: "must be an object" });
            }
            else {
                for (const [source, bank] of Object.entries(value.sourceBanks)) {
                    if (!isNucleusSourceIdentity(source)) {
                        issues.push({
                            path: `$.sourceBanks.${source}`,
                            message: `key ${NUCLEUS_SOURCE_IDENTITY_REQUIREMENT}`,
                        });
                    }
                    if (typeof bank !== "number" ||
                        !Number.isInteger(bank) ||
                        bank < 0 ||
                        bank > 0xff) {
                        issues.push({
                            path: `$.sourceBanks.${source}`,
                            message: "must be an integer in the range 0..255",
                        });
                    }
                }
            }
        }
    }
    else {
        if (!Array.isArray(value.sources) || value.sources.length === 0) {
            issues.push({
                path: "$.sources",
                message: "must contain at least one source path",
            });
        }
        else {
            value.sources.forEach((source, index) => {
                if (!nonemptyString(source)) {
                    issues.push({
                        path: `$.sources[${index}]`,
                        message: "must be a nonempty path",
                    });
                }
            });
        }
    }
    if (!nonemptyString(value.target)) {
        issues.push({ path: "$.target", message: "must be a nonempty path" });
    }
    if (!isObject(value.outputs)) {
        issues.push({ path: "$.outputs", message: "must be an object" });
    }
    else {
        const outputKeys = new Set(["nobj", "hex", "d8"]);
        for (const key of Object.keys(value.outputs)) {
            if (!outputKeys.has(key)) {
                issues.push({ path: `$.outputs.${key}`, message: "is not recognised" });
            }
        }
        for (const key of ["nobj", "hex", "d8"]) {
            const output = value.outputs[key];
            if ((key === "nobj" || output !== undefined) && !nonemptyString(output)) {
                issues.push({
                    path: `$.outputs.${key}`,
                    message: "must be a nonempty path",
                });
            }
        }
    }
    if (issues.length > 0) {
        throw new NucleusConfigurationError("Invalid Nucleus project", issues);
    }
    return value;
};

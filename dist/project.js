import { NucleusConfigurationError } from "./configuration.js";
export const NUCLEUS_PROJECT_SCHEMA = "nucleus-project/v1";
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
    const allowed = new Set(["schema", "root", "sources", "target", "outputs"]);
    for (const key of Object.keys(value)) {
        if (!allowed.has(key))
            issues.push({ path: `$.${key}`, message: "is not recognised" });
    }
    if (value.schema !== NUCLEUS_PROJECT_SCHEMA) {
        issues.push({
            path: "$.schema",
            message: `must be ${JSON.stringify(NUCLEUS_PROJECT_SCHEMA)}`,
        });
    }
    if (value.root !== undefined && !nonemptyString(value.root)) {
        issues.push({ path: "$.root", message: "must be a nonempty path" });
    }
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

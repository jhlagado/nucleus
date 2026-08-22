import { compileNucleusTo, nucleusCompilerCapacities, nucleusCompilerInfo, writeNucleusIntelHex, } from "./compiler.js";
import { materializeNobj, parseNobj } from "./nobj.js";
import { validateNucleusTarget, } from "./configuration.js";
import { nucleusD8SourceName } from "./d8-internal.js";
import { nucleusDiagnosticMessage } from "./diagnostics.js";
export const NUCLEUS_HOST_API_VERSION = 1;
const configurationFailure = (issues) => ({
    success: false,
    kind: "configuration",
    message: "Invalid Nucleus build configuration",
    issues,
});
export class NucleusCompiler {
    async info() {
        return await nucleusCompilerInfo();
    }
    async build(request) {
        const target = request.target ?? {};
        const issues = [
            ...validateNucleusTarget(target, {
                requireServices: request.artifacts?.hex === true,
                sourcePartCount: request.sources.length,
            }),
        ];
        if (request.hostTransport !== undefined &&
            request.hostTransport !== "direct" &&
            request.hostTransport !== "mon3") {
            issues.push({
                path: "$.hostTransport",
                message: "must be direct or mon3",
            });
        }
        if (request.sources.length === 0) {
            issues.push({
                path: "$.sources",
                message: "must contain at least one source part",
            });
        }
        else if (request.sources.length > nucleusCompilerCapacities.sourceParts) {
            issues.push({
                path: "$.sources",
                message: `must contain at most ${nucleusCompilerCapacities.sourceParts} source parts`,
            });
        }
        const d8SourceNames = new Map();
        request.sources.forEach((part, index) => {
            if (typeof part.name !== "string" || part.name.length === 0) {
                issues.push({
                    path: `$.sources[${index}].name`,
                    message: "must be a nonempty source identity",
                });
            }
            if (!(typeof part.source === "string" || part.source instanceof Uint8Array)) {
                issues.push({
                    path: `$.sources[${index}].source`,
                    message: "must be a string or Uint8Array",
                });
            }
            else {
                const byteLength = typeof part.source === "string"
                    ? new TextEncoder().encode(part.source).length
                    : part.source.length;
                if (byteLength > nucleusCompilerCapacities.sourcePartBytes) {
                    issues.push({
                        path: `$.sources[${index}].source`,
                        message: `contains ${byteLength} bytes; capacity is ${nucleusCompilerCapacities.sourcePartBytes}`,
                    });
                }
            }
            if (request.artifacts?.d8 === true &&
                typeof part.name === "string" &&
                part.name.length > 0) {
                const d8Name = nucleusD8SourceName(part.name);
                const previous = d8SourceNames.get(d8Name);
                if (previous === undefined) {
                    d8SourceNames.set(d8Name, index);
                }
                else {
                    issues.push({
                        path: `$.sources[${index}].name`,
                        message: `duplicates the portable D8 source identity of $.sources[${previous}].name`,
                    });
                }
            }
        });
        if (request.artifacts?.hex === true &&
            "bankCount" in target &&
            target.bankCount > 1) {
            issues.push({
                path: "$.artifacts.hex",
                message: "requires a flat target",
            });
        }
        if (issues.length > 0)
            return configurationFailure(issues);
        try {
            const chunks = [];
            let committed = false;
            const compiled = await compileNucleusTo(request.sources, target, {
                write: (bytes) => chunks.push(bytes.slice()),
                commit: () => {
                    committed = true;
                },
                abort: () => {
                    chunks.length = 0;
                },
            }, {
                debugMap: request.artifacts?.d8 === true,
                hostTransport: request.hostTransport,
            });
            if (!compiled.success) {
                if (compiled.diagnostic.code === 95 ||
                    compiled.diagnostic.code === 96) {
                    return configurationFailure([
                        {
                            path: "$.target",
                            message: nucleusDiagnosticMessage(compiled.diagnostic.code),
                        },
                    ]);
                }
                if (compiled.diagnostic.code === 97) {
                    return {
                        success: false,
                        kind: "execution",
                        message: nucleusDiagnosticMessage(compiled.diagnostic.code),
                    };
                }
                return {
                    success: false,
                    kind: "source",
                    message: nucleusDiagnosticMessage(compiled.diagnostic.code),
                    diagnostic: compiled.diagnostic,
                    instructions: compiled.instructions,
                    cycles: compiled.cycles,
                };
            }
            if (!committed) {
                throw new Error("Nucleus compiler returned without committing NOBJ");
            }
            const byteLength = chunks.reduce((total, chunk) => total + chunk.length, 0);
            const nobj = new Uint8Array(byteLength);
            let cursor = 0;
            for (const chunk of chunks) {
                nobj.set(chunk, cursor);
                cursor += chunk.length;
            }
            const materialized = materializeNobj(parseNobj(nobj));
            const d8 = compiled.debugMapping?.maps.map(({ bank, map }) => ({
                bank,
                map,
                json: `${JSON.stringify(map, null, 2)}\n`,
            }));
            const compatibilityResult = {
                success: true,
                nobj,
                materialized,
                ...(compiled.debugMapping === undefined
                    ? {}
                    : { debugMapping: compiled.debugMapping }),
                instructions: compiled.instructions,
                cycles: compiled.cycles,
            };
            return {
                success: true,
                artifacts: {
                    nobj,
                    ...(request.artifacts?.hex === true
                        ? { hex: writeNucleusIntelHex(compatibilityResult) }
                        : {}),
                    ...(d8 === undefined ? {} : { d8 }),
                },
                materialized,
                instructions: compiled.instructions,
                cycles: compiled.cycles,
            };
        }
        catch (error) {
            return {
                success: false,
                kind: "execution",
                message: error instanceof Error ? error.message : String(error),
                cause: error,
            };
        }
    }
}
export const createNucleusCompiler = () => new NucleusCompiler();

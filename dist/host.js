import { compileNucleus, nucleusCompilerCapacities, nucleusCompilerInfo, writeNucleusIntelHex, } from "./compiler.js";
import { validateNucleusTarget, } from "./configuration.js";
import { nucleusDiagnosticMessage } from "./diagnostics.js";
import { sourcePartBytes } from "./d8.js";
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
        let sourceWindowUse = request.sources.length * 5;
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
                sourceWindowUse += sourcePartBytes(part).length;
            }
        });
        if (sourceWindowUse > nucleusCompilerCapacities.sourceWindowBytes) {
            issues.push({
                path: "$.sources",
                message: `requires ${sourceWindowUse} bytes in the ${nucleusCompilerCapacities.sourceWindowBytes}-byte host source window`,
            });
        }
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
            const compiled = await compileNucleus(request.sources, target, {
                debugMap: request.artifacts?.d8 === true,
            });
            if (!compiled.success) {
                return {
                    success: false,
                    kind: "source",
                    message: nucleusDiagnosticMessage(compiled.diagnostic.code),
                    diagnostic: compiled.diagnostic,
                    instructions: compiled.instructions,
                    cycles: compiled.cycles,
                };
            }
            const d8 = compiled.debugMapping?.maps.map(({ bank, map }) => ({
                bank,
                map,
                json: `${JSON.stringify(map, null, 2)}\n`,
            }));
            return {
                success: true,
                artifacts: {
                    nobj: compiled.nobj,
                    ...(request.artifacts?.hex === true
                        ? { hex: writeNucleusIntelHex(compiled) }
                        : {}),
                    ...(d8 === undefined ? {} : { d8 }),
                },
                materialized: compiled.materialized,
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

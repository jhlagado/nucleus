import { describe, expect, it } from "vitest";

import { compileNucleus } from "../src/compiler.js";
import { runNucleusNobj } from "../src/runner.js";
import { resolveNucleusImports } from "../src/source-imports.js";

const compile = async (source: string) => {
  const result = await compileNucleus([{ name: "main.nu", source }]);
  if (!result.success) throw new Error(JSON.stringify(result.diagnostic));
  return result.nobj;
};

describe("the Node Z80 NOBJ runner", () => {
  it("runs the imported standard library through the production service adapter", async () => {
    const parts = await resolveNucleusImports({
      root: new URL("../examples/", import.meta.url).pathname,
      entry: "hello.nu",
    });
    const built = await compileNucleus(parts);
    if (!built.success) throw new Error(JSON.stringify(built.diagnostic));
    const result = runNucleusNobj(built.nobj, {}, {
      maxInstructions: 5_000_000,
      maxCycles: 50_000_000,
    });
    expect(result).toMatchObject({ success: true, outcome: "success" });
    expect(new TextDecoder().decode(result.output)).toBe("Total: 42\n");
  }, 30_000);

  it("loads committed NOBJ with the Z80 consumer and runs console services", async () => {
    const object = await compile(
      [
        "sub main() fails",
        "writeOutputByte('A') else fail",
        "writeOutputByte('Z') else fail",
        "end",
        "",
      ].join("\n"),
    );
    const result = runNucleusNobj(object);
    expect(result).toMatchObject({ success: true, outcome: "success" });
    expect(new TextDecoder().decode(result.output)).toBe("AZ");
    expect(result.loaderInstructions).toBeGreaterThan(0);
    expect(result.programInstructions).toBeGreaterThan(0);
    expect(result.instructions).toBe(
      result.loaderInstructions + result.programInstructions,
    );
  }, 30_000);

  it("keeps the loader watchdog separate from the program limit", async () => {
    const object = await compile("sub main()\nwhile true\nend\nend\n");
    const result = runNucleusNobj(object, {}, { maxInstructions: 10 });
    expect(result).toMatchObject({
      success: false,
      outcome: "executionLimit",
      phase: "program",
      programInstructions: 10,
    });
    expect(result.loaderInstructions).toBeGreaterThan(10);
  });

  it("streams console bytes through callbacks while retaining the result", async () => {
    const object = await compile(
      [
        "sub main() fails",
        "var value as u8 = readInputByte() else fail",
        "writeOutputByte(value) else fail",
        "end",
        "",
      ].join("\n"),
    );
    const streamed: number[] = [];
    let read = false;
    const result = runNucleusNobj(object, {}, {
      readInput: () => {
        if (read) return undefined;
        read = true;
        return "K".charCodeAt(0);
      },
      writeOutput: (value) => streamed.push(value),
    });
    expect(result).toMatchObject({ success: true, outcome: "success" });
    expect(streamed).toEqual(["K".charCodeAt(0)]);
    expect(result.output).toEqual(Uint8Array.of("K".charCodeAt(0)));
  }, 30_000);

  it("binds sequential storage and the packet gateway through the Node adapter", async () => {
    const object = await compile(
      [
        "var packet as u8[2] = [1, 2]",
        "sub main() fails",
        "var first as u8",
        "var second as u8",
        "first = readStorageByte() else fail",
        "rewindStorageInput() else fail",
        "second = readStorageByte() else fail",
        "writeStorageByte(first) else fail",
        "writeStorageByte(second) else fail",
        "seekStorageOutput(1) else fail",
        "writeStorageByte('Z') else fail",
        "service(3, packet)",
        "writeOutputByte(packet[0]) else fail",
        "end",
        "",
      ].join("\n"),
    );
    const result = runNucleusNobj(object, {}, {
      storageInput: ["A".charCodeAt(0)],
      packetService: (slot, packet) => {
        expect(slot).toBe(3);
        expect(Array.from(packet)).toEqual([1, 2]);
        packet[0] = 9;
      },
    });
    expect(result).toMatchObject({ success: true, outcome: "success" });
    expect(result.storageOutput).toEqual(
      Uint8Array.of("A".charCodeAt(0), "Z".charCodeAt(0)),
    );
    expect(result.output).toEqual(Uint8Array.of(9));
  }, 30_000);

  it("keeps source port output separate from the private Node MON3 shim", async () => {
    const object = await compile(
      "sub main()\nwritePort($00E0, $5A)\nend\n",
    );
    const writes: Array<{ port: number; value: number }> = [];
    const result = runNucleusNobj(object, {}, {
      ioWrite: (port, value) => writes.push({ port, value }),
    });
    expect(result).toMatchObject({ success: true, outcome: "success" });
    expect(result.output).toEqual(new Uint8Array());
    expect(writes).toEqual([{ port: 0x00e0, value: 0x5a }]);
  }, 30_000);

  it("uses the runtime return arena to unwind nested physical-bank calls", async () => {
    const parts = [
      {
        name: "leaf.nu",
        source: [
          "sub emit() fails",
          "writeOutputByte('B') else fail",
          "end",
          "",
        ].join("\n"),
      },
      {
        name: "bridge.nu",
        source: ["sub bridge() fails", "emit() else fail", "end", ""].join(
          "\n",
        ),
      },
      {
        name: "main.nu",
        source: ["sub main() fails", "bridge() else fail", "end", ""].join(
          "\n",
        ),
      },
    ];
    const target = {
      bankCount: 3,
      entryBank: 0,
      partBanks: [2, 1, 0],
    } as const;
    const built = await compileNucleus(parts, target);
    if (!built.success) throw new Error(JSON.stringify(built.diagnostic));
    const result = runNucleusNobj(built.nobj, target);
    expect(result).toMatchObject({ success: true, outcome: "success" });
    expect(new TextDecoder().decode(result.output)).toBe("B");
    expect(result.banks).toHaveLength(3);
    expect(result.banks?.[0]).toEqual(built.materialized.banks[0]);
    expect(result.banks?.[1]).toEqual(built.materialized.banks[1]);
    expect(result.banks?.[2]).toEqual(built.materialized.banks[2]);
    expect(result.memory[0x4024 + 8]).toBe(0);
    expect(result.memory[0x4024 + 9]).toBe(0);
    expect(result.memory[0x4024 + 10]).toBe(1);
    expect(result.memory[0x4024 + 21]).not.toBe(0);
    expect(result.memory[0x4024 + 23]).not.toBe(0);
  }, 30_000);

  it("rejects malformed public target profiles before loading", async () => {
    const object = await compile("sub main()\nend\n");
    expect(() =>
      runNucleusNobj(object, {
        imageBase: 0xff00,
        imageCapacity: 0x0200,
      }),
    ).toThrowError("Invalid Nucleus target profile");
  });

  it("uses a far jump to report a trap from a non-entry bank", async () => {
    const parts = [
      {
        name: "library.nu",
        source: [
          "sub divide(value as u8) as u8",
          "return 1 / value",
          "end",
          "",
        ].join("\n"),
      },
      {
        name: "main.nu",
        source: [
          "sub main() fails",
          "var zero as u8 = readInputByte() else fail",
          "var result as u8 = divide(zero)",
          "end",
          "",
        ].join("\n"),
      },
    ];
    const target = {
      bankCount: 2,
      entryBank: 0,
      partBanks: [1, 0],
    } as const;
    const built = await compileNucleus(parts, target);
    if (!built.success) throw new Error(JSON.stringify(built.diagnostic));
    const result = runNucleusNobj(built.nobj, target, { input: [0] });
    expect(result).toMatchObject({ success: false, outcome: "trap" });
    expect(result.memory[0x4024 + 8]).toBe(0);
  }, 30_000);

  it("reports an unhandled recoverable failure from initialized runtime state", async () => {
    const object = await compile("sub main() fails\nfail 9\nend\n");
    const result = runNucleusNobj(object);
    expect(result).toMatchObject({
      success: false,
      outcome: "unhandledFailure",
      trapReason: 6,
      errorCode: 9,
    });
  }, 30_000);

  it("never enters an object rejected by the standalone Z80 consumer", async () => {
    const object = await compile("sub main()\nend\n");
    const corrupted = object.slice();
    corrupted[corrupted.length - 1] ^= 1;
    const result = runNucleusNobj(corrupted);
    expect(result).toMatchObject({
      success: false,
      outcome: "loaderFailure",
      loaderOutcome: 1,
    });
  }, 30_000);
});

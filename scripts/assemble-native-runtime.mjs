// Native runtime composition shared by catalog generation and development links.
import { copyFile, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { assembleNativeSource } from "./assemble-native-source.mjs";

const assemblyDirectory = new URL("../asm/vertical-slice/", import.meta.url);
const runtimeSymbols = JSON.parse(await readFile(new URL("../asm/atom-runtime-symbols.json", import.meta.url), "utf8"));
const exportMap = {
  ...runtimeSymbols,
  RunState: "RUNSTATE", RootSP: "ROOTSP", RootIX: "ROOTIX",
  StateEnd: "STATEEND", RunReady: "RUNREADY",
};
const definitions = {
  RuntimeProofServices: 0,
  RuntimePacketGateway: 1,
  AggregateCallSlices: 1,
  TargetStreamingOutput: 0,
};

function hexWord(value, name) {
  if (!Number.isInteger(value) || value < 0 || value > 0xffff) {
    throw new RangeError(`Native runtime ${name} is outside 0..65535`);
  }
  return `$${value.toString(16).padStart(4, "0")}`;
}

function contextSource(context) {
  return `RTORIGIN EQU ${hexWord(context.runtimeBase, "runtimeBase")}
RTWRBASE EQU ${hexWord(context.writableStateBase, "writableStateBase")}
RTDBASE EQU ${hexWord(context.programDataBase, "programDataBase")}
RTDCAP EQU ${hexWord(context.programDataCapacity, "programDataCapacity")}
RTROBASE EQU ${hexWord(context.readOnlyBase, "readOnlyBase")}
RTROCAP EQU ${hexWord(context.readOnlyCapacity, "readOnlyCapacity")}
RTPKTVEC EQU ${hexWord(context.packetService, "packetService")}
RTSTATE EQU RTWRBASE
RUNSTATE EQU RTSTATE+$00
RTTRPNO EQU RTSTATE+$01
RTTRPRTN EQU RTSTATE+$02
RTTRPOFF EQU RTSTATE+$03
RTTRPERR EQU RTSTATE+$05
RTDEPTH EQU RTSTATE+$06
RTACTLIM EQU RTSTATE+$07
RTSCALAR EQU RTSTATE+$08
RTBANK EQU RTSCALAR
RTACTMEM EQU RTSTATE+$09
RTACTCAP EQU 8
ROOTSP EQU RTACTMEM+RTACTCAP
ROOTIX EQU ROOTSP+2
RTFARMEM EQU ROOTIX+2
RTFARCAP EQU RTACTCAP*2
RTDBWORD EQU RTFARMEM+RTFARCAP
RTDCWORD EQU RTDBWORD+2
STATEEND EQU RTDCWORD+2
RUNREADY EQU 1
RTSUCC EQU 2
RTTRAP EQU 3
RORDATA EQU RTROBASE
RORDCAP EQU RTROCAP
RCEQ EQU 0
RCNE EQU 1
RCLT EQU 2
RCLE EQU 3
RCGT EQU 4
RCGE EQU 5
`;
}

export async function assembleNativeRuntime(context) {
  const contextBytes = contextSource(context);
  const root = await mkdtemp(path.join(os.tmpdir(), "nucleus-native-runtime-"));
  try {
    await Promise.all([
      ...["loop-z80-runtime.asm", "nucleus-runtime-identity.asmi"].map(name =>
        copyFile(new URL(name, assemblyDirectory), path.join(root, name))),
      writeFile(path.join(root, "context.asm"), contextBytes),
      writeFile(path.join(root, "origin.asm"), "ORG RTORIGIN\nRTSTART:\n"),
      writeFile(path.join(root, "entry.asm"),
        '%INCLUDE "context.asm"\n%INCLUDE "origin.asm"\n%INCLUDE "loop-z80-runtime.asm"\nRTEND:\n'),
    ]);
    return await assembleNativeSource({
      root, entry: "entry.asm", definitions, exportMap,
      target: { start: context.runtimeBase, capacity: Math.min(0xffff, 0x10000 - context.runtimeBase) },
      requiredExports: [
        "RuntimeCodeStart", "RuntimeCodeEnd", "NucleusRuntimeExpectedLength",
        "NucleusRuntimeIdentity", "StateBase", "StateEnd",
      ],
    });
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

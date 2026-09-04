// Native ATOM runs a Z80 instruction loop. Promise.all alone cannot run those
// CPU-bound loops concurrently; limit build workers to three resident images.
import { Worker, isMainThread, parentPort, workerData } from "node:worker_threads";
import path from "node:path";

if (!isMainThread) {
  const { assembleImageSource } = await import("./assemble-image-source.mjs");
  const result = await assembleImageSource(workerData.source);
  console.log(`ATOM assembled ${path.basename(workerData.source)}`);
  parentPort.postMessage(result);
}

let active = 0;
const waiting = [];

export async function assembleImageInWorker(source) {
  if (active < 3) active++;
  else await new Promise(resolve => waiting.push(resolve));
  try {
    return await new Promise((resolve, reject) => {
      const worker = new Worker(new URL(import.meta.url), { workerData: { source }, execArgv: [] });
      let received = false, image;
      worker.once("message", result => { received = true; image = result; });
      worker.once("error", reject);
      worker.once("exit", code => {
        if (code === 0 && received) resolve(image);
        else reject(new Error(`ATOM worker failed (status ${code}): ${source}`));
      });
    });
  } finally {
    if (waiting.length) waiting.shift()();
    else active--;
  }
}

import { describe, expect, it } from "vitest";

import { NativeRetainedNameStore } from "../src/native-retained-names.js";

const retained = (text: string, part = 1, offset = 0) => ({
  bytes: new TextEncoder().encode(text),
  part,
  offset,
});

describe("native retained-name store", () => {
  it("accepts the published 1024-entry boundary and rejects entry 1025", () => {
    const store = new NativeRetainedNameStore();
    for (let index = 0; index < 1_024; index += 1) {
      expect(store.retain(retained("x", 1, index))).toBe(index + 1);
    }
    expect(store.usage()).toEqual({ entries: 1_024, bytes: 1_024 });
    expect(() => store.retain(retained("x"))).toThrow(
      "native retained-name capacity exceeded",
    );
    expect(store.usage()).toEqual({ entries: 1_024, bytes: 1_024 });
  });

  it("accepts the published 65535-byte boundary and rejects the next byte", () => {
    const store = new NativeRetainedNameStore();
    const block = "x".repeat(255);
    for (let index = 0; index < 257; index += 1) {
      store.retain(retained(block, 1, index * 255));
    }
    expect(store.usage()).toEqual({ entries: 257, bytes: 65_535 });
    expect(() => store.retain(retained("x"))).toThrow(
      "native retained-name capacity exceeded",
    );
    expect(store.usage()).toEqual({ entries: 257, bytes: 65_535 });
  });

  it("accepts exact entry and byte capacity, then rejects the first excess atomically", () => {
    const store = new NativeRetainedNameStore(2, 3);
    expect(store.retain(retained("a"))).toBe(1);
    expect(store.retain(retained("bc", 2, 4))).toBe(2);
    expect(store.usage()).toEqual({ entries: 2, bytes: 3 });

    expect(() => store.retain(retained("d"))).toThrow(
      "native retained-name capacity exceeded",
    );
    expect(store.usage()).toEqual({ entries: 2, bytes: 3 });
    expect(store.get(2)).toEqual(retained("bc", 2, 4));
  });

  it("rejects byte overflow before entry overflow and resets handles with the generation", () => {
    const store = new NativeRetainedNameStore(3, 2);
    expect(store.retain(retained("ab"))).toBe(1);
    expect(() => store.retain(retained("c"))).toThrow(
      "native retained-name capacity exceeded",
    );
    expect(store.usage()).toEqual({ entries: 1, bytes: 2 });

    store.clear();
    expect(store.usage()).toEqual({ entries: 0, bytes: 0 });
    expect(store.get(1)).toBeUndefined();
    expect(store.retain(retained("c"))).toBe(1);
  });

  it("treats a different valid length as unequal rather than a host failure", () => {
    const store = new NativeRetainedNameStore();
    const handle = store.retain(retained("alpha"));

    expect(store.compare(handle, new TextEncoder().encode("alph"))).toBe(
      "unequal",
    );
    expect(store.compare(handle, new TextEncoder().encode("alpha"))).toBe(
      "equal",
    );
    expect(store.compare(handle + 1, new TextEncoder().encode("alpha"))).toBe(
      "invalid",
    );
  });
});

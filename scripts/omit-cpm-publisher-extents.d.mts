/** Private output metadata filter. Assembly input and generation are unchanged. */
export function omitCpmPublisherExtents<T extends {
  readonly symbols: Readonly<Record<string, number>>;
  readonly addresses: Readonly<Record<string, number>>;
}>(result: T): Omit<T, "symbols"> & {
  readonly symbols: Readonly<Record<string, number>>;
};

# Import-directed project example

This project exercises the complete standalone Node pipeline: `main.nu`
imports `model.nu`, the host orders both files, and the Z80 compiler publishes
NOBJ, Intel HEX, and D8 output.

From the Nucleus repository:

```bash
node dist/cli.js build --project examples/import-project/nucleus-project.json
```

The output appears in `examples/import-project/build/`.

`nucleus-target.json` uses synthetic service addresses. It proves target
validation and artifact generation but does not describe a physical machine.
A launchable machine profile must replace every service address with a callable
implementation supplied by its monitor, operating system, or emulator.

The repository's `npm run check:package` gate supplies small headless terminal
stubs, enters the NOBJ entry address through Debug80 Runtime, and verifies that
the example stores `7` in its program variable before reaching success.

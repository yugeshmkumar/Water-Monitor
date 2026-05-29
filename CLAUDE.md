# Water Monitor — Project Rules for Claude

## Documentation Placement (STRICT)

**`README.md` is the ONLY documentation file permitted in the project root.**

All other documentation must be placed inside `docs/` using the subfolder that matches its scope:

| Content type | Target subfolder |
|---|---|
| System architecture, design decisions | `docs/architecture/` |
| Firmware build, flash, dev guides | `docs/firmware/` |
| Hardware wiring, BOM, datasheets | `docs/hardware/` |
| iOS app design, API contracts | `docs/ios-app/` |
| Android app | `docs/android-app/` |
| API reference | `docs/api/` |

**Enforcement:**
- Never create `.md` or any other documentation file directly in the project root.
- Never create documentation files in `firmware/`, `os-app/`, or any source subdirectory.
- If a relevant `docs/` subfolder does not exist yet, create it before writing the file.
- This rule applies to every document: changelogs, ADRs, guides, references, and planning notes.

## Architecture File Maintenance (STRICT)

**`docs/architecture/ARCHITECTURE.md` must be kept up to date at all times.**

After every meaningful code change, update it to reflect the current state:

- Adding a new source file → add it to the relevant file tree or module list
- Removing or renaming a file → remove or rename it in the doc
- Changing a BLE UUID, REST endpoint, or config key → update the corresponding table
- Changing a pin assignment → update the pin map and wiring tables
- Implementing a previously planned item → mark it `[x]` in the checklist
- Architectural decision that differs from what was originally planned → add a note explaining why

Do not defer architecture updates to "later". Update them in the same commit.

## General Project Rules

- Phase 1 only: sensor unit + iOS app. Do not scaffold Phase 2 (motor controller) until Phase 1 is tested and stable.
- GPIO3 and GPIO14 are RF switch lines on the XIAO ESP32-C6. They must never be used as I/O.
- All inter-task shared state lives in `gState` (defined in `src/state.h`). Do not create additional global state structs.
- All NVS config goes through the `Config` class (`src/config.h`). Do not call `Preferences` directly from other modules.

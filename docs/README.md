# Water Monitor Documentation

**Current Phase:** Phase 1 (Hardware + Firmware)  
**Status:** Active Development

---

## Quick Navigation

### 🔨 Phase 1: Sensor Unit (NOW)

**Start here for Phase 1 hardware/firmware:**

1. **[ARCHITECTURE.md](architecture/ARCHITECTURE.md)** — System overview + SR04M-2 sensor pipeline
2. **[DESIGN_DECISIONS.md](architecture/DESIGN_DECISIONS.md)** — Approved design decisions (TVS, WiFi refactor)
3. **[DESIGN_REVIEW_REV_G.md](architecture/DESIGN_REVIEW_REV_G.md)** — Technical deep-dive (all components)
4. **[IMPLEMENTATION_CHECKLIST.md](architecture/IMPLEMENTATION_CHECKLIST.md)** — Phase 1B–1F roadmap with go/no-go gates

#### Hardware Specification
- **[HARDWARE_REV_G.md](hardware/HARDWARE_REV_G.md)** — Complete hardware specification
- **[BOM_PROTOTYPE.md](hardware/BOM_PROTOTYPE.md)** — Prototype build (what to populate, what to DNP)
- **[BOM_PRODUCTION.md](hardware/BOM_PRODUCTION.md)** — Production build (Phase 1F, with ESD)
- **[SENSOR_SELECTION_RATIONALE.md](hardware/SENSOR_SELECTION_RATIONALE.md)** — Why SR04M-2 vs JSN-SR04T

#### Firmware
- **[firmware/build-and-flash.md](firmware/build-and-flash.md)** — Build and flashing guide

---

### 📱 Phase 2+: iOS App & Cloud (FUTURE)

**For reference (not active in Phase 1):**

- **docs/api/** — Cloud API specifications (Phase 2A+)
- **docs/guides/ios/** — iOS app implementation guides (Phase 2+)

---

## Documentation Structure

```
docs/
├── README.md                           ← You are here
│
├── architecture/                       ← Design decisions & specs
│   ├── ARCHITECTURE.md                 (System overview, updated for SR04M-2)
│   ├── DESIGN_DECISIONS.md             (TVS + WiFi decisions)
│   ├── DESIGN_REVIEW_REV_G.md          (Technical review, all components)
│   ├── IMPLEMENTATION_CHECKLIST.md     (Phase 1B–1F roadmap)
│   ├── REQUIREMENTS.md                 (Phase 2 specs, reference only)
│   ├── IMPLEMENTATION_TODO.md          (Phase 2 tasks, reference only)
│   └── CLOUD_PERFORMANCE_ANALYSIS.md   (Phase 2 analysis, reference only)
│
├── hardware/                           ← Hardware specification & BOM
│   ├── HARDWARE_REV_G.md               (Production spec)
│   ├── BOM_PROTOTYPE.md                (Prototype: what to populate/DNP)
│   ├── BOM_PRODUCTION.md               (Production: all components)
│   └── SENSOR_SELECTION_RATIONALE.md   (SR04M-2 vs JSN-SR04T decision)
│
├── firmware/                           ← Firmware guides
│   └── build-and-flash.md              (Build & flash instructions)
│
├── api/                                ← Cloud API (Phase 2+, reference)
│   └── PHASE_2A_IMPLEMENTATION.md
│
└── guides/                             ← Implementation guides
    └── ios/                            ← iOS app guides (Phase 2+, reference)
        ├── README.md
        ├── PROJECT_STRUCTURE.md        (iOS project structure)
        ├── QUICK_START.md
        ├── IMPLEMENTATION_GUIDE.md
        ├── DEPLOYMENT_CHECKLIST.md
        ├── SUMMARY.md
        ├── CHANGELOG.md
        ├── ACTION_ITEMS.md
        ├── INDEX.md
        ├── STATUS_CHECK.md
        └── POST_CRASH_STATUS.md
```

---

## Current Phase Status

| Phase | Component | Status | Next |
|-------|-----------|--------|------|
| **1B** | Pre-Layout | ⏳ Ready | Verify SMBJ5V0A sourcing |
| **1C** | Prototype Build | ⏳ Awaiting PCB | Electrical tests (6 items) |
| **1D** | Firmware Refactor | ⏳ After 1C | WiFi non-blocking + offline-first |
| **1E** | Environmental Testing | ⏳ After 1D | 72h soak + humidity tests |
| **1F** | Production | ⏳ After 1E | Populate ESD (D3, D4) |

---

## Key Design Decisions (Phase 1)

1. **TVS Thermal Derating** → Replace P6KE6.8A with SMBJ5V0A (better derating for urban roof environment)
2. **WiFi Non-Blocking** → Refactor to background reconnect (offline-first, 1–2 day WiFi outages)
3. **Sensor Selection** → SR04M-2 (triggered UART) over JSN-SR04T (pulse-width)

See [DESIGN_DECISIONS.md](architecture/DESIGN_DECISIONS.md) for full rationale.

---

## How to Use This Documentation

### If you're building the prototype (Phase 1C)
1. Read [HARDWARE_REV_G.md](hardware/HARDWARE_REV_G.md) for overview
2. Use [BOM_PROTOTYPE.md](hardware/BOM_PROTOTYPE.md) for component list (clear ✅ YES / ❌ DNP)
3. Follow assembly instructions in HARDWARE_REV_G.md §7
4. Run validation tests in HARDWARE_REV_G.md §8

### If you're reviewing the design
1. Start with [DESIGN_DECISIONS.md](architecture/DESIGN_DECISIONS.md) for approved decisions
2. Read [DESIGN_REVIEW_REV_G.md](architecture/DESIGN_REVIEW_REV_G.md) for technical justification (10 sections)
3. Check cross-references in [ARCHITECTURE.md](architecture/ARCHITECTURE.md)

### If you're implementing firmware
1. Check [ARCHITECTURE.md](architecture/ARCHITECTURE.md) §"Firmware Sensor Pipeline" for SR04M-2 flow
2. Review [firmware/build-and-flash.md](firmware/build-and-flash.md) for build setup
3. Follow Phase 1D in [IMPLEMENTATION_CHECKLIST.md](architecture/IMPLEMENTATION_CHECKLIST.md)

### If you're looking at Phase 2 (Cloud/iOS)
1. See [docs/api/](api/) for cloud API specs
2. See [docs/guides/ios/](guides/ios/) for iOS implementation
3. Note: Phase 2 not active in current phase, kept for reference

---

**Last Updated:** 2026-06-07  
**Maintained by:** Claude Code (Haiku 4.5)

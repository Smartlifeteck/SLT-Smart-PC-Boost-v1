# SLT Smart PC Boost — Public Roadmap

## Phase 1: Safety & Open-Source Foundation (Completed)
- [x] Eliminate hardcoded credentials and enforce salted PBKDF2 local PIN storage.
- [x] Enforce truthful hardware telemetry (`Not reported`) and explicit QC pass gates.
- [x] Protect BitLocker volumes, external Panther Unattend files, Prefetch, and Windows Update caches.
- [x] Add typed registry backup/rollback and preserve failed rollback entries.
- [x] Establish Pester 5 static safety tests, repository integrity tests, and Windows GitHub Actions CI.
- [x] Publish under OSI-approved MIT License with full community health documentation.

## Phase 2: Live Hardware Validation & Rollback Completeness (Next)
- [ ] Complete automated & manual Windows 10/11 hardware test matrix (NVMe/SATA, battery/desktop, standard user/admin).
- [ ] Implement full snapshot & rollback capture for service startup types, scheduled tasks, and power plans.
- [ ] Resolve all `PSScriptAnalyzer` warnings and expand Pester unit test coverage with mocked CIM/WMI layers.
- [ ] Publish checksum-verified GitHub Releases with clear upgrade notes.

## Phase 3: Educational Expansion & Community Ecosystem (Planned)
- [ ] Add interactive "Learning Mode" tooltips explaining what each Windows command, registry key, and diagnostic check does.
- [ ] Support multilingual UI packs (English, Urdu, Arabic) via external JSON string tables.
- [ ] Create contributor starter guides and "Good First Issue" tracks for university students and junior IT technicians.

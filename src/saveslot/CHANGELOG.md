# v2.8.0 (Thu Aug 13 2026)

#### 🚀 Enhancement

- feat(saveslot): make save slot and datastore commands work on absent players [#799](https://github.com/Quenty/NevermoreEngine/pull/799) ([@Quenty](https://github.com/Quenty))
- feat: Fix a lot of cmdr issues ([@Quenty](https://github.com/Quenty))
- feat(saveslot): make every save slot command work on players who are not in this server ([@Quenty](https://github.com/Quenty))
- feat(saveslot): take playerIds on every save slot command ([@Quenty](https://github.com/Quenty))

#### 🐛 Bug Fix

- fix: Transfers now are more secure ([@Quenty](https://github.com/Quenty))
- chore(saveslot): skip a nil slot line instead of dropping it silently ([@Quenty](https://github.com/Quenty))
- fix(datastore): release a borrowed session even when the caller is torn down ([@Quenty](https://github.com/Quenty))
- chore(saveslot): type check the new specs under strict mode ([@Quenty](https://github.com/Quenty))
- refactor(saveslot): move the slot system off the player into HasSaveSlotsDataStore ([@Quenty](https://github.com/Quenty))

#### Authors: 1

- James Onnen ([@Quenty](https://github.com/Quenty))

---

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## [2.7.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.7.0...@quenty/saveslot@2.7.1) (2026-08-10)

### Bug Fixes

- Carry accrued playtime onto a copied slot ([90be930](https://github.com/Quenty/NevermoreEngine/commit/90be9301629ee967f52be7ad947f3f1568b48f29))

# [2.7.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.6.3...@quenty/saveslot@2.7.0) (2026-08-10)

### Bug Fixes

- Fix save slots ([579c587](https://github.com/Quenty/NevermoreEngine/commit/579c587ebfadaedaab91e774f8441d78a8d6fe99))
- **nevermore-cli:** make the watch context tests independent of the host ([453f415](https://github.com/Quenty/NevermoreEngine/commit/453f415460db72eec511ecbea34434c82afb61c8))

## [2.6.3](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.6.2...@quenty/saveslot@2.6.3) (2026-08-10)

**Note:** Version bump only for package @quenty/saveslot

## [2.6.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.6.1...@quenty/saveslot@2.6.2) (2026-07-30)

### Bug Fixes

- **saveslot:** give the slots-load continuation a consistent return so the type check passes ([43dd6e7](https://github.com/Quenty/NevermoreEngine/commit/43dd6e7a7bc1dc87f3c2e2936f4c05f064edba2b))
- **saveslot:** guard the import read, and reject rather than fulfil nil when destroyed ([14d551b](https://github.com/Quenty/NevermoreEngine/commit/14d551b7adebae6780cac69b57676328c30ab821))
- **saveslot:** guard the slots load against settling after the player left ([d274aee](https://github.com/Quenty/NevermoreEngine/commit/d274aee8f135fa0ae3eaccf29c121acda2ea0be6))
- **saveslot:** guard the transferable-ephemeral read, and pin the seeded slot ([2b76762](https://github.com/Quenty/NevermoreEngine/commit/2b76762320468ba9c0d496857bff5c34b87e1c39))

## [2.6.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.6.0...@quenty/saveslot@2.6.1) (2026-07-30)

**Note:** Version bump only for package @quenty/saveslot

# [2.6.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.5.0...@quenty/saveslot@2.6.0) (2026-07-28)

### Features

- **saveslot:** let save-slot commands address ephemeral slots and persist them ([17fd930](https://github.com/Quenty/NevermoreEngine/commit/17fd930afdfa259eca552072e9a15bfa29f0afe7))

# [2.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.4.0...@quenty/saveslot@2.5.0) (2026-07-28)

**Note:** Version bump only for package @quenty/saveslot

# [2.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.3.0...@quenty/saveslot@2.4.0) (2026-07-27)

### Features

- **saveslot:** run consumer callbacks before a slot is selected ([#758](https://github.com/Quenty/NevermoreEngine/issues/758)) ([f2d8c1b](https://github.com/Quenty/NevermoreEngine/commit/f2d8c1b5e5108ff85df98749a35a54706e77ae9a))

# [2.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.2.3...@quenty/saveslot@2.3.0) (2026-07-27)

### Features

- **saveslot:** save slot commands take a players argument ([#756](https://github.com/Quenty/NevermoreEngine/issues/756)) ([724b9b4](https://github.com/Quenty/NevermoreEngine/commit/724b9b40e4acdb4700d841e514e578332c60e155))

## [2.2.3](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.2.2...@quenty/saveslot@2.2.3) (2026-07-27)

**Note:** Version bump only for package @quenty/saveslot

## [2.2.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.2.1...@quenty/saveslot@2.2.2) (2026-07-26)

**Note:** Version bump only for package @quenty/saveslot

## [2.2.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.2.0...@quenty/saveslot@2.2.1) (2026-07-25)

**Note:** Version bump only for package @quenty/saveslot

# [2.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.1.0...@quenty/saveslot@2.2.0) (2026-07-25)

### Bug Fixes

- Ephemeral save slots replicate to the client ([457f3e9](https://github.com/Quenty/NevermoreEngine/commit/457f3e95e1c9f6714e027c0e96754f646ee7f6a5))

### Features

- Export other people's save slots for debugging ([d5600ae](https://github.com/Quenty/NevermoreEngine/commit/d5600ae650d0af21dbd0c26d24f7cf7e292489b9))

# [2.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@2.0.0...@quenty/saveslot@2.1.0) (2026-07-24)

**Note:** Version bump only for package @quenty/saveslot

# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.15.0...@quenty/saveslot@2.0.0) (2026-07-24)

### Features

- **saveslot:** save slot export/import + cross-session transfer ([#748](https://github.com/Quenty/NevermoreEngine/issues/748)) ([3ef4fe0](https://github.com/Quenty/NevermoreEngine/commit/3ef4fe0024a6036f396babfc292099041bdf56d6))

# [1.15.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.14.2...@quenty/saveslot@1.15.0) (2026-07-24)

**Note:** Version bump only for package @quenty/saveslot

## [1.14.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.14.1...@quenty/saveslot@1.14.2) (2026-07-24)

### Bug Fixes

- **saveslot:** bind the client HasSaveSlots for a mocked local player ([a1d94e6](https://github.com/Quenty/NevermoreEngine/commit/a1d94e6d996f49f0e595d90169eef5c9ae49d719))

## [1.14.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.14.0...@quenty/saveslot@1.14.1) (2026-07-23)

### Bug Fixes

- **saveslot:** selection chain consumes loads that settle after the player leaves ([f8716a3](https://github.com/Quenty/NevermoreEngine/commit/f8716a37028db5474578ccad1b0d9aa811edd64c))

# [1.14.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.13.1...@quenty/saveslot@1.14.0) (2026-07-23)

**Note:** Version bump only for package @quenty/saveslot

## [1.13.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.13.0...@quenty/saveslot@1.13.1) (2026-07-23)

**Note:** Version bump only for package @quenty/saveslot

# [1.13.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.12.0...@quenty/saveslot@1.13.0) (2026-07-23)

### Features

- Add baseline player-mock and support across Nevermore for mocked players. ([567d121](https://github.com/Quenty/NevermoreEngine/commit/567d121ffc014b42391554088189a1a6296dda83))

# [1.12.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.11.0...@quenty/saveslot@1.12.0) (2026-07-22)

**Note:** Version bump only for package @quenty/saveslot

# [1.11.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.10.0...@quenty/saveslot@1.11.0) (2026-07-21)

### Bug Fixes

- **saveslot:** satisfy luau-lsp on ephemeral slot code ([12ac92b](https://github.com/Quenty/NevermoreEngine/commit/12ac92b5ecabc391b1cb716c16a3ee7113d7175f))

### Features

- Add ephemeral save slots ([16bd91b](https://github.com/Quenty/NevermoreEngine/commit/16bd91b87943a65165245cba90d44274585903d6))

# [1.10.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.9.0...@quenty/saveslot@1.10.0) (2026-07-21)

**Note:** Version bump only for package @quenty/saveslot

# [1.9.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.8.0...@quenty/saveslot@1.9.0) (2026-07-21)

### Bug Fixes

- Resolve luau-lsp and moonwave lint failures ([286e352](https://github.com/Quenty/NevermoreEngine/commit/286e3527b52a86639fc0485359141d7805b3fefa))

### Features

- Add a method to reset active slots ([f353b3e](https://github.com/Quenty/NevermoreEngine/commit/f353b3e579651bd6dcabf158f5d2c8943725ccc5))
- Add duplication to save slots package ([27288e4](https://github.com/Quenty/NevermoreEngine/commit/27288e4b8cd6d29a93c2807c364f13ea03ad5fee))
- Add save slot tracking data ([34ce611](https://github.com/Quenty/NevermoreEngine/commit/34ce61104410a96be2d23b21db6485b0ea428548))

# [1.8.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.7.0...@quenty/saveslot@1.8.0) (2026-07-20)

**Note:** Version bump only for package @quenty/saveslot

# [1.7.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.6.0...@quenty/saveslot@1.7.0) (2026-07-20)

### Bug Fixes

- Strict typing on tests ([efbc458](https://github.com/Quenty/NevermoreEngine/commit/efbc45882fac95755ea4ff4e007c5f71bedebf6f))

### Features

- Integrate teleport data service directly into save slots for cross-game continuation ([ffa7496](https://github.com/Quenty/NevermoreEngine/commit/ffa7496047b80a82623440221c019fdfe09e31ea))
- **saveslot:** add last-active replication and continue/new-game/wipe APIs ([f5f4045](https://github.com/Quenty/NevermoreEngine/commit/f5f4045b5849482f95a780fce5ba298682afe173))
- Support deselecting the active save slot ([d7da61d](https://github.com/Quenty/NevermoreEngine/commit/d7da61d80742f56987e2cf69e7fb108e9b18fa2d))
- Support unbounded save slots via SetUnlimitedSlots ([ec34e9a](https://github.com/Quenty/NevermoreEngine/commit/ec34e9aa6c9fce0cab4dd4f6f88780581e3cd1e5))

# [1.6.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.5.0...@quenty/saveslot@1.6.0) (2026-07-18)

**Note:** Version bump only for package @quenty/saveslot

# [1.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.4.1...@quenty/saveslot@1.5.0) (2026-07-18)

**Note:** Version bump only for package @quenty/saveslot

## [1.4.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.4.0...@quenty/saveslot@1.4.1) (2026-07-15)

**Note:** Version bump only for package @quenty/saveslot

# [1.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.3.0...@quenty/saveslot@1.4.0) (2026-07-15)

**Note:** Version bump only for package @quenty/saveslot

# [1.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.2.1...@quenty/saveslot@1.3.0) (2026-07-14)

**Note:** Version bump only for package @quenty/saveslot

## [1.2.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.2.0...@quenty/saveslot@1.2.1) (2026-06-20)

### Bug Fixes

- Flush deletions ([ad6c821](https://github.com/Quenty/NevermoreEngine/commit/ad6c821ac21b12db120c01e02d4f2a95d3c10616))

# [1.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.1.2...@quenty/saveslot@1.2.0) (2026-06-10)

### Features

- Optionally keep slot active between teleports ([ca5c71f](https://github.com/Quenty/NevermoreEngine/commit/ca5c71fc85b6ac9c61df03c28489c025280902fa))

## [1.1.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.1.1...@quenty/saveslot@1.1.2) (2026-06-03)

**Note:** Version bump only for package @quenty/saveslot

## [1.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/saveslot@1.1.0...@quenty/saveslot@1.1.1) (2026-05-30)

**Note:** Version bump only for package @quenty/saveslot

# 1.1.0 (2026-05-29)

### Features

- Save slots ([55c926a](https://github.com/Quenty/NevermoreEngine/commit/55c926a29d6e304971b8d0123bb3a684be496899))

# v1.1.0 (Fri May 29 2026)

#### 🚀 Enhancement

- feat: Save slots [#692](https://github.com/Quenty/NevermoreEngine/pull/692) ([@alex-y-z](https://github.com/alex-y-z))
- feat: Save slots ([@alex-y-z](https://github.com/alex-y-z))

#### 🐛 Bug Fix

- chore: Docs link ([@alex-y-z](https://github.com/alex-y-z))
- chore: Rename store key ([@alex-y-z](https://github.com/alex-y-z))
- refactor: Cleaner state/lifetime management ([@alex-y-z](https://github.com/alex-y-z))
- refactor: Reactive summaries ([@alex-y-z](https://github.com/alex-y-z))
- refactor: Type SlotId ([@alex-y-z](https://github.com/alex-y-z))
- chore: Set command feedback ([@alex-y-z](https://github.com/alex-y-z))
- refactor: Switch to GUIDs, default to root store ([@alex-y-z](https://github.com/alex-y-z))
- chore: Lint ([@alex-y-z](https://github.com/alex-y-z))

#### Authors: 1

- Alex Turner ([@alex-y-z](https://github.com/alex-y-z))

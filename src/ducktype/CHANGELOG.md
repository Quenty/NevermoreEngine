# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

# [5.9.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.8.4...@quenty/ducktype@5.9.0) (2025-05-10)

**Note:** Version bump only for package @quenty/ducktype





## [5.8.4](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.8.3...@quenty/ducktype@5.8.4) (2025-04-10)

**Note:** Version bump only for package @quenty/ducktype





## [5.8.3](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.8.1...@quenty/ducktype@5.8.3) (2025-04-07)


### Bug Fixes

* Add types to packages ([2374fb2](https://github.com/Quenty/NevermoreEngine/commit/2374fb2b043cfbe0e9b507b3316eec46a4e353a0))
* Bump package versions for republishing ([ba47c62](https://github.com/Quenty/NevermoreEngine/commit/ba47c62e32170bf74377b0c658c60b84306dc294))





## [5.8.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.8.1...@quenty/ducktype@5.8.2) (2025-04-07)


### Bug Fixes

* Add types to packages ([2374fb2](https://github.com/Quenty/NevermoreEngine/commit/2374fb2b043cfbe0e9b507b3316eec46a4e353a0))





## [5.8.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.8.0...@quenty/ducktype@5.8.1) (2025-03-21)

**Note:** Version bump only for package @quenty/ducktype





# [5.8.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.7.1...@quenty/ducktype@5.8.0) (2025-02-18)

**Note:** Version bump only for package @quenty/ducktype





## [5.7.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.7.0...@quenty/ducktype@5.7.1) (2024-11-04)

**Note:** Version bump only for package @quenty/ducktype





# [5.7.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.6.0...@quenty/ducktype@5.7.0) (2024-10-06)

**Note:** Version bump only for package @quenty/ducktype





# [5.6.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.5.0...@quenty/ducktype@5.6.0) (2024-10-04)

**Note:** Version bump only for package @quenty/ducktype





# [5.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.4.0...@quenty/ducktype@5.5.0) (2024-09-25)

**Note:** Version bump only for package @quenty/ducktype





# [5.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.3.0...@quenty/ducktype@5.4.0) (2024-09-12)

**Note:** Version bump only for package @quenty/ducktype





# [5.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.2.0...@quenty/ducktype@5.3.0) (2024-05-09)


### Bug Fixes

* Fix .package-lock.json replicating in packages ([75d0efe](https://github.com/Quenty/NevermoreEngine/commit/75d0efeef239f221d93352af71a5b3e930ec23c5))





# [5.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.1.0...@quenty/ducktype@5.2.0) (2024-04-27)

**Note:** Version bump only for package @quenty/ducktype





# [5.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@5.0.0...@quenty/ducktype@5.1.0) (2024-03-09)

**Note:** Version bump only for package @quenty/ducktype





# [5.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@4.0.0...@quenty/ducktype@5.0.0) (2024-02-14)

**Note:** Version bump only for package @quenty/ducktype





# [4.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@3.0.0...@quenty/ducktype@4.0.0) (2024-02-13)

**Note:** Version bump only for package @quenty/ducktype





# [3.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@2.2.0...@quenty/ducktype@3.0.0) (2024-02-13)


### Features

* New loader (breaking changes), fixing loader issues  ([#439](https://github.com/Quenty/NevermoreEngine/issues/439)) ([3534345](https://github.com/Quenty/NevermoreEngine/commit/353434522918812953bd9f13fece73e27a4d034d))


### BREAKING CHANGES

* Standard loader

Adds new loader version which replicates full structure instead of some partial structure. This allows us to have hot-reloading (in the future), as well as generally do less computation, handle dependencies more carefully, and other changes.

This means you'll need to change you how require client-side modules, as we export a simple `loader` module instead of all modules available.

Signed-off-by: James Onnen <jonnen0@gmail.com>

* fix: Fix missing dependency in ResetService

* feat: Add RxPhysicsUtils.observePartMass

* fix: Fix package discovery for games

* feat: Add UIAlignmentUtils.verticalToHorizontalAlignment(verticalAlignment) and UIAlignmentUtils.horizontalToVerticalAlignment(horizontalAlignment)

* feat: AdorneeData:InitAttributes() does not require data as a  secondparameter

* ci: Upgrade to new rojo 7.4.0

* fix: Update loader to handle hoarcekat properly

* docs: Fix spacing in Maid

* fix: Add new ragdoll constants

* fix: Compress influxDB sends

* style: Errors use string.format

* fix: Handle motor animations

* ci: Upgrade rojo version

* feat!: Maid no longer is includd in ValueObject.Changed event

* docs: Fix docs





# [2.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@2.1.0...@quenty/ducktype@2.2.0) (2024-01-08)

**Note:** Version bump only for package @quenty/ducktype





# [2.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@2.0.0...@quenty/ducktype@2.1.0) (2023-12-14)

**Note:** Version bump only for package @quenty/ducktype





# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/ducktype@1.1.0...@quenty/ducktype@2.0.0) (2023-10-11)

**Note:** Version bump only for package @quenty/ducktype





# 1.1.0 (2023-08-23)


### Features

* Add DuckType package which allows for easy ducktyping interface checkers to be made ([14874e8](https://github.com/Quenty/NevermoreEngine/commit/14874e8f4b0789e203bd60f418d70510fac950e9))





# v1.1.0 (Wed Aug 23 2023)

:tada: This release contains work from a new contributor! :tada:

Thank you, Max Bacon ([@max-bacon](https://github.com/max-bacon)), for all your work!

#### 🚀 Enhancement

- users/quenty/pack [#405](https://github.com/Quenty/NevermoreEngine/pull/405) ([@Quenty](https://github.com/Quenty))
- feat: Add DuckType package which allows for easy ducktyping interface checkers to be made ([@Quenty](https://github.com/Quenty))

#### 🐛 Bug Fix

- Fix DataStore.lua documentation type [#372](https://github.com/Quenty/NevermoreEngine/pull/372) ([@max-bacon](https://github.com/max-bacon))

#### Authors: 2

- James Onnen ([@Quenty](https://github.com/Quenty))
- Max Bacon ([@max-bacon](https://github.com/max-bacon))

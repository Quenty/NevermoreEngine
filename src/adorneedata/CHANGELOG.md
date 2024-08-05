# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

# [7.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@7.3.0...@quenty/adorneedata@7.4.0) (2024-05-18)


### Features

* Add AdorneeData docs and ability to use indirectly ([8df4e84](https://github.com/Quenty/NevermoreEngine/commit/8df4e844c027ec196476306d472c7c8e4625c53f))





# [7.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@7.2.0...@quenty/adorneedata@7.3.0) (2024-05-09)


### Bug Fixes

* Fix .package-lock.json replicating in packages ([75d0efe](https://github.com/Quenty/NevermoreEngine/commit/75d0efeef239f221d93352af71a5b3e930ec23c5))





# [7.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@7.1.0...@quenty/adorneedata@7.2.0) (2024-04-27)

**Note:** Version bump only for package @quenty/adorneedata





# [7.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@7.0.0...@quenty/adorneedata@7.1.0) (2024-03-09)

**Note:** Version bump only for package @quenty/adorneedata





# [7.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@6.0.0...@quenty/adorneedata@7.0.0) (2024-02-14)

**Note:** Version bump only for package @quenty/adorneedata





# [6.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@5.0.0...@quenty/adorneedata@6.0.0) (2024-02-13)

**Note:** Version bump only for package @quenty/adorneedata





# [5.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@4.0.0...@quenty/adorneedata@5.0.0) (2024-02-13)

**Note:** Version bump only for package @quenty/adorneedata





# [4.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@3.0.0...@quenty/adorneedata@4.0.0) (2024-02-13)


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





# [3.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@2.0.0...@quenty/adorneedata@3.0.0) (2024-01-10)

**Note:** Version bump only for package @quenty/adorneedata





# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@1.3.0...@quenty/adorneedata@2.0.0) (2024-01-08)

**Note:** Version bump only for package @quenty/adorneedata





# [1.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@1.2.0...@quenty/adorneedata@1.3.0) (2024-01-08)


### Bug Fixes

* InitAttributes works on partial data ([a5831f6](https://github.com/Quenty/NevermoreEngine/commit/a5831f6fad116b76717bea3d2bc9d414ce58d874))





# [1.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/adorneedata@1.1.0...@quenty/adorneedata@1.2.0) (2023-12-28)


### Bug Fixes

* Adornee attribute retrieval includes default values ([577691d](https://github.com/Quenty/NevermoreEngine/commit/577691d0bbdf2dbb0809c71dcf733881d74670ba))





# 1.1.0 (2023-12-14)

**Note:** Version bump only for package @quenty/adorneedata





# v1.1.0 (Thu Dec 14 2023)

#### 🚀 Enhancement

- users/quenty/updates [#433](https://github.com/Quenty/NevermoreEngine/pull/433) ([@Quenty](https://github.com/Quenty))

#### 🐛 Bug Fix

- docs: Fix docs and style ([@Quenty](https://github.com/Quenty))
- refactor: Rename AdorneeData to AttributeData ([@Quenty](https://github.com/Quenty))

#### Authors: 1

- James Onnen ([@Quenty](https://github.com/Quenty))

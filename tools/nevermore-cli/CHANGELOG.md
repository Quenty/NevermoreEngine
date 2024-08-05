# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

# [4.2.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@4.1.0...@quenty/nevermore-cli@4.2.0) (2024-05-09)


### Bug Fixes

* Fix .package-lock.json replicating in packages ([75d0efe](https://github.com/Quenty/Nevermore/commit/75d0efeef239f221d93352af71a5b3e930ec23c5))
* update default project to ignore package-lock.json ([6e7f533](https://github.com/Quenty/Nevermore/commit/6e7f533fddee8efb803febad4cc97020b5e59703))





# [4.1.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@4.0.2...@quenty/nevermore-cli@4.1.0) (2024-04-27)


### Bug Fixes

* Patch issues in package ([7f6d2f1](https://github.com/Quenty/Nevermore/commit/7f6d2f1d862d10131bf97368067eed35f4286ea9))





## [4.0.2](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@4.0.1...@quenty/nevermore-cli@4.0.2) (2024-03-27)

**Note:** Version bump only for package @quenty/nevermore-cli





## [4.0.1](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@4.0.0...@quenty/nevermore-cli@4.0.1) (2024-03-09)

**Note:** Version bump only for package @quenty/nevermore-cli





# [4.0.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@3.0.0...@quenty/nevermore-cli@4.0.0) (2024-02-13)


### Bug Fixes

* Fix bootstrap of test environments and loader samples ([441e4a9](https://github.com/Quenty/Nevermore/commit/441e4a90d19fcc203da2fdedc08e532c20d52f99))
* Fix loader require ([5a78e8c](https://github.com/Quenty/Nevermore/commit/5a78e8ceb0df372e4efe1382f9438b51e6c182fa))





# [3.0.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@2.0.0...@quenty/nevermore-cli@3.0.0) (2024-02-13)


### Features

* New loader (breaking changes), fixing loader issues  ([#439](https://github.com/Quenty/Nevermore/issues/439)) ([3534345](https://github.com/Quenty/Nevermore/commit/353434522918812953bd9f13fece73e27a4d034d))


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





# [2.0.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@1.9.0...@quenty/nevermore-cli@2.0.0) (2023-10-11)


### Features

* JSONTranslator can exist on server and generate translation keys (improved ergonomics) ([84b84b5](https://github.com/Quenty/Nevermore/commit/84b84b5587b9cfebad9b9bbda7694ba714188d9c))





# [1.9.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@1.8.1...@quenty/nevermore-cli@1.9.0) (2023-08-23)


### Bug Fixes

* Fix package template ([4b1be5b](https://github.com/Quenty/Nevermore/commit/4b1be5b18267c22b6e01401d4555dd5413f0bf91))
* Update game-template with latest data and ideas ([922ef09](https://github.com/Quenty/Nevermore/commit/922ef0979359beaee1c4cc8085f4e1a209bf793d))


### Features

* Add initial pack command (not finished yet) ([73ac451](https://github.com/Quenty/Nevermore/commit/73ac4519fb9221d95c43e2737f5eb5a3b51b563c))





## [1.8.1](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@1.8.0...@quenty/nevermore-cli@1.8.1) (2023-07-23)


### Bug Fixes

* Escape generated workflow ([#396](https://github.com/Quenty/Nevermore/issues/396)) ([2539ae7](https://github.com/Quenty/Nevermore/commit/2539ae767c5c6b87468a065f142c01006f9444eb))





# [1.8.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@1.7.0...@quenty/nevermore-cli@1.8.0) (2023-06-17)

**Note:** Version bump only for package @quenty/nevermore-cli





# [1.7.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@1.6.0...@quenty/nevermore-cli@1.7.0) (2023-03-31)


### Bug Fixes

* Fix body color serialization and add additional attribute support ([4490c02](https://github.com/Quenty/Nevermore/commit/4490c02d990b9531ef6f4a49340be06a26f1ee52))





# [1.6.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@1.5.1...@quenty/nevermore-cli@1.6.0) (2023-03-06)

**Note:** Version bump only for package @quenty/nevermore-cli





## [1.5.1](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@1.5.0...@quenty/nevermore-cli@1.5.1) (2023-03-05)


### Bug Fixes

* Include gitignore in package version of CLI tools ([24deebc](https://github.com/Quenty/Nevermore/commit/24deebc055fbd5149256d8ff32d3bd658859f7c7))





# [1.5.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@1.4.0...@quenty/nevermore-cli@1.5.0) (2023-02-22)


### Features

* Add github workflow to nevermore init command ([8369044](https://github.com/Quenty/Nevermore/commit/83690442c0914ed8b766348f12f79ea233dae3aa))





# [1.4.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@1.3.0...@quenty/nevermore-cli@1.4.0) (2023-02-21)

**Note:** Version bump only for package @quenty/nevermore-cli





# [1.3.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@1.2.0...@quenty/nevermore-cli@1.3.0) (2022-12-27)


### Bug Fixes

* Ignore distribution from nevermore-cli folder ([02a2297](https://github.com/Quenty/Nevermore/commit/02a2297065478bf0d457463cdf46719fe564efcc))


### Features

* Add ability to generate new Nevermore library packages ([e0e8e44](https://github.com/Quenty/Nevermore/commit/e0e8e44a21692d4c383274985d01a965dcfe389c))





# [1.2.0](https://github.com/Quenty/Nevermore/compare/@quenty/nevermore-cli@1.1.0...@quenty/nevermore-cli@1.2.0) (2022-11-21)


### Features

* Add sublime project generation to game generator ([fc6509d](https://github.com/Quenty/Nevermore/commit/fc6509d3ebcf25dcdddf6637ca55f4aad9c00c7c))





# 1.1.0 (2022-11-19)

**Note:** Version bump only for package @quenty/nevermore-cli





# v1.1.0 (Sat Nov 19 2022)

#### 🚀 Enhancement

- docs: Improve onboarding and more [#308](https://github.com/Quenty/NevermoreEngine/pull/308) ([@Quenty](https://github.com/Quenty))

#### 🐛 Bug Fix

- docs: Update onboarding documentation and tools ([@Quenty](https://github.com/Quenty))

#### Authors: 1

- James Onnen ([@Quenty](https://github.com/Quenty))

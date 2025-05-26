# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

# [3.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@3.4.2...@quenty/symbol@3.5.0) (2025-05-10)

**Note:** Version bump only for package @quenty/symbol





## [3.4.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@3.4.0...@quenty/symbol@3.4.2) (2025-04-07)


### Bug Fixes

* Add types to packages ([2374fb2](https://github.com/Quenty/NevermoreEngine/commit/2374fb2b043cfbe0e9b507b3316eec46a4e353a0))
* Bump package versions for republishing ([ba47c62](https://github.com/Quenty/NevermoreEngine/commit/ba47c62e32170bf74377b0c658c60b84306dc294))





## [3.4.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@3.4.0...@quenty/symbol@3.4.1) (2025-04-07)


### Bug Fixes

* Add types to packages ([2374fb2](https://github.com/Quenty/NevermoreEngine/commit/2374fb2b043cfbe0e9b507b3316eec46a4e353a0))





# [3.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@3.3.0...@quenty/symbol@3.4.0) (2024-12-03)


### Bug Fixes

* Symbols should be newproxy() ([afb4337](https://github.com/Quenty/NevermoreEngine/commit/afb43373b3376a5e5c608eff0ea0a889240081a8))





# [3.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@3.2.0...@quenty/symbol@3.3.0) (2024-11-06)

**Note:** Version bump only for package @quenty/symbol





# [3.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@3.1.0...@quenty/symbol@3.2.0) (2024-10-04)

**Note:** Version bump only for package @quenty/symbol





# [3.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@3.0.0...@quenty/symbol@3.1.0) (2024-05-09)


### Bug Fixes

* Fix .package-lock.json replicating in packages ([75d0efe](https://github.com/Quenty/NevermoreEngine/commit/75d0efeef239f221d93352af71a5b3e930ec23c5))





# [3.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@2.2.0...@quenty/symbol@3.0.0) (2024-02-13)


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





# [2.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@2.1.0...@quenty/symbol@2.2.0) (2023-02-21)

**Note:** Version bump only for package @quenty/symbol





# [2.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@2.0.1...@quenty/symbol@2.1.0) (2022-03-27)

**Note:** Version bump only for package @quenty/symbol





## [2.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@2.0.0...@quenty/symbol@2.0.1) (2021-12-30)

**Note:** Version bump only for package @quenty/symbol





# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/symbol@1.2.0...@quenty/symbol@2.0.0) (2021-09-05)


### Bug Fixes

* Remove peer dependencies. This is because lerna doesn't really support peer dependencies being linked and getting a new version on build, which is unfortunate. ([5f5aeee](https://github.com/Quenty/NevermoreEngine/commit/5f5aeeea8de9975435309e53679f0ef7064f9dd0))





# 1.2.0 (2021-07-31)


### Bug Fixes

* Add CI and CD ([47513e9](https://github.com/Quenty/NevermoreEngine/commit/47513e9b568162707534af132396dd8756947dd3))
* Adjust CI badge to show automatic build and release state ([5a55d3f](https://github.com/Quenty/NevermoreEngine/commit/5a55d3f19bf8d66a760d67da9b56ed47fab74656))
* Fix selene linting ([45fc074](https://github.com/Quenty/NevermoreEngine/commit/45fc07489ee59127ac6582689f19a0e87c1e5b5a))



## 1.0.2 (2021-07-25)



## 1.0.1 (2021-07-25)



# 1.0.0 (2021-07-24)

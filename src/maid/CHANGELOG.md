# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

# [3.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@3.4.3...@quenty/maid@3.5.0) (2025-05-10)

**Note:** Version bump only for package @quenty/maid





## [3.4.3](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@3.4.2...@quenty/maid@3.4.3) (2025-04-10)

**Note:** Version bump only for package @quenty/maid





## [3.4.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@3.4.0...@quenty/maid@3.4.2) (2025-04-07)


### Bug Fixes

* Add types to packages ([2374fb2](https://github.com/Quenty/NevermoreEngine/commit/2374fb2b043cfbe0e9b507b3316eec46a4e353a0))
* Bump package versions for republishing ([ba47c62](https://github.com/Quenty/NevermoreEngine/commit/ba47c62e32170bf74377b0c658c60b84306dc294))





## [3.4.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@3.4.0...@quenty/maid@3.4.1) (2025-04-07)


### Bug Fixes

* Add types to packages ([2374fb2](https://github.com/Quenty/NevermoreEngine/commit/2374fb2b043cfbe0e9b507b3316eec46a4e353a0))





# [3.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@3.3.0...@quenty/maid@3.4.0) (2024-10-04)


### Bug Fixes

* Maid:Add reports the correct method name in error ([3d31b0d](https://github.com/Quenty/NevermoreEngine/commit/3d31b0d5c6aa7c3bf280e102b1b37a3219ef2dba))


### Performance Improvements

* Order maid tasks by most common access scenarios and reduce query of typeof() calls ([2f6c713](https://github.com/Quenty/NevermoreEngine/commit/2f6c7130f462188e77ee4789315e5692302280eb))





# [3.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@3.2.0...@quenty/maid@3.3.0) (2024-09-12)


### Bug Fixes

* Fix maid formatting ([d4cc336](https://github.com/Quenty/NevermoreEngine/commit/d4cc336f86c82de76670f0e3e1061741b0e9b998))





# [3.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@3.1.0...@quenty/maid@3.2.0) (2024-05-09)


### Bug Fixes

* Fix .package-lock.json replicating in packages ([75d0efe](https://github.com/Quenty/NevermoreEngine/commit/75d0efeef239f221d93352af71a5b3e930ec23c5))





# [3.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@3.0.0...@quenty/maid@3.1.0) (2024-03-09)


### Bug Fixes

* Add Maid package ([e0bc7fc](https://github.com/Quenty/NevermoreEngine/commit/e0bc7fc47e7981b74f404410f14b539cd1191223))





# [3.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@2.6.0...@quenty/maid@3.0.0) (2024-02-13)


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





# [2.6.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@2.5.0...@quenty/maid@2.6.0) (2023-08-23)


### Features

* Add Maid:Add() which returns the task you pass into the maid ([bf9e3d6](https://github.com/Quenty/NevermoreEngine/commit/bf9e3d66e5c31ec0dafcc1c9e4142d963d309c65))





# [2.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@2.4.0...@quenty/maid@2.5.0) (2023-03-05)


### Bug Fixes

* Maids would sometimes error while cancelling threads they were part of. This ensures full cancellation. ([252fc3a](https://github.com/Quenty/NevermoreEngine/commit/252fc3a5b097dc1a58a998a261b2c28d367839d4))





# [2.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@2.3.0...@quenty/maid@2.4.0) (2022-07-31)


### Bug Fixes

* Maid tasks cancel old threads upon rewrite ([f953eb8](https://github.com/Quenty/NevermoreEngine/commit/f953eb8650073a3da5b551239c87e8d9391bc858))


### Features

* Add thread-support for maids ([#259](https://github.com/Quenty/NevermoreEngine/issues/259)) ([b6f37fa](https://github.com/Quenty/NevermoreEngine/commit/b6f37fa430dad4c6801510335c62691c4b7b6e3c))





# [2.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@2.2.0...@quenty/maid@2.3.0) (2022-03-27)

**Note:** Version bump only for package @quenty/maid





# [2.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@2.1.0...@quenty/maid@2.2.0) (2022-03-10)

**Note:** Version bump only for package @quenty/maid





# [2.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@2.0.2...@quenty/maid@2.1.0) (2022-01-17)


### Bug Fixes

* Maid errors are better ([f2cd8dd](https://github.com/Quenty/NevermoreEngine/commit/f2cd8dd529aacca133b5d1c773cb19479fc581fe))





## [2.0.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@2.0.1...@quenty/maid@2.0.2) (2021-12-30)

**Note:** Version bump only for package @quenty/maid





## [2.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@2.0.0...@quenty/maid@2.0.1) (2021-10-06)

**Note:** Version bump only for package @quenty/maid





# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/maid@1.2.0...@quenty/maid@2.0.0) (2021-09-05)


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

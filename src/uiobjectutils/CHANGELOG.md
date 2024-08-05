# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

# [6.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@6.2.0...@quenty/uiobjectutils@6.3.0) (2024-05-09)


### Bug Fixes

* Fix .package-lock.json replicating in packages ([75d0efe](https://github.com/Quenty/NevermoreEngine/commit/75d0efeef239f221d93352af71a5b3e930ec23c5))





# [6.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@6.1.0...@quenty/uiobjectutils@6.2.0) (2024-04-27)

**Note:** Version bump only for package @quenty/uiobjectutils





# [6.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@6.0.0...@quenty/uiobjectutils@6.1.0) (2024-03-09)

**Note:** Version bump only for package @quenty/uiobjectutils





# [6.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@5.0.0...@quenty/uiobjectutils@6.0.0) (2024-02-14)

**Note:** Version bump only for package @quenty/uiobjectutils





# [5.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@4.0.0...@quenty/uiobjectutils@5.0.0) (2024-02-13)

**Note:** Version bump only for package @quenty/uiobjectutils





# [4.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@3.6.0...@quenty/uiobjectutils@4.0.0) (2024-02-13)


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





# [3.6.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@3.5.0...@quenty/uiobjectutils@3.6.0) (2024-01-08)

**Note:** Version bump only for package @quenty/uiobjectutils





# [3.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@3.4.0...@quenty/uiobjectutils@3.5.0) (2023-12-14)


### Features

* Add PlayerGuiUtils.findPlayerGui() and documentation ([8f6ddd7](https://github.com/Quenty/NevermoreEngine/commit/8f6ddd7186b296dfe158f66f666bc08b02d02e8a))
* Add ScrollingDirectionUtils.canScrollHorizontal(scrollingDirection) ([0b18d30](https://github.com/Quenty/NevermoreEngine/commit/0b18d30af7003ce4abb75398490d40d4afb530ac))





# [3.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@3.3.0...@quenty/uiobjectutils@3.4.0) (2023-05-26)


### Bug Fixes

* Better error message with radius ([c4952fb](https://github.com/Quenty/NevermoreEngine/commit/c4952fbe364847051f82173dca4631df0ff137c7))


### Features

* Add UIAlignmentUtils.toNumber(alignment) and UIAlignmentUtils.toBias(alignment) ([8092aba](https://github.com/Quenty/NevermoreEngine/commit/8092aba1cc564daaf5c775cb23f3c2131005da80))
* Add UIAlignmentUtils.verticalAlignmentToBias(verticalAlignment) and UIAlignmentUtils.horizontalAlignmentToBias(horizontalAlignment) ([fb98622](https://github.com/Quenty/NevermoreEngine/commit/fb98622dad4ca05bf28ecf90b55521c6d48f9b38))





# [3.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@3.2.0...@quenty/uiobjectutils@3.3.0) (2023-04-24)


### Bug Fixes

* Fix unnecessary loader call ([c006846](https://github.com/Quenty/NevermoreEngine/commit/c0068460643037d818adac74b3fd213657d40325))





# [3.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@3.1.0...@quenty/uiobjectutils@3.2.0) (2023-02-21)

**Note:** Version bump only for package @quenty/uiobjectutils





# [3.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@3.0.0...@quenty/uiobjectutils@3.1.0) (2022-12-29)


### Features

* Add UIAlignmentUtils ([6b8fb3b](https://github.com/Quenty/NevermoreEngine/commit/6b8fb3b6167146ba60045980a3f94a7e90645c7c))





# [3.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@2.1.0...@quenty/uiobjectutils@3.0.0) (2022-09-27)

**Note:** Version bump only for package @quenty/uiobjectutils





# [2.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@2.0.1...@quenty/uiobjectutils@2.1.0) (2022-03-27)

**Note:** Version bump only for package @quenty/uiobjectutils





## [2.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@2.0.0...@quenty/uiobjectutils@2.0.1) (2021-12-30)

**Note:** Version bump only for package @quenty/uiobjectutils





# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/uiobjectutils@1.2.0...@quenty/uiobjectutils@2.0.0) (2021-09-05)


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
